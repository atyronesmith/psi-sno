#!/bin/bash

set -euo pipefail

# Script to list all OpenStack networks that start with "psi-"
# Usage: ./scripts/list-psi-networks.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to print and execute OpenStack commands
run_openstack_cmd() {
    local cmd="$*"
    print_info "Executing: openstack $cmd"
    openstack "$@"
}

# Function to check if OpenStack CLI is available
check_openstack_cli() {
    if ! command -v openstack &> /dev/null; then
        print_error "OpenStack CLI not found. Please install it first:"
        echo "  pip install python-openstackclient"
        exit 1
    fi
}

# Function to check if OpenStack credentials are configured
check_openstack_auth() {
    print_info "Executing: openstack token issue"
    if ! openstack token issue &> /dev/null; then
        print_error "OpenStack authentication failed. Please ensure you have:"
        echo "  1. Sourced your OpenStack RC file"
        echo "  2. Set the required environment variables:"
        echo "     - OS_AUTH_URL"
        echo "     - OS_USERNAME"
        echo "     - OS_PASSWORD"
        echo "     - OS_PROJECT_NAME"
        echo "     - OS_USER_DOMAIN_NAME"
        echo "     - OS_PROJECT_DOMAIN_NAME"
        exit 1
    fi
}

# Function to list PSI networks
list_psi_networks() {
    print_info "Searching for networks with names starting with 'psi-'..."
    echo ""

            # Get all networks and filter for psi-* names, store in array
    local networks_array=()

    # Use mapfile to read filtered networks into array
    print_info "Executing: openstack network list -f value -c ID -c Name -c Subnets"
    mapfile -t networks_array < <(openstack network list -f value -c ID -c Name -c Subnets | grep -E "\s+psi-[a-z0-9-]+\s+")





    if [[ ${#networks_array[@]} -eq 0 ]]; then
        print_warning "No networks found with names starting with 'psi-'"
        return 0
    fi

    # Header
    printf "%-40s %-36s %-10s %-20s\n" "NETWORK NAME" "NETWORK ID" "STATUS" "SUBNETS"
    printf "%-40s %-36s %-10s %-20s\n" "$(printf '%0.s-' {1..40})" "$(printf '%0.s-' {1..36})" "$(printf '%0.s-' {1..10})" "$(printf '%0.s-' {1..20})"

                # Process each network from the array
    local count=0

    # Use index-based loop instead of for-in loop
    for i in "${!networks_array[@]}"; do
        network_line="${networks_array[$i]}"

        # Use bash parameter expansion and read to split fields
        read -r id name subnets <<< "$network_line"

        # Handle empty subnets field
        if [[ -z "$subnets" || "$subnets" == "[]" ]]; then
            subnets="None"
        fi

        printf "%-40s %-36s %-10s %-20s\n" "$name" "$id" "ACTIVE" "$subnets"

        # Use alternative increment method to avoid arithmetic evaluation issues
        count=$((count + 1))
    done

    echo ""
    print_success "Found $count PSI network(s)"
}

# Function to show detailed network information
show_network_details() {
    local network_name="$1"

    print_info "Detailed information for network: $network_name"
    echo ""

    run_openstack_cmd network show "$network_name" -f table

    # Show subnets if any
    local subnets
    print_info "Executing: openstack network show \"$network_name\" -f value -c subnets"
    subnets=$(openstack network show "$network_name" -f value -c subnets)

    if [[ -n "$subnets" && "$subnets" != "[]" ]]; then
        echo ""
        print_info "Subnets for network $network_name:"

        # Remove brackets and split by comma
        subnets=$(echo "$subnets" | tr -d '[]' | tr ',' '\n')

        while IFS= read -r subnet_id; do
            if [[ -n "$subnet_id" ]]; then
                # Remove quotes and whitespace
                subnet_id=$(echo "$subnet_id" | tr -d "'" | xargs)
                echo ""
                run_openstack_cmd subnet show "$subnet_id" -f table
            fi
        done <<< "$subnets"
    fi
}

# Function to delete a network (with router detachment if needed)
delete_network() {
    local network_name="$1"
    local network_id="$2"
    local auto_yes="$3"
    local router_port_details=("${@:4}")

    echo ""
    print_warning "You are about to DELETE network: $network_name (ID: $network_id)"

    # Show what will be deleted
    print_warning "NETWORK DELETION PROCESS:"
    print_warning "1. All floating IPs will be detached from all network ports"
    print_warning "2. All non-router ports (detached, infrastructure, VM ports) will be deleted"
    print_warning "3. Router ports will be removed from routers"
    print_warning "4. Network will be deleted"

    if [[ ${#router_port_details[@]} -gt 0 ]]; then
        echo ""
        print_info "Router ports that will be detached:"
        for port_info in "${router_port_details[@]}"; do
            IFS=$'\t' read -r port_id port_name device_owner router_id fixed_ips <<< "$port_info"
            local router_name
            if [[ -n "$router_id" ]]; then
                print_info "Executing: openstack router show \"$router_id\" -f value -c name"
                router_name=$(openstack router show "$router_id" -f value -c name 2>/dev/null || echo "$router_id")
            else
                router_name="(unknown router)"
            fi
            echo "  - Port: $port_id (Router: $router_name)"
        done
    fi

    echo ""
    local confirmation
    if [[ "$auto_yes" == "true" ]]; then
        print_info "Auto-confirming network deletion (-y flag provided)"
        confirmation="yes"
    else
        read -p "Are you sure you want to delete this network? This action cannot be undone. (yes/no): " confirmation
    fi

    case "$confirmation" in
        "yes"|"YES"|"y"|"Y")
            print_info "Proceeding with network deletion..."
            ;;
        *)
            print_info "Network deletion cancelled."
            return 0
            ;;
    esac

                # Step 1: Detach ALL floating IPs from the network
    echo ""
    print_info "Step 1: Detaching all floating IPs from network ports..."

    # Get all ports on the network
    print_info "Executing: openstack port list --network \"$network_id\" -f value -c ID"
    local all_port_ids
    all_port_ids=$(openstack port list --network "$network_id" -f value -c ID 2>/dev/null)

    local floating_ips_found=false

    if [[ -n "$all_port_ids" ]]; then
        while IFS= read -r port_id; do
            if [[ -n "$port_id" ]]; then
                # Check if this port has any floating IPs
                print_info "Executing: openstack floating ip list --port \"$port_id\" -f value -c ID"
                local floating_ip_ids
                floating_ip_ids=$(openstack floating ip list --port "$port_id" -f value -c ID 2>/dev/null)

                if [[ -n "$floating_ip_ids" ]]; then
                    floating_ips_found=true
                    print_warning "Found floating IP(s) attached to port $port_id"

                    while IFS= read -r fip_id; do
                        if [[ -n "$fip_id" ]]; then
                            # Get floating IP details for user information
                            print_info "Executing: openstack floating ip show \"$fip_id\" -f value -c floating_ip_address"
                            local fip_address
                            fip_address=$(openstack floating ip show "$fip_id" -f value -c floating_ip_address 2>/dev/null || echo "unknown")

                            print_info "Detaching floating IP: $fip_address ($fip_id) from port $port_id"
                            print_info "Executing: openstack floating ip unset --port \"$fip_id\""

                            if openstack floating ip unset --port "$fip_id" 2>/dev/null; then
                                print_success "Successfully detached floating IP $fip_address"
                            else
                                print_error "Failed to detach floating IP $fip_address"
                                print_error "You may need to manually detach this floating IP before deletion"
                                return 1
                            fi
                        fi
                    done <<< "$floating_ip_ids"
                fi
            fi
        done <<< "$all_port_ids"
    fi

    if [[ "$floating_ips_found" == "true" ]]; then
        print_success "All floating IPs successfully detached from network ports"
    else
        print_info "No floating IPs found on network ports"
    fi

    # Step 2: Delete all non-router ports (detached, infrastructure, VM ports, etc.)
    echo ""
    print_info "Step 2: Checking for and deleting all non-router ports..."

    # Get all ports on the network with detailed information
    print_info "Executing: openstack port list --network \"$network_id\" -f value -c ID"
    local all_port_ids
    all_port_ids=$(openstack port list --network "$network_id" -f value -c ID 2>/dev/null)

    local ports_to_delete_found=false
    local ports_to_delete_ids=()

    if [[ -n "$all_port_ids" ]]; then
        while IFS= read -r port_id; do
            if [[ -n "$port_id" ]]; then
                # Get detailed port information to properly check device_owner
                print_info "Executing: openstack port show \"$port_id\" -f value -c device_owner -c device_id"
                local port_details
                port_details=$(openstack port show "$port_id" -f value -c device_owner -c device_id 2>/dev/null)

                                                if [[ -n "$port_details" ]]; then
                    # Parse device_owner and device_id from the output
                    local device_owner device_id
                    read -r device_owner device_id <<< "$port_details"

                                        # Normalize empty values
                    [[ -z "$device_owner" ]] && device_owner=""
                    [[ -z "$device_id" ]] && device_id=""

                    # Skip router ports - they are handled in the next step
                    if [[ "$device_owner" == "network:router_interface" || "$device_owner" == "network:router_gateway" ]]; then
                        print_info "Skipping router port: $port_id (device_owner: $device_owner) - will handle in next step"
                    # Delete all other ports including detached, network infrastructure, etc.
                    else
                        ports_to_delete_found=true
                        ports_to_delete_ids+=("$port_id")
                        print_warning "Found port to delete: $port_id (device_owner: '${device_owner:-empty}', device_id: '${device_id:-empty}')"
                    fi
                else
                    print_warning "Could not get details for port $port_id - will try to delete it anyway"
                    ports_to_delete_found=true
                    ports_to_delete_ids+=("$port_id")
                fi
            fi
        done <<< "$all_port_ids"
    fi

        if [[ "$ports_to_delete_found" == "true" ]]; then
        print_info "Deleting ${#ports_to_delete_ids[@]} non-router port(s)..."

        for port_id in "${ports_to_delete_ids[@]}"; do
            print_info "Deleting port: $port_id"
            print_info "Executing: openstack port delete \"$port_id\""

            if openstack port delete "$port_id" 2>/dev/null; then
                print_success "Successfully deleted port $port_id"
            else
                print_error "Failed to delete port $port_id"
                print_error "You may need to manually delete this port before network deletion"
                return 1
            fi
        done

        print_success "All non-router ports successfully deleted"
    else
        print_info "No non-router ports found on network (only router interfaces remain)"
    fi

              # Step 3: Handle router ports (remove from routers - floating IPs already detached)
    if [[ ${#router_port_details[@]} -gt 0 ]]; then
        echo ""
        print_info "Step 3: Removing router ports from routers..."

        for port_info in "${router_port_details[@]}"; do
            IFS=$'\t' read -r port_id port_name device_owner router_id fixed_ips <<< "$port_info"

            if [[ -n "$router_id" ]]; then
                local router_name
                print_info "Executing: openstack router show \"$router_id\" -f value -c name"
                router_name=$(openstack router show "$router_id" -f value -c name 2>/dev/null || echo "$router_id")

                print_info "Removing router port: $port_id from router $router_name ($router_id)"

                # Try to remove the router interface
                print_info "Executing: openstack router remove subnet \"$router_id\" \"$network_id\""
                if openstack router remove subnet "$router_id" "$network_id" 2>/dev/null; then
                    print_success "Successfully detached network from router $router_name"
                else
                    # If subnet removal fails, try removing the port directly
                    print_warning "Subnet removal failed, trying to remove port directly..."
                    print_info "Executing: openstack router remove port \"$router_id\" \"$port_id\""
                    if openstack router remove port "$router_id" "$port_id" 2>/dev/null; then
                        print_success "Successfully removed port from router $router_name"
                    else
                        print_error "Failed to detach network from router $router_name"
                        print_error "You may need to manually detach the network before deletion"
                        return 1
                    fi
                fi
            fi
        done

        print_success "Network successfully detached from all routers"
    fi

    # Step 4: Delete the network
    echo ""
    print_info "Step 4: Deleting network..."

    print_info "Executing: openstack network delete \"$network_id\""
    if openstack network delete "$network_id" 2>/dev/null; then
        print_success "Network '$network_name' has been successfully deleted!"
    else
        print_error "Failed to delete network '$network_name'"
        print_error "The network may still have active ports or other dependencies"
        echo ""
        print_info "Checking remaining ports..."
        local remaining_ports
        print_info "Executing: openstack port list --network \"$network_id\" -f value -c ID"
        remaining_ports=$(openstack port list --network "$network_id" -f value -c ID 2>/dev/null || echo "")

        if [[ -n "$remaining_ports" ]]; then
            print_warning "The following ports are still attached to the network:"
            while IFS= read -r port_id; do
                if [[ -n "$port_id" ]]; then
                    local port_owner
                    print_info "Executing: openstack port show \"$port_id\" -f value -c device_owner"
                    port_owner=$(openstack port show "$port_id" -f value -c device_owner 2>/dev/null || echo "unknown")
                    echo "  - Port: $port_id (Owner: $port_owner)"
                fi
            done <<< "$remaining_ports"
            echo ""
            print_info "You may need to manually remove these ports before deleting the network"
        fi

        return 1
    fi
}

# Function to interactively select a PSI network and check router ports
select_network_check_routers() {
    local auto_yes="${1:-false}"
    print_info "Loading PSI networks for selection..."
    echo ""

    # Get all PSI networks and store in array
    local networks_array=()
    print_info "Executing: openstack network list -f value -c ID -c Name -c Subnets"
    mapfile -t networks_array < <(openstack network list -f value -c ID -c Name -c Subnets | grep -E "\s+psi-[a-z0-9-]+\s+")

    if [[ ${#networks_array[@]} -eq 0 ]]; then
        print_warning "No networks found with names starting with 'psi-'"
        return 0
    fi

    # Create arrays for network names and IDs
    local network_names=()
    local network_ids=()

    for i in "${!networks_array[@]}"; do
        network_line="${networks_array[$i]}"
        read -r id name subnets <<< "$network_line"
        network_ids+=("$id")
        network_names+=("$name")
    done

    # Display numbered list of networks
    echo "Available PSI networks:"
    echo "======================="
    for i in "${!network_names[@]}"; do
        printf "%2d. %s\n" $((i + 1)) "${network_names[$i]}"
    done
    echo ""

    # Get user selection
    local selection
    while true; do
        read -p "Enter the number of the network to check (1-${#network_names[@]}): " selection

        # Validate input
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#network_names[@]} ]]; then
            break
        else
            print_error "Invalid selection. Please enter a number between 1 and ${#network_names[@]}."
        fi
    done

    # Convert to 0-based index
    local selected_index=$((selection - 1))
    local selected_network_name="${network_names[$selected_index]}"
    local selected_network_id="${network_ids[$selected_index]}"

    echo ""
    print_info "Selected network: $selected_network_name (ID: $selected_network_id)"
    echo ""

    # Check for ports attached to routers
    print_info "Checking for ports attached to routers on network '$selected_network_name'..."
    echo ""

        # Get all ports on the selected network
    local port_ids
    print_info "Executing: openstack port list --network \"$selected_network_id\" -f value -c ID"
    port_ids=$(openstack port list --network "$selected_network_id" -f value -c ID 2>/dev/null)

    if [[ -z "$port_ids" ]]; then
        print_warning "No ports found on network '$selected_network_name'"
        echo ""
        # Still offer to delete the network even if no ports
        local delete_choice
        if [[ "$auto_yes" == "true" ]]; then
            print_info "Auto-confirming network deletion (-y flag provided)"
            delete_choice="y"
        else
            read -p "Would you like to delete this network? (floating IPs detached, all ports deleted) (y/N): " delete_choice
        fi
        case "$delete_choice" in
            "y"|"Y"|"yes"|"YES")
                delete_network "$selected_network_name" "$selected_network_id" "$auto_yes"
                ;;
            *)
                print_info "Network deletion cancelled."
                ;;
        esac
        return 0
    fi

    print_info "Found $(echo "$port_ids" | wc -l) port(s) on network '$selected_network_name'"
    echo ""

    # Arrays to store port information
    local port_details=()
    local router_port_details=()

            # Get detailed information for each port
    while IFS= read -r port_id; do
        if [[ -n "$port_id" ]]; then
            # Get all port details in one call using shell format
            local port_output
            print_info "Executing: openstack port show \"$port_id\" -f shell"
            port_output=$(openstack port show "$port_id" -f shell 2>/dev/null)

            if [[ -n "$port_output" ]]; then
                                # Parse the shell output to get individual fields
                local port_name device_owner device_id fixed_ips
                port_name=$(echo "$port_output" | grep '^name=' | cut -d'=' -f2- | sed 's/^"//;s/"$//')
                device_owner=$(echo "$port_output" | grep '^device_owner=' | cut -d'=' -f2- | sed 's/^"//;s/"$//')
                device_id=$(echo "$port_output" | grep '^device_id=' | cut -d'=' -f2- | sed 's/^"//;s/"$//')
                fixed_ips=$(echo "$port_output" | grep '^fixed_ips=' | cut -d'=' -f2- | sed 's/^"//;s/"$//')

                # Ensure empty fields have placeholders to maintain tab structure
                [[ -z "$port_name" ]] && port_name="(no name)"
                [[ -z "$device_owner" ]] && device_owner="(no owner)"
                [[ -z "$device_id" ]] && device_id="(no device)"
                [[ -z "$fixed_ips" ]] && fixed_ips="[]"

                # Create combined port info
                local port_info="$port_id"$'\t'"$port_name"$'\t'"$device_owner"$'\t'"$device_id"$'\t'"$fixed_ips"
                port_details+=("$port_info")

                # Check if this is a router port
                if [[ "$device_owner" == "network:router_interface" || "$device_owner" == "network:router_gateway" ]]; then
                    router_port_details+=("$port_info")
                fi
            fi
        fi
    done <<< "$port_ids"

    # Check if we found any router ports
    if [[ ${#router_port_details[@]} -eq 0 ]]; then
        print_warning "No router ports found on network '$selected_network_name'"
        echo ""
                print_info "All ports on this network:"
        printf "%-36s %-25s %-20s %-30s %-20s\n" "PORT ID" "PORT NAME" "DEVICE OWNER" "DEVICE NAME" "FIXED IP"
        printf "%-36s %-25s %-20s %-30s %-20s\n" "$(printf '%0.s-' {1..36})" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..20})" "$(printf '%0.s-' {1..30})" "$(printf '%0.s-' {1..20})"

        for port_info in "${port_details[@]}"; do
            # Parse port information: id, name, device_owner, device_id, fixed_ips
            IFS=$'\t' read -r port_id port_name device_owner device_id fixed_ips <<< "$port_info"

            # Extract IP address from fixed_ips format
            local ip_address
            if [[ -n "$fixed_ips" && "$fixed_ips" != "[]" ]]; then
                # Extract IP from format: [{'subnet_id': '...', 'ip_address': '192.168.200.1'}]
                ip_address=$(echo "$fixed_ips" | grep -o "'ip_address': '[^']*'" | cut -d"'" -f4 | head -1)
                if [[ -z "$ip_address" ]]; then
                    ip_address="(no IP)"
                fi
            else
                ip_address="(no IP)"
            fi

            # Get device name if device_id is present
            local device_name=""
            if [[ -n "$device_id" && "$device_id" != "" ]]; then
                case "$device_owner" in
                    "network:router_interface"|"network:router_gateway")
                        print_info "Executing: openstack router show \"$device_id\" -f value -c name"
                        device_name=$(openstack router show "$device_id" -f value -c name 2>/dev/null || echo "$device_id")
                        ;;
                    "compute:nova")
                        print_info "Executing: openstack server show \"$device_id\" -f value -c name"
                        device_name=$(openstack server show "$device_id" -f value -c name 2>/dev/null || echo "$device_id")
                        ;;
                    *)
                        device_name="$device_id"
                        ;;
                esac
            else
                device_name="(no device)"
            fi

            printf "%-36s %-25s %-20s %-30s %-20s\n" "$port_id" "$port_name" "$device_owner" "$device_name" "$ip_address"
        done

        echo ""
        # Ask if user wants to delete the network
        local delete_choice
        if [[ "$auto_yes" == "true" ]]; then
            print_info "Auto-confirming network deletion (-y flag provided)"
            delete_choice="y"
        else
            read -p "Would you like to delete this network? (floating IPs detached, all ports deleted) (y/N): " delete_choice
        fi
        case "$delete_choice" in
            "y"|"Y"|"yes"|"YES")
                delete_network "$selected_network_name" "$selected_network_id" "$auto_yes"
                ;;
            *)
                print_info "Network deletion cancelled."
                ;;
        esac
            else
        print_success "Found ${#router_port_details[@]} router port(s) on network '$selected_network_name':"
        echo ""
        printf "%-36s %-25s %-20s %-30s %-20s\n" "PORT ID" "PORT NAME" "DEVICE OWNER" "ROUTER NAME" "FIXED IP"
        printf "%-36s %-25s %-20s %-30s %-20s\n" "$(printf '%0.s-' {1..36})" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..20})" "$(printf '%0.s-' {1..30})" "$(printf '%0.s-' {1..20})"

        local router_ids=()
        for port_info in "${router_port_details[@]}"; do
            # Parse port information: id, name, device_owner, device_id, fixed_ips
            IFS=$'\t' read -r port_id port_name device_owner router_id fixed_ips <<< "$port_info"

            # Extract IP address from fixed_ips format
            local ip_address
            if [[ -n "$fixed_ips" && "$fixed_ips" != "[]" ]]; then
                # Extract IP from format: [{'subnet_id': '...', 'ip_address': '192.168.200.1'}]
                ip_address=$(echo "$fixed_ips" | grep -o "'ip_address': '[^']*'" | cut -d"'" -f4 | head -1)
                if [[ -z "$ip_address" ]]; then
                    ip_address="(no IP)"
                fi
            else
                ip_address="(no IP)"
            fi

            # Get router name
            local router_name
            if [[ -n "$router_id" ]]; then
                print_info "Executing: openstack router show \"$router_id\" -f value -c name"
                router_name=$(openstack router show "$router_id" -f value -c name 2>/dev/null || echo "$router_id")
                # Store unique router IDs for detailed display
                if [[ ! " ${router_ids[*]} " =~ " ${router_id} " ]]; then
                    router_ids+=("$router_id")
                fi
            else
                router_name="(no router)"
            fi

            printf "%-36s %-25s %-20s %-30s %-20s\n" "$port_id" "$port_name" "$device_owner" "$router_name" "$ip_address"
        done

        echo ""
        print_info "Router details:"
        for router_id in "${router_ids[@]}"; do
            if [[ -n "$router_id" ]]; then
                echo ""
                print_info "Router: $router_id"
                print_info "Executing: openstack router show \"$router_id\" -f table"
                openstack router show "$router_id" -f table 2>/dev/null || print_warning "Could not retrieve router details for $router_id"
            fi
        done

        echo ""
        # Ask if user wants to delete the network (complete cleanup process)
        local delete_choice
        if [[ "$auto_yes" == "true" ]]; then
            print_info "Auto-confirming network deletion (-y flag provided)"
            delete_choice="y"
        else
            read -p "Would you like to delete this network? This will perform complete cleanup (floating IPs, all ports, router interfaces). (y/N): " delete_choice
        fi
        case "$delete_choice" in
            "y"|"Y"|"yes"|"YES")
                delete_network "$selected_network_name" "$selected_network_id" "$auto_yes" "${router_port_details[@]}"
                ;;
            *)
                print_info "Network deletion cancelled."
                ;;
        esac
    fi
}

# Function to list PSI routers matching the patterns psi-[0-9a-z]{5} and psi-[0-9a-z]{5}-os
list_psi_routers() {
    print_info "Searching for routers with names matching patterns 'psi-[0-9a-z]{5}' and 'psi-[0-9a-z]{5}-os'..."
    echo ""

    # Get all routers and filter for psi-* names matching the patterns
    local routers_array=()

    # Use mapfile to read filtered routers into array
    print_info "Executing: openstack router list -f value -c ID -c Name -c Status"
    mapfile -t routers_array < <(openstack router list -f value -c ID -c Name -c Status | grep -E "\s+(psi-[0-9a-z]{5}|psi-[0-9a-z]{5}-os)\s+")

    if [[ ${#routers_array[@]} -eq 0 ]]; then
        print_warning "No routers found with names matching patterns 'psi-[0-9a-z]{5}' or 'psi-[0-9a-z]{5}-os'"
        return 0
    fi

    # Header
    printf "%-25s %-36s %-10s %-20s %-20s\n" "ROUTER NAME" "ROUTER ID" "STATUS" "NETWORKS" "PORTS"
    printf "%-25s %-36s %-10s %-20s %-20s\n" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..36})" "$(printf '%0.s-' {1..10})" "$(printf '%0.s-' {1..20})" "$(printf '%0.s-' {1..20})"

    # Process each router from the array
    local count=0
    local orphaned_routers=()

        # Use index-based loop instead of for-in loop
    for i in "${!routers_array[@]}"; do
        router_line="${routers_array[$i]}"

        # Use bash parameter expansion and read to split fields
        read -r id name status <<< "$router_line"

        # Check if router has any networks attached (optimized - no debug output)
        local networks_count
        local interfaces_info
        interfaces_info=$(openstack router show "$id" -f value -c interfaces_info 2>/dev/null || echo "[]")

        # Count networks (interfaces_info contains network interfaces)
        if [[ "$interfaces_info" == "[]" || -z "$interfaces_info" ]]; then
            networks_count=0
        else
            # Count the number of subnet_id entries in the interfaces_info
            networks_count=$(echo "$interfaces_info" | grep -o "subnet_id" | wc -l)
        fi

        # Check if router has any ports (optimized - no debug output)
        local ports_count
        ports_count=$(openstack port list --router "$id" -f value -c ID 2>/dev/null | wc -l)

        # Format counts for display
        local networks_display="${networks_count}"
        local ports_display="${ports_count}"

        # Mark as orphaned if no networks and no ports
        if [[ $networks_count -eq 0 && $ports_count -eq 0 ]]; then
            networks_display="${networks_count} (ORPHANED)"
            ports_display="${ports_count} (ORPHANED)"
            orphaned_routers+=("$id|$name|$status")
        fi

        printf "%-25s %-36s %-10s %-20s %-20s\n" "$name" "$id" "$status" "$networks_display" "$ports_display"

        count=$((count + 1))
    done

    echo ""
    print_success "Found $count PSI router(s)"

    if [[ ${#orphaned_routers[@]} -gt 0 ]]; then
        echo ""
        print_warning "Found ${#orphaned_routers[@]} orphaned router(s) with no networks or ports attached"
        return ${#orphaned_routers[@]}
    fi

    return 0
}

# Function to manage orphaned routers
manage_orphaned_routers() {
    local auto_yes="$1"

    print_info "Checking for orphaned PSI routers..."
    echo ""

    # Get all routers matching the patterns
    local routers_array=()
    print_info "Executing: openstack router list -f value -c ID -c Name -c Status"
    mapfile -t routers_array < <(openstack router list -f value -c ID -c Name -c Status | grep -E "\s+(psi-[0-9a-z]{5}|psi-[0-9a-z]{5}-os)\s+")

    if [[ ${#routers_array[@]} -eq 0 ]]; then
        print_warning "No routers found with names matching patterns 'psi-[0-9a-z]{5}' or 'psi-[0-9a-z]{5}-os'"
        return 0
    fi

    # Find orphaned routers
    local orphaned_routers=()

        for i in "${!routers_array[@]}"; do
        router_line="${routers_array[$i]}"
        read -r id name status <<< "$router_line"

        # Check if router has any networks attached (optimized - no debug output)
        local interfaces_info
        interfaces_info=$(openstack router show "$id" -f value -c interfaces_info 2>/dev/null || echo "[]")

        # Check if router has any ports (optimized - no debug output)
        local ports_count
        ports_count=$(openstack port list --router "$id" -f value -c ID 2>/dev/null | wc -l)

        # Check if truly orphaned (no interfaces and no ports)
        if [[ ("$interfaces_info" == "[]" || -z "$interfaces_info") && $ports_count -eq 0 ]]; then
            orphaned_routers+=("$id|$name|$status")
        fi
    done

    if [[ ${#orphaned_routers[@]} -eq 0 ]]; then
        print_success "No orphaned routers found - all routers have networks or ports attached"
        return 0
    fi

    echo ""
    print_warning "Found ${#orphaned_routers[@]} orphaned router(s):"
    echo ""

    # Header
    printf "%-3s %-25s %-36s %-10s\n" "#" "ROUTER NAME" "ROUTER ID" "STATUS"
    printf "%-3s %-25s %-36s %-10s\n" "---" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..36})" "$(printf '%0.s-' {1..10})"

    # Display orphaned routers with numbers
    for i in "${!orphaned_routers[@]}"; do
        IFS='|' read -r id name status <<< "${orphaned_routers[$i]}"
        printf "%-3d %-25s %-36s %-10s\n" "$((i + 1))" "$name" "$id" "$status"
    done

    echo ""

    # Ask user what to do
    local action_choice
    if [[ "$auto_yes" == "true" ]]; then
        print_info "Auto-confirming router deletion (-y flag provided)"
        action_choice="all"
    else
        echo "What would you like to do?"
        echo "  all  - Delete all orphaned routers"
        echo "  one  - Select and delete one router"
        echo "  none - Do nothing (default)"
        echo ""
        read -p "Choose action (all/one/none): " action_choice
    fi

    case "$action_choice" in
        "all")
            print_warning "Deleting ALL orphaned routers..."
            for router_info in "${orphaned_routers[@]}"; do
                IFS='|' read -r id name status <<< "$router_info"
                delete_router "$id" "$name" "$auto_yes"
            done
            ;;
        "one")
            if [[ "$auto_yes" == "true" ]]; then
                # In auto-yes mode, delete the first one
                IFS='|' read -r id name status <<< "${orphaned_routers[0]}"
                delete_router "$id" "$name" "$auto_yes"
            else
                echo ""
                read -p "Enter the number of the router to delete (1-${#orphaned_routers[@]}): " router_num

                if [[ "$router_num" =~ ^[0-9]+$ ]] && [[ $router_num -ge 1 ]] && [[ $router_num -le ${#orphaned_routers[@]} ]]; then
                    IFS='|' read -r id name status <<< "${orphaned_routers[$((router_num - 1))]}"
                    delete_router "$id" "$name" "$auto_yes"
                else
                    print_error "Invalid selection: $router_num"
                    return 1
                fi
            fi
            ;;
        *)
            print_info "No action taken."
            return 0
            ;;
    esac
}

# Function to delete a router
delete_router() {
    local router_id="$1"
    local router_name="$2"
    local auto_yes="$3"

    echo ""
    print_warning "You are about to DELETE router: $router_name (ID: $router_id)"

    # Show router details
    print_info "Router details:"
    print_info "Executing: openstack router show \"$router_id\" -f table"
    openstack router show "$router_id" -f table 2>/dev/null || print_warning "Could not retrieve router details"

    echo ""
    local confirmation
    if [[ "$auto_yes" == "true" ]]; then
        print_info "Auto-confirming router deletion (-y flag provided)"
        confirmation="yes"
    else
        read -p "Are you sure you want to delete this router? This action cannot be undone. (yes/no): " confirmation
    fi

    case "$confirmation" in
        "yes"|"YES"|"y"|"Y")
            print_info "Proceeding with router deletion..."

            print_info "Executing: openstack router delete \"$router_id\""
            if openstack router delete "$router_id" 2>/dev/null; then
                print_success "Successfully deleted router: $router_name (ID: $router_id)"
            else
                print_error "Failed to delete router: $router_name (ID: $router_id)"
                return 1
            fi
            ;;
        *)
            print_info "Router deletion cancelled."
            return 0
            ;;
    esac
}

# Main function
main() {
    # Parse -y flag from any position in arguments
    local auto_yes=false
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == "-y" ]]; then
            auto_yes=true
        else
            args+=("$arg")
        fi
    done

    # Handle help command first, before checking OpenStack prerequisites
    case "${args[0]:-list}" in
        "help"|"-h"|"--help")
            echo "PSI Management Tool"
            echo "==================="
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Network Commands:"
            echo "  list          List all networks starting with 'psi-' (default)"
            echo "  select        Interactively select a network and check router ports"
            echo "  delete        Select a network and delete it (detaches floating IPs, deletes all ports, removes from routers)"
            echo "  debug         Show raw network data for troubleshooting"
            echo "  show <name>   Show detailed information for a specific network"
            echo ""
            echo "Router Commands:"
            echo "  list-routers  List all routers matching patterns 'psi-[0-9a-z]{5}' or 'psi-[0-9a-z]{5}-os'"
            echo "  clean-routers Clean up orphaned routers (no networks or ports attached)"
            echo ""
            echo "General Commands:"
            echo "  help          Show this help message"
            echo ""
            echo "Options:"
            echo "  -y            Auto-confirm all prompts (non-interactive mode)"
            echo ""
            echo "Examples:"
            echo "  $0                           # List all psi-* networks"
            echo "  $0 list                      # List all psi-* networks"
            echo "  $0 select                    # Interactively select network and check routers"
            echo "  $0 delete                    # Select and delete a network"
            echo "  $0 delete -y                 # Select and delete a network (auto-confirm)"
            echo "  $0 show psi-provider         # Show details for psi-provider network"
            echo "  $0 list-routers              # List all PSI routers"
            echo "  $0 clean-routers             # Find and clean up orphaned routers"
            echo "  $0 clean-routers -y          # Auto-delete all orphaned routers"
            return 0
            ;;
    esac

    print_info "PSI Management Tool"
    echo "==================="
    echo ""

    # Check prerequisites
    check_openstack_cli
    check_openstack_auth

    # Parse command line arguments
    case "${args[0]:-list}" in
        "list"|"")
            list_psi_networks
            ;;
        "select")
            select_network_check_routers "$auto_yes"
            ;;
        "delete")
            select_network_check_routers "$auto_yes"
            ;;
        "list-routers")
            list_psi_routers
            ;;
        "clean-routers")
            manage_orphaned_routers "$auto_yes"
            ;;
        "debug")
            # Enable debug mode
            print_info "Debug mode: showing raw network data"
            echo ""
            local raw_output
            print_info "Executing: openstack network list -f value -c ID -c Name -c Subnets"
            raw_output=$(openstack network list -f value -c ID -c Name -c Subnets)
            echo "All networks (raw):"
            echo "$raw_output"
            echo ""
            echo "Filtered networks (psi-*):"
            echo "$raw_output" | grep -E "\s+psi-[a-z0-9-]+\s+" || echo "No matches found"
            ;;
        "show")
            if [[ -z "${args[1]:-}" ]]; then
                print_error "Network name required for 'show' command"
                echo "Usage: $0 show <network-name>"
                exit 1
            fi
            show_network_details "${args[1]}"
            ;;
        *)
            print_error "Unknown command: ${args[0]}"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"