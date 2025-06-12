# PSI SNO Deployment Automation

[![Ansible Lint](https://github.com/your-org/psi-sno/workflows/Ansible%20Lint/badge.svg)](https://github.com/your-org/psi-sno/actions)

Automated deployment of Single-Node OpenShift (SNO) clusters with Red Hat OpenStack Services on OpenShift (RHOSO) in Red Hat's PSI environment.

## 🚀 Quick Start

```bash
# 1. Clone and setup
git clone <repository-url> psi-sno
cd psi-sno

# 2. Install dependencies
make install-deps

# 3. Configure secrets
cp secrets/pull-secret.txt.example secrets/pull-secret.txt
cp secrets/ssh-key.pub.example secrets/ssh-key.pub
# Edit files with your actual secrets

# 4. Source OpenStack credentials
#source ~/psi-openrc.sh
This repo assumes a cloud.yaml exists and that OS_CLOUD is set to the PSI cloud

# 5. Deploy to development
make deploy-dev
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

### Required Tools
- **Ansible** (2.14+) with collections:
  ```bash
  pip install ansible-core ansible-lint yamllint
  ansible-galaxy collection install -r requirements.yml
  ```
- **OpenShift CLI Tools**: `openshift-install`, `oc`
- **Container Runtime**: Podman (for coreos-installer)
- **OpenStack CLI**: `python-openstackclient`

### Environment Setup
```bash
# Source OpenStack credentials
source ~/psi-openrc.sh

# Verify connectivity
openstack server list
```

## 🎯 Usage

### Environment Management

Deploy to different environments using environment-specific inventories:

```bash
# Development environment
make deploy-dev
ansible-playbook -i inventory/environments/dev playbooks/deploy.yml

# Staging environment
ansible-playbook -i inventory/environments/staging playbooks/deploy.yml

# Production environment
ansible-playbook -i inventory/environments/prod playbooks/deploy.yml
```

### Common Operations

```bash
# Create installation ISO
make create-iso-dev
ansible-playbook playbooks/create-iso.yml

# Bootstrap cluster
make bootstrap-dev
ansible-playbook playbooks/bootstrap.yml

# Get cluster information
ansible-playbook playbooks/maintenance/get-cluster-info.yml

# Start/Stop cluster
ansible-playbook playbooks/maintenance/start-cluster.yml
ansible-playbook playbooks/maintenance/stop-cluster.yml

# Destroy environment
make destroy-dev
ansible-playbook playbooks/destroy.yml
```

### Development Workflow

```bash
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

Override settings in `inventory/environments/{env}/group_vars/all.yml`:

```yaml
# Development overrides
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
2. Create a feature branch
3. Make changes and test
4. Run linting: `make lint`
5. Submit a pull request

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

- ✅ Repository restructuring complete
- ✅ Ansible lint compliance
- ✅ CI/CD pipeline setup
- ✅ Environment separation
- ✅ Documentation updates
- 🔄 Additional testing and validation
- 📋 Advanced features and integrations