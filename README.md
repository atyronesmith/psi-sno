# PSI SNO Deployment Automation

[![Ansible Lint](https://github.com/your-org/psi-sno/workflows/Ansible%20Lint/badge.svg)](https://github.com/your-org/psi-sno/actions)

Automated deployment of Single-Node OpenShift (SNO) clusters with Red Hat OpenStack Services on OpenShift (RHOSO) in Red Hat's PSI environment.

## 🚀 Quick Start

```bash
# 1. Clone and setup
git clone <repository-url> psi-sno
cd psi-sno

# 2. Setup environment (REQUIRED)
source ~/psi/bin/activate    # Activate Python virtual environment
export OS_CLOUD=psi          # Set OpenStack cloud environment

# 3. Install dependencies
make install-deps

# 4. Configure secrets
cp secrets/pull-secret.txt.example secrets/pull-secret.txt
cp secrets/ssh-key.pub.example secrets/ssh-key.pub
# Edit files with your actual secrets

# 5. Verify environment
openstack server list  # Test connectivity

# 6. Deploy to PSI environment (with project bypass)
make deploy-psi PROJECT=my-cluster
```

## 📁 Repository Structure

```
├── 📄 README.md                    # This file
├── 📄 ansible.cfg                  # Ansible configuration
├── 📄 requirements.yml             # Ansible collection requirements
├── 📄 Makefile                     # Common tasks automation
├── 📄 .ansible-lint                # Ansible lint configuration
├── 📄 .yamllint                    # YAML lint configuration
│
├── 📁 docs/                        # Documentation
│   ├── 📄 deployment-guide.md
│   ├── 📄 troubleshooting.md
│   └── 📁 examples/
│
├── 📁 playbooks/                   # Ansible playbooks
│   ├── 📄 deploy.yml               # Main deployment playbook
│   ├── 📄 destroy.yml              # Environment cleanup
│   ├── 📄 bootstrap.yml            # Cluster bootstrap
│   ├── 📄 create-iso.yml           # ISO creation
│   └── 📁 maintenance/             # Maintenance playbooks
│
├── 📁 inventory/                   # Inventory management
│   ├── 📁 group_vars/              # Global variables
│   ├── 📁 host_vars/               # Host-specific variables
│   └── 📁 environments/            # Environment configs
│       ├── 📁 dev/                 # Development environment
│       ├── 📁 staging/             # Staging environment
│       └── 📁 prod/                # Production environment
│
├── 📁 roles/                       # Ansible roles
│   ├── 📁 common/                  # Shared utilities
│   ├── 📁 openshift/               # OpenShift-specific roles
│   │   ├── 📁 iso-builder/         # ISO creation and management
│   │   ├── 📁 cluster-deployer/    # Cluster deployment
│   │   └── 📁 bootstrap/           # Bootstrap operations
│   ├── 📁 infrastructure/          # Infrastructure roles
│   │   ├── 📁 openstack-networks/  # Network management
│   │   ├── 📁 security-groups/     # Security configuration
│   │   └── 📁 floating-ips/        # IP management
│   └── 📁 dns/                     # DNS management
│       ├── 📁 coredns-server/      # DNS server deployment
│       └── 📁 cluster-dns/         # Cluster DNS configuration
│
├── 📁 configs/                     # Configuration templates
│   ├── 📁 openshift/               # OpenShift configurations
│   │   ├── 📁 install-configs/     # Installation configurations
│   │   └── 📁 machine-configs/     # Machine configurations
│   ├── 📁 kubernetes/              # Kubernetes manifests
│   │   ├── 📁 networking/          # Network configurations
│   │   ├── 📁 storage/             # Storage configurations
│   │   └── 📁 monitoring/          # Monitoring setup
│   └── 📁 infrastructure/          # Infrastructure configs
│
├── 📁 scripts/                     # Utility scripts
│   └── 📁 helpers/                 # Helper scripts
│
├── 📁 tests/                       # Testing framework
│   ├── 📁 unit/                    # Unit tests
│   ├── 📁 integration/             # Integration tests
│   └── 📁 molecule/                # Molecule testing
│
├── 📁 build/                       # Build artifacts (gitignored)
│   ├── 📁 isos/                    # Generated ISO files
│   ├── 📁 projects/                # Project directories
│   └── 📁 generated/               # Generated configurations
│
└── 📁 secrets/                     # Secrets (gitignored)
    ├── 📄 .keep
    ├── 📄 pull-secret.txt.example
    └── 📄 ssh-key.pub.example
```

## 🛠️ Prerequisites

### System Requirements
- **Python** 3.8+ (recommended: 3.11+)
- **Git** for version control
- **Container Runtime**: Podman (for coreos-installer)

### Python Virtual Environment Setup (Recommended)

Using a Python virtual environment is strongly recommended to avoid conflicts with system packages:

```bash
# Create a virtual environment
python3 -m venv venv

# Activate the virtual environment
source venv/bin/activate

# Upgrade pip to latest version
pip install --upgrade pip

# Install Ansible and required tools
pip install ansible-core ansible-lint yamllint python-openstackclient

# Install Ansible collections
ansible-galaxy collection install -r requirements.yml
```

**Note**: Always activate your virtual environment before running Ansible commands:
```bash
source venv/bin/activate
```

To deactivate the virtual environment when done:
```bash
deactivate
```

### Alternative: System-wide Installation
If you prefer system-wide installation (not recommended for production use):

```bash
# Install required tools system-wide
pip install ansible-core ansible-lint yamllint python-openstackclient
ansible-galaxy collection install -r requirements.yml
```

### Additional Tools
- **OpenShift CLI Tools**: `openshift-install`, `oc`
  ```bash
  # Download from Red Hat's official releases
  curl -O https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-install-linux.tar.gz
  curl -O https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz

  # Extract and add to PATH
  tar -xzf openshift-install-linux.tar.gz
  tar -xzf openshift-client-linux.tar.gz
  sudo mv openshift-install oc /usr/local/bin/
  ```

### Environment Setup
```bash
# Source OpenStack credentials
source ~/psi-openrc.sh

# Verify connectivity
openstack server list
```

## 🎯 Usage

### 🚀 Quick Reference (Most Common Commands)

```bash
# Environment setup (REQUIRED FIRST)
source ~/psi/bin/activate && export OS_CLOUD=psi

# Deploy with project bypass (recommended)
make deploy-psi PROJECT=my-cluster

# Create server from existing volume
make boot-sno PROJECT=my-cluster      # or just: make boot-sno (interactive)

# Clean up networks and routers
./scripts/manage-psi.sh clean-networks -y
./scripts/manage-psi.sh clean-routers -y

# Delete project (various modes)
make delete-project                    # Interactive
make delete-project-y                  # Skip confirmation
make delete-project-name PROJECT=name  # Target specific project

# Check what's available
make help  # Full list of commands
```

### Environment Management

Deploy to different environments using environment-specific inventories:

```bash
# PSI environment (interactive project selection)
make deploy-psi

# PSI environment (bypass interactive selection)
make deploy-psi PROJECT=my-cluster-name

# Using Ansible directly with project bypass
ansible-playbook -i inventory/environments/psi playbooks/deploy.yml -e project_name=my-cluster
```

### Server Management

```bash
# Create server that boots from existing volume (auto-makes bootable)
make boot-sno PROJECT=my-cluster      # Non-interactive with specific project
make boot-sno                         # Interactive project selection

# Using Ansible directly
ansible-playbook playbooks/create-volume-boot-server.yml -e project_name=my-cluster
ansible-playbook playbooks/create-volume-boot-server.yml  # Interactive selection
```

### Network and Router Management

Use the enhanced PSI management script:

```bash
# List PSI networks
./scripts/manage-psi.sh list-networks

# Clean orphaned networks (interactive)
./scripts/manage-psi.sh clean-networks

# Clean orphaned networks (auto-confirm)
./scripts/manage-psi.sh clean-networks -y

# List PSI routers
./scripts/manage-psi.sh list-routers

# Clean orphaned routers (interactive)
./scripts/manage-psi.sh clean-routers

# Clean orphaned routers (auto-confirm)
./scripts/manage-psi.sh clean-routers -y
```

### Common Operations

```bash
# Create installation ISO
make create-iso

# Bootstrap cluster
make bootstrap-psi
ansible-playbook playbooks/bootstrap.yml

# Get cluster information
ansible-playbook playbooks/maintenance/get-cluster-info.yml

# Start/Stop cluster
ansible-playbook playbooks/maintenance/start-cluster.yml
ansible-playbook playbooks/maintenance/stop-cluster.yml

# Destroy environment
make destroy-psi
ansible-playbook playbooks/destroy.yml
```

### Development Workflow

```bash
# Activate virtual environment (if using)
source venv/bin/activate

# Install dependencies
make install-deps

# Run linting
make lint

# Run syntax check
make syntax-check

# Run all tests
make test

# Clean build artifacts
make clean

# Deactivate virtual environment when done
deactivate
```

### Project Management

The system creates project directories in `build/projects/` for each deployment. These contain installation assets, ISOs, and configuration files.

```bash
# List current projects
ls -la build/projects/

# Interactive project deletion (choose project + confirm)
make delete-project

# Interactive project selection, skip confirmation
make delete-project-y

# Delete specific project by name (no prompts)
make delete-project-name PROJECT=my-cluster

# Using Ansible directly
ansible-playbook playbooks/delete-project.yml
ansible-playbook playbooks/delete-project.yml -e auto_confirm=true
ansible-playbook playbooks/delete-project.yml -e auto_confirm=true -e target_project=my-cluster
```

**Enhanced Project Deletion Features:**
- ✅ **Interactive Selection**: Lists all available project directories with numbered selection
- ✅ **Project Details**: Shows project details (size, file count, last modified)
- ✅ **Content Summary**: Displays project contents summary
- ✅ **Auto-Confirm Modes**: Skip confirmation prompts with `-y` variants
- ✅ **Targeted Deletion**: Delete specific projects by name
- ✅ **Audit Trail**: Creates deletion log for audit trail
- ✅ **Verification**: Verifies successful deletion and shows remaining projects
- ✅ **Safety Checks**: Multiple confirmation layers to prevent accidental deletion

### Virtual Environment Management

For daily development workflow with virtual environments:

```bash
# Start working session
cd psi-sno
source venv/bin/activate

# Update dependencies (when requirements change)
pip install --upgrade -r requirements.txt
ansible-galaxy collection install -r requirements.yml --upgrade

# Check virtual environment status
pip list | grep ansible

# Create requirements.txt from current environment
pip freeze > requirements.txt

# End working session
deactivate
```

## ⚙️ Configuration

### Global Configuration

Edit `inventory/group_vars/all.yml` for global settings:

```yaml
# OpenStack Configuration
project_provider_network: "provider_net_shared_3"
sno_flavor: "g.memory.xxl"
sno_volume_size: 120

# OpenShift Configuration
ocp_version: "4.18.10"

# DNS Configuration
dns_fip: "10.0.108.151"
```

### Environment-Specific Configuration

Override settings in `inventory/environments/psi/group_vars/all.yml`:

```yaml
# PSI environment overrides
sno_flavor: "g.memory.large"
sno_volume_size: 80
bootstrap_timeout_minutes: 20
```

### OpenShift Install Configuration

Create install configurations in `configs/openshift/install-configs/examples/`:

```yaml
apiVersion: v1
baseDomain: nfv.com
metadata:
  name: my-cluster
networking:
  machineNetwork:
  - cidr: 192.168.150.0/24
# ... rest of configuration
```

## 🔐 Secrets Management

### Setup Secrets

1. **Pull Secret**: Get from [Red Hat Console](https://console.redhat.com/openshift/install/pull-secret)
   ```bash
   cp secrets/pull-secret.txt.example secrets/pull-secret.txt
   # Edit with your actual pull secret
   ```

2. **SSH Key**:
   ```bash
   cp secrets/ssh-key.pub.example secrets/ssh-key.pub
   # Add your public SSH key
   ```

### Security Best Practices

- Never commit actual secrets to version control
- Use environment-specific secret files when needed
- Rotate secrets regularly
- Use OpenStack application credentials where possible

## 🏗️ Architecture

### Network Architecture
- **SNO Network**: Primary cluster network (192.168.122.0/24)
- **OpenStack Network**: Secondary network for RHOSO services
- **VLAN Configuration**:
  - VLAN 20: Internal API (172.17.0.0/24)
  - VLAN 21: Storage (172.18.0.0/24)
  - VLAN 22: Tenant (172.19.0.0/24)

### DNS Architecture
- **CoreDNS Server**: Centralized DNS for multiple clusters
- **Local DNS**: dnsmasq configuration for development
- **Automatic Records**: API and application route records

### Storage Architecture
- **Local Storage**: Direct-attached storage for cluster nodes
- **OpenStack Volumes**: Persistent storage for applications
- **Container Storage**: OpenShift Container Storage when needed

## 🔄 CI/CD Integration

### GitHub Actions

The repository includes GitHub Actions workflows for:
- Ansible lint validation
- YAML syntax checking
- Playbook syntax validation

### Pre-commit Hooks

Install pre-commit hooks for local development:

```bash
pip install pre-commit
pre-commit install
```

### Testing Strategy

```bash
# Unit tests (when available)
make test-unit

# Integration tests
make test-integration

# Molecule tests
cd roles/common && molecule test
```

## 🐛 Troubleshooting

### Environment Setup Issues

**Problem**: Commands fail with "command not found" or undefined variables
**Solution**: Ensure proper environment setup (this is the #1 cause of issues):
```bash
# Check virtual environment
echo $VIRTUAL_ENV  # Should show /home/user/psi
(psi) should appear in your prompt

# Check OpenStack environment
echo $OS_CLOUD     # Should show "psi"
openstack server list  # Should work without errors
```

### DNS Configuration Issues

**Problem**: `ansible_default_ipv4` undefined during DNS configuration
**Solution**: The DNS role now includes automatic fact gathering for remote DNS hosts:
```bash
# This is handled automatically in the updated DNS role
# If you encounter issues, check DNS server connectivity:
ssh fedora@10.0.108.151 "ip route show default"
```

**Problem**: DNS cluster files not created (`nfv.com.cluster` missing)
**Solution**: Recent fixes ensure both DNS files are created:
```bash
# Verify DNS files were created
ssh fedora@10.0.108.151 "ls -la /etc/coredns/clusters/ | grep nfv"
# Should show both nfv.com.cluster and nfv.com.record
```

### Deployment Issues

**Problem**: Deployment hangs on project selection prompts
**Solution**: Use PROJECT parameter to bypass interactive selection:
```bash
# Instead of this (interactive):
make deploy-psi

# Use this (non-interactive):
make deploy-psi PROJECT=my-cluster-name
```

**Problem**: Volume boot server fails because volume isn't bootable
**Solution**: The enhanced volume boot task automatically makes volumes bootable:
```bash
# This now happens automatically in create_volume_boot_server task
# Check volume bootable status:
openstack volume show my-volume -f value -c bootable
```

### Variable Name Issues

**Problem**: Undefined variables like `project_instance_ip_sno`
**Solution**: Use correct variable names (fixed in recent updates):
- ✅ `project_instance_ip` (for SNO network IP)
- ✅ `project_instance_ip_os` (for OpenStack network IP)
- ✅ `project_fip` (for floating IP)

### Common Issues

**Bootstrap Timeout:**
```bash
# Check server console
openstack console log show <server-name>

# SSH to server (if accessible)
ssh core@<server-ip>
sudo journalctl -u bootkube.service
```

**DNS Resolution Issues:**
```bash
# Check local DNS configuration
cat /etc/NetworkManager/dnsmasq.d/99-*.conf

# Restart NetworkManager
sudo systemctl restart NetworkManager
```

**Network Connectivity:**
```bash
# Test from debug pod
oc apply -f configs/kubernetes/simple-pod.yaml
oc exec -it net-debug-container -- /bin/bash
```

### Log Locations
- **Installation logs**: `build/projects/<cluster-name>/.openshift_install.log`
- **Bootstrap logs**: On cluster node at `/var/log/`
- **OpenStack SDK logs**: `/tmp/openstack_sdk.log`

### Validation Commands

```bash
# Validate configuration
make validate-dev

# Check OpenStack resources
openstack server list --name <project-name>
openstack network list --name <project-name>

# Verify security groups
openstack security group list
openstack floating ip list
```

## 📖 Documentation

- [Deployment Guide](docs/deployment-guide.md) - Detailed deployment instructions
- [Troubleshooting Guide](docs/troubleshooting.md) - Common issues and solutions
- [Architecture Overview](docs/architecture.md) - System architecture details
- [Examples](docs/examples/) - Step-by-step examples

## 🤝 Contributing

### Development Setup

1. Fork the repository
2. Clone your fork and setup virtual environment:
   ```bash
   git clone <your-fork-url> psi-sno
   cd psi-sno
   make setup-venv
   source venv/bin/activate
   ```
3. Create a feature branch
4. Make changes and test
5. Run linting: `make lint`
6. Submit a pull request

**Note**: Always work within the virtual environment to ensure consistent dependencies.

### Code Standards

- All Ansible code must pass `ansible-lint`
- YAML files must pass `yamllint`
- Use meaningful commit messages
- Document any new features
- Test changes in development environment

### Role Development

When creating new roles:

```bash
# Create role structure
ansible-galaxy role init roles/my-new-role

# Ensure proper metadata
cat > roles/my-new-role/meta/main.yml << EOF
---
galaxy_info:
  author: PSI SNO Team
  description: Description of the role
  license: MIT
  min_ansible_version: "2.14"
dependencies: []
EOF
```

## 📋 Migration Guide

If migrating from the old repository structure:

1. **Run Migration Script**:
   ```bash
   chmod +x migrate-psi-sno.sh
   ./migrate-psi-sno.sh
   ```

2. **Validate Migration**:
   ```bash
   chmod +x validate-migration.sh
   ./validate-migration.sh
   ```

3. **Test New Structure**:
   ```bash
   make test
   make deploy-dev --check
   ```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For issues and questions:
- Check the [troubleshooting guide](docs/troubleshooting.md)
- Review [GitHub Issues](https://github.com/your-org/psi-sno/issues)
- Consult Red Hat documentation for RHOSO

When reporting issues, include:
- Ansible playbook output
- OpenStack resource states
- OpenShift installation logs
- Network configuration details

## 📊 Project Status

### ✅ Recent Improvements (Latest Updates)

- ✅ **DNS Configuration Fixes**: Resolved `ansible_default_ipv4` undefined errors with automatic fact gathering
- ✅ **Volume Boot Server**: New functionality to create servers that boot from existing volumes (auto-bootable)
- ✅ **Enhanced Project Management**: Multiple delete modes with auto-confirm and targeted deletion
- ✅ **PROJECT Parameter Support**: Bypass interactive prompts with `PROJECT=name` parameter
- ✅ **Network/Router Management**: Enhanced `manage-psi.sh` script for infrastructure cleanup
- ✅ **Environment Setup Documentation**: Comprehensive setup guide with troubleshooting
- ✅ **Automated Fixes**: Volume bootable status automatically corrected when needed
- ✅ **Variable Name Consistency**: Fixed undefined variable issues in deployment summaries

### ✅ Core Functionality Status

- ✅ Repository restructuring complete
- ✅ Ansible lint compliance
- ✅ CI/CD pipeline setup
- ✅ Environment separation
- ✅ Documentation updates
- ✅ DNS role enhancements
- ✅ Server management automation
- ✅ Interactive and non-interactive deployment modes
- 🔄 Additional testing and validation
- 📋 Advanced features and integrations

## ⚡ Environment Setup (CRITICAL)

**Before running ANY commands, you MUST set up your environment:**

```bash
# 1. Activate Python virtual environment
source ~/psi/bin/activate

# 2. Set OpenStack cloud environment
export OS_CLOUD=psi

# 3. Enable bash tab completion (optional but recommended)
source completion.bash

# 4. Verify setup
which python     # Should show virtual environment path
which ansible    # Should show virtual environment path
openstack server list  # Should list your servers
```

**Visual confirmation:** Your prompt should show `(psi)` when the virtual environment is active.

### 🚀 Tab Completion Features

After sourcing `completion.bash`, you get smart tab completion:

```bash
# Tab completion for make targets
make <TAB><TAB>         # Shows all available targets

# Smart PROJECT parameter completion
make deploy-psi P<TAB>  # Completes to PROJECT=
make boot-sno PROJECT=<TAB>  # Shows available projects from build/projects/

# Quick reference command
show_make_targets       # Lists all targets organized by category
```