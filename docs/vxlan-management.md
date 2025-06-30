# VXLAN Management for internalapi Network

This system provides automated management of VXLAN endpoints for the internalapi network in the psi-sno project. The configuration is **dynamically loaded** from existing YAML files, ensuring consistency with your infrastructure setup.

## 🔄 Dynamic Configuration

The VXLAN management system automatically reads configuration from:

### Primary Configuration Files
- **`configs/kubernetes/vxlan-nncp.yaml`** - VXLAN interface settings
  - **Filters by type**: Only processes interfaces where `type: vxlan`
  - **Extracts**: Interface name, VXLAN ID, destination port
  - **Smart detection**: Matches remote IP with localhost interface IP to auto-detect base interface
- **`configs/kubernetes/networking.yaml`** - Network ranges and IP allocation
  - Network CIDR, IP ranges, IPAM configuration
- **`inventory/group_vars/all.yml`** - Remote VXLAN endpoint configuration
  - **`remote_vxlan_fip`**: Remote VXLAN endpoint IP address

### Intelligent Configuration Extraction

#### VXLAN Interface Detection
The system now intelligently processes VXLAN interfaces:

1. **Type Filtering**: Only examines interfaces with `type: vxlan`
2. **Data Extraction**: From VXLAN interfaces, extracts:
   - `name` - Interface name (e.g., "internalapi")
   - `vxlan.id` - VXLAN ID (e.g., "20")
   - `vxlan.destination-port` - Destination port (e.g., 4789)

3. **Remote Endpoint**: From inventory variables:
   - `remote_vxlan_fip` - Remote endpoint IP (e.g., "10.37.146.188")

4. **Smart Base Interface Detection**:
   - Scans all localhost network interfaces
   - Matches the `remote_vxlan_fip` IP with local interface IPs
   - Automatically selects the interface that has the same IP as the remote endpoint
   - Falls back to config file `base-iface` if no match found
   - Can be overridden with `--base-if` parameter

#### Network Configuration
- **Network Range**: From `networking.yaml` → `spec.config.ipam.range`
- **IP Range**: From `networking.yaml` → `spec.config.ipam.range_start` and `range_end`

### Configuration Logic Flow
```
Configuration Sources:
├── vxlan-nncp.yaml
│   ├── Filter: type == "vxlan"
│   └── Extract: name, vxlan.id, destination-port
├── inventory/group_vars/all.yml
│   └── Extract: remote_vxlan_fip
└── Smart Detection:
    ├── Scan localhost interfaces: ip addr show
    ├── Match remote_vxlan_fip (10.37.146.188) with local IPs
    └── Auto-select base interface (e.g., eno1)
```

## 🚀 Quick Start

### Using Makefile (Recommended)
```bash
# Create VXLAN endpoint (reads config automatically)
make vxlan-create

# Check status
make vxlan-status

# Delete VXLAN endpoint
make vxlan-delete
```

### Using Helper Script
```bash
# Create with automatic configuration
sudo ./scripts/manage-vxlan.sh create

# Create with overrides
sudo ./scripts/manage-vxlan.sh create --base-if eno1 --network-ip 172.17.0.25

# Check status
./scripts/manage-vxlan.sh status

# Delete
sudo ./scripts/manage-vxlan.sh delete
```

### Using Ansible Playbook Directly

```bash
# Create VXLAN endpoint
ansible-playbook playbooks/manage-vxlan-internalapi.yml -i localhost, -e "state=present"

# Delete VXLAN endpoint
ansible-playbook playbooks/manage-vxlan-internalapi.yml -i localhost, -e "state=absent"

# Create with custom IP
ansible-playbook playbooks/manage-vxlan-internalapi.yml -i localhost, -e "state=present network_ip=172.17.0.20"

# Multiple customizations
ansible-playbook playbooks/manage-vxlan-internalapi.yml \
  -i localhost, \
  -e "state=present" \
  -e "network_ip=172.17.0.50" \
  -e "base_interface=eth0" \
  -e "remote_endpoint=10.37.146.200"
```

## ⚙️ Configuration Override

While the system reads configuration automatically, you can override specific values:

### Available Overrides
- `--interface <name>` - Interface name (default: from config)
- `--network-ip <ip>` - Override IP address
- `--base-if <interface>` - Override base interface
- `--remote <ip>` - Override remote endpoint

### Examples
```bash
# Override base interface (common need)
sudo ./scripts/manage-vxlan.sh create --base-if eno1

# Override IP address
sudo ./scripts/manage-vxlan.sh create --network-ip 172.17.0.100

# Multiple overrides
sudo ./scripts/manage-vxlan.sh create \
  --base-if eno1 \
  --network-ip 172.17.0.50 \
  --remote 10.37.146.200
```

## 📋 Current Configuration

Based on your configuration files, the system will use:

### From vxlan-nncp.yaml (VXLAN interfaces only):
- **Interface**: internalapi (type: vxlan)
- **VXLAN ID**: 20
- **Destination Port**: 4789

### From inventory/group_vars/all.yml:
- **Remote VXLAN FIP**: 10.37.146.188 (`remote_vxlan_fip`)
- **Base Interface**: Auto-detected by matching remote_vxlan_fip with localhost interfaces

### From networking.yaml:
- **Network Range**: 172.17.0.0/24
- **IP Range**: 172.17.0.30 - 172.17.0.70
- **Default IP**: 172.17.0.10 (auto-calculated)

### Smart Interface Detection:
The system will automatically find that `eno1` has IP `10.37.146.188` (matching `remote_vxlan_fip`) and use it as the base interface.

## 🔍 Verification

### Check Interface Status
```bash
# Using the script
./scripts/manage-vxlan.sh status

# Manual verification
ip addr show internalapi
ip -d link show internalapi
```

### Expected Output
```
100: internalapi: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN
    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.10/24 scope global internalapi
    vxlan id 20 remote 10.37.146.188 dev eno1 srcport 0 0 dstport 4789
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. Base Interface Not Found
**Problem**: `Base interface enp4s0 does not exist`
**Solution**: Override with correct interface
```bash
sudo ./scripts/manage-vxlan.sh create --base-if eno1
```

#### 2. Configuration File Not Found
**Problem**: `VXLAN configuration file not found`
**Solution**: Ensure you're running from the project root and files exist:
```bash
ls -la configs/kubernetes/vxlan-nncp.yaml
ls -la configs/kubernetes/networking.yaml
```

#### 3. Permission Denied
**Problem**: Network operations require root privileges
**Solution**: Run with sudo
```bash
sudo ./scripts/manage-vxlan.sh create
```

### Debug Mode
```bash
# Dry run to see what would be executed
sudo ./scripts/manage-vxlan.sh create --dry-run

# Verbose Ansible output
ansible-playbook playbooks/manage-vxlan-internalapi.yml \
  -i localhost, \
  -e "state=present" \
  -vvv
```

## 🏗️ Architecture

### Dynamic Configuration Flow
```
┌─────────────────────┐    ┌──────────────────────┐
│   vxlan-nncp.yaml   │    │   networking.yaml    │
│                     │    │                      │
│ • Interface name    │    │ • Network ranges     │
│ • VXLAN ID         │    │ • IP allocation      │
│ • Base interface   │    │ • IPAM config        │
│ • Remote endpoint  │    │                      │
│ • Destination port │    │                      │
└─────────────────────┘    └──────────────────────┘
           │                          │
           └──────────┬─────────────────┘
                      │
                      ▼
         ┌─────────────────────────┐
         │   Ansible Playbook     │
         │                        │
         │ • Loads both configs   │
         │ • Extracts settings    │
         │ • Applies overrides    │
         │ • Creates VXLAN        │
         └─────────────────────────┘
                      │
                      ▼
         ┌─────────────────────────┐
         │   VXLAN Interface       │
         │                        │
         │ internalapi (VXLAN)     │
         │ ├── ID: 20             │
         │ ├── IP: 172.17.0.x/24  │
         │ ├── Remote: 10.37...   │
         │ └── Base: eno1         │
         └─────────────────────────┘
```

### File Structure
```
psi-sno/
├── configs/kubernetes/
│   ├── vxlan-nncp.yaml      # VXLAN configuration source
│   └── networking.yaml      # Network ranges source
├── playbooks/
│   ├── manage-vxlan-internalapi.yml  # Main playbook
│   └── ansible-vxlan.cfg    # Ansible config for VXLAN
├── scripts/
│   └── manage-vxlan.sh      # Helper script
├── inventory/
│   └── localhost.yml        # Localhost inventory
└── docs/
    └── vxlan-management.md  # This documentation
```

## 🔒 Security Considerations

- **Root Privileges**: Network interface management requires root access
- **Configuration Validation**: All configuration files are validated before use
- **Idempotent Operations**: Safe to run multiple times
- **Error Handling**: Comprehensive error checking and rollback

## 🔄 Integration

### With Existing Workflows
The VXLAN management integrates seamlessly with:
- **OpenShift SNO deployment**: Provides network connectivity
- **RHOSO installation**: Enables internalapi network
- **PSI environment**: Matches existing network topology

### Configuration Consistency
By reading from existing configuration files, the VXLAN setup:
- ✅ Matches your OpenShift network policy
- ✅ Uses consistent IP ranges
- ✅ Follows your network architecture
- ✅ Stays synchronized with infrastructure changes