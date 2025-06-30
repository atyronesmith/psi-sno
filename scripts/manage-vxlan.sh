#!/bin/bash

# VXLAN Management Script for internalapi network
# This script manages VXLAN endpoints by dynamically reading configuration
# from vxlan-nncp.yaml and networking.yaml files

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PLAYBOOK="$PROJECT_DIR/playbooks/manage-vxlan-internalapi.yml"

# Default values (can be overridden)
INTERFACE_NAME="internalapi"
DRY_RUN="false"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
    create      Create VXLAN endpoint (reads config from files)
    delete      Delete VXLAN endpoint
    status      Show current VXLAN interface status
    help        Show this help message

Options:
    --interface <name>      Interface name (default: internalapi)
    --network-ip <ip>       Override network IP address
    --base-if <interface>   Override base interface
    --remote <ip>           Override remote endpoint IP
    --dry-run              Show what would be executed without running

Configuration Files:
    The script dynamically reads configuration from:
    - configs/kubernetes/vxlan-nncp.yaml      (VXLAN settings)
    - configs/kubernetes/networking.yaml      (Network ranges)

Examples:
    $0 create                                 # Create with config from files
    $0 create --base-if eno1                 # Override base interface
    $0 create --network-ip 172.17.0.20      # Override IP address
    $0 delete                                # Delete VXLAN endpoint
    $0 status                                # Show current status
    $0 create --dry-run                      # Show what would be done

EOF
}

# Function to check prerequisites
check_prerequisites() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        echo "Please run with sudo or as root user"
        exit 1
    fi

    # Check if ansible-playbook is available
    if ! command -v ansible-playbook &> /dev/null; then
        echo -e "${RED}Error: ansible-playbook is not installed${NC}"
        echo "Please install Ansible to use this script"
        exit 1
    fi

    # Check if playbook exists
    if [[ ! -f "$PLAYBOOK" ]]; then
        echo -e "${RED}Error: Playbook not found at $PLAYBOOK${NC}"
        exit 1
    fi

    # Check if configuration files exist
    local vxlan_config="$PROJECT_DIR/configs/kubernetes/vxlan-nncp.yaml"
    local network_config="$PROJECT_DIR/configs/kubernetes/networking.yaml"

    if [[ ! -f "$vxlan_config" ]]; then
        echo -e "${RED}Error: VXLAN configuration file not found: $vxlan_config${NC}"
        exit 1
    fi

    if [[ ! -f "$network_config" ]]; then
        echo -e "${RED}Error: Network configuration file not found: $network_config${NC}"
        exit 1
    fi
}

# Function to run the playbook
run_playbook() {
    local state=$1
    local extra_vars="state=$state interface_name=$INTERFACE_NAME"
    local inventory="$PROJECT_DIR/inventory/localhost.yml"
    local ansible_config="$PROJECT_DIR/playbooks/ansible-vxlan.cfg"

    # Add optional overrides
    if [[ -n "${NETWORK_IP:-}" ]]; then
        extra_vars="$extra_vars network_ip=$NETWORK_IP"
    fi

    if [[ -n "${BASE_INTERFACE:-}" ]]; then
        extra_vars="$extra_vars base_interface=$BASE_INTERFACE"
    fi

    if [[ -n "${REMOTE_ENDPOINT:-}" ]]; then
        extra_vars="$extra_vars remote_endpoint=$REMOTE_ENDPOINT"
    fi

    echo -e "${BLUE}Running Ansible playbook...${NC}"
    echo "Command: ANSIBLE_CONFIG=$ansible_config ansible-playbook $PLAYBOOK -i $inventory -e \"$extra_vars\""
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}DRY RUN MODE - Would execute:${NC}"
        echo "ANSIBLE_CONFIG=$ansible_config ansible-playbook $PLAYBOOK -i $inventory -e \"$extra_vars\" --check"
        return 0
    fi

    ANSIBLE_CONFIG="$ansible_config" ansible-playbook "$PLAYBOOK" -i "$inventory" -e "$extra_vars"
}

# Function to show current status
show_status() {
    echo -e "${BLUE}Current VXLAN Interface Status:${NC}"
    echo "================================"

    if ip link show "$INTERFACE_NAME" &>/dev/null; then
        echo -e "${GREEN}✅ VXLAN interface '$INTERFACE_NAME' exists${NC}"
        echo ""
        echo "Interface Details:"
        ip addr show "$INTERFACE_NAME"
        echo ""
        echo "VXLAN Configuration:"
        ip -d link show "$INTERFACE_NAME" | grep vxlan || echo "No VXLAN details found"
    else
        echo -e "${YELLOW}❌ VXLAN interface '$INTERFACE_NAME' does not exist${NC}"
    fi
}

# Function to create VXLAN
create_vxlan() {
    echo -e "${GREEN}Creating VXLAN endpoint for $INTERFACE_NAME network...${NC}"
    run_playbook "present"

    if [[ $? -eq 0 && "$DRY_RUN" != "true" ]]; then
        echo ""
        echo -e "${GREEN}Operation completed successfully!${NC}"
        echo "Run '$0 status' to check the current state."
    fi
}

# Function to delete VXLAN
delete_vxlan() {
    echo -e "${YELLOW}Deleting VXLAN endpoint for $INTERFACE_NAME network...${NC}"
    run_playbook "absent"

    if [[ $? -eq 0 && "$DRY_RUN" != "true" ]]; then
        echo ""
        echo -e "${GREEN}Operation completed successfully!${NC}"
        echo "VXLAN interface has been removed."
    fi
}

# Parse command line arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        create|delete|status|help)
            COMMAND="$1"
            shift
            ;;
        --interface)
            INTERFACE_NAME="$2"
            shift 2
            ;;
        --network-ip)
            NETWORK_IP="$2"
            shift 2
            ;;
        --base-if)
            BASE_INTERFACE="$2"
            shift 2
            ;;
        --remote)
            REMOTE_ENDPOINT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Check if command is provided
if [[ -z "$COMMAND" ]]; then
    echo -e "${RED}Error: No command specified${NC}"
    usage
    exit 1
fi

# Execute based on command
case $COMMAND in
    create)
        check_prerequisites
        create_vxlan
        ;;
    delete)
        check_prerequisites
        delete_vxlan
        ;;
    status)
        show_status
        ;;
    help)
        usage
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        usage
        exit 1
        ;;
esac