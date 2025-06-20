#!/bin/bash

# Complete PSI SNO Repository Setup Script
# This script performs the full migration and ensures ansible-lint compliance

set -e

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "========================================"
echo "PSI SNO Repository Complete Setup"
echo "========================================"

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "roles" ]; then
    echo "Error: This script must be run from the root of the PSI SNO repository"
    exit 1
fi

# Create backup
echo "Creating backup..."
if [ -d "../psi-sno-backup-$TIMESTAMP" ]; then
    rm -rf "../psi-sno-backup-$TIMESTAMP"
fi
cp -r . "../psi-sno-backup-$TIMESTAMP"
echo "Backup created at: ../psi-sno-backup-$TIMESTAMP"

# Phase 1: Directory Structure Migration
echo ""
echo "Phase 1: Creating new directory structure..."

# Create all required directories
mkdir -p {docs/examples,playbooks/maintenance}
mkdir -p inventory/{group_vars,host_vars,environments/{dev,staging,prod}}
mkdir -p configs/{openshift/{install-configs/{templates,examples},machine-configs/butane},kubernetes/{networking,storage,monitoring},infrastructure/{openstack,dns}}
mkdir -p {scripts/helpers,tests/{unit,integration,molecule/default}}
mkdir -p {build/{isos,projects,generated},secrets}

# Create role structure
for role_base in common openshift/{iso-builder,cluster-deployer,bootstrap} infrastructure/{openstack-networks,security-groups,floating-ips} dns/{coredns-server,cluster-dns}; do
    mkdir -p "roles/$role_base"/{tasks,defaults,vars,meta,templates,handlers,files}
done

echo "Directory structure created successfully."

# Phase 2: File Migration
echo ""
echo "Phase 2: Migrating existing files..."

# Move playbooks
for playbook in deploy.yml destroy.yml bootstrap.yml create_project_iso.yml; do
    if [ -f "$playbook" ]; then
        target_name="$playbook"
        [ "$playbook" = "create_project_iso.yml" ] && target_name="create-iso.yml"
        mv "$playbook" "playbooks/$target_name"
        echo "Moved $playbook to playbooks/$target_name"
    fi
done

# Move maintenance playbooks
for playbook in read_metadata.yml get_server_fip.yml gen_machineconfig.yml start.yml attach-volume.yml check_fip.yml; do
    if [ -f "$playbook" ]; then
        mv "$playbook" "playbooks/maintenance/"
        echo "Moved $playbook to playbooks/maintenance/"
    fi
done

# Move inventory
if [ -d "group_vars" ]; then
    mv group_vars/* inventory/group_vars/ 2>/dev/null || true
    rmdir group_vars
    echo "Moved group_vars to inventory/group_vars/"
fi

# Move configurations
if [ -d "install-configs" ]; then
    mv install-configs/* configs/openshift/install-configs/examples/ 2>/dev/null || true
    rmdir install-configs
    echo "Moved install-configs to configs/openshift/install-configs/examples/"
fi

if [ -d "cr" ]; then
    mv cr/* configs/kubernetes/ 2>/dev/null || true
    rmdir cr
    echo "Moved cr to configs/kubernetes/"
fi

if [ -d "butane" ]; then
    mv butane/* configs/openshift/machine-configs/butane/ 2>/dev/null || true
    rmdir butane
    echo "Moved butane to configs/openshift/machine-configs/butane/"
fi

if [ -d "host" ]; then
    mv host/* configs/infrastructure/dns/ 2>/dev/null || true
    rmdir host
    echo "Moved host to configs/infrastructure/dns/"
fi

# Move build artifacts
if [ -d "projects" ]; then
    mv projects/* build/projects/ 2>/dev/null || true
    rmdir projects
    echo "Moved projects to build/projects/"
fi

if [ -d "iso" ]; then
    mv iso/* build/isos/ 2>/dev/null || true
    rmdir iso
    echo "Moved iso to build/isos/"
fi

# Phase 3: Role Migration
echo ""
echo "Phase 3: Reorganizing roles..."

# Migrate existing roles
if [ -d "roles/psi-project" ]; then
    mv roles/psi-project/* roles/openshift/iso-builder/ 2>/dev/null || true
    rmdir roles/psi-project
    echo "Migrated psi-project role to openshift/iso-builder"
fi

if [ -d "roles/cluster" ]; then
    mv roles/cluster/* roles/openshift/cluster-deployer/ 2>/dev/null || true
    rmdir roles/cluster
    echo "Migrated cluster role to openshift/cluster-deployer"
fi

if [ -d "roles/add-dns-cluster" ]; then
    mv roles/add-dns-cluster/* roles/dns/cluster-dns/ 2>/dev/null || true
    rmdir roles/add-dns-cluster
    echo "Migrated add-dns-cluster role to dns/cluster-dns"
fi

if [ -d "roles/create-dns-server" ]; then
    mv roles/create-dns-server/* roles/dns/coredns-server/ 2>/dev/null || true
    rmdir roles/create-dns-server
    echo "Migrated create-dns-server role to dns/coredns-server"
fi

# Clean up old directories
for old_dir in vxlan templates tasks; do
    if [ -d "$old_dir" ]; then
        rm -rf "$old_dir"
        echo "Removed old directory: $old_dir"
    fi
done

# Phase 4: Configuration Files
echo ""
echo "Phase 4: Creating configuration files..."

# Create ansible.cfg
cat > ansible.cfg << 'EOF'
[defaults]
inventory = inventory/environments/dev
roles_path = roles
host_key_checking = False
gathering = smart
fact_caching = memory
stdout_callback = yaml
bin_ansible_callbacks = True
collections_path = ~/.ansible/collections
interpreter_python = auto_silent
timeout = 30
forks = 10

[inventory]
enable_plugins = openstack.cloud.openstack

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
pipelining = True
control_path_dir = ~/.ansible/cp

[galaxy]
server_list = automation_hub, galaxy

[galaxy_server.automation_hub]
url = https://console.redhat.com/api/automation-hub/content/published/
auth_url = https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token

[galaxy_server.galaxy]
url = https://galaxy.ansible.com/
EOF

# Create requirements.yml
cat > requirements.yml << 'EOF'
---
collections:
  - name: openstack.cloud
    version: ">=2.0.0"
  - name: community.general
    version: ">=6.0.0"
  - name: ansible.utils
    version: ">=2.0.0"
  - name: kubernetes.core
    version: ">=2.0.0"
  - name: ansible.posix
    version: ">=1.0.0"
EOF

# Create .ansible-lint
cat > .ansible-lint << 'EOF'
---
exclude_paths:
  - build/
  - secrets/
  - .github/
  - docs/
  - tests/molecule/
  - '**/molecule/'
  - '**/*.md'

skip_list:
  - yaml[line-length]
  - name[casing]
  - var-naming[no-role-prefix]

use_default_rules: true

warn_list:
  - experimental
  - ignore-errors

offline: false

supported_ansible:
  - "2.14"
  - "2.15"
  - "2.16"

verbosity: 1
EOF

# Create .yamllint
cat > .yamllint << 'EOF'
---
extends: default

rules:
  line-length:
    max: 120
    level: warning

  indentation:
    spaces: 2
    indent-sequences: true
    check-multi-line-strings: false

  truthy:
    allowed-values: ['true', 'false', 'yes', 'no']
    check-keys: false

  comments:
    min-spaces-from-content: 1

  document-start:
    present: true

  empty-lines:
    max: 2
    max-start: 1
    max-end: 1

ignore: |
  build/
  secrets/
  .github/
  node_modules/
  *.md
EOF

# Create Makefile
cat > Makefile << 'EOF'
.PHONY: help lint lint-fix syntax-check test clean install-deps

help:
    @echo "Available targets:"
    @echo "  help         - Show this help message"
    @echo "  lint         - Run ansible-lint and yamllint"
    @echo "  lint-fix     - Run ansible-lint with auto-fix where possible"
    @echo "  syntax-check - Run ansible syntax check on all playbooks"
    @echo "  test         - Run all tests (lint + syntax)"
    @echo "  install-deps - Install required dependencies"
    @echo "  clean        - Clean build artifacts"
    @echo ""
    @echo "Environment targets:"
    @echo "  deploy-dev   - Deploy to development environment"
    @echo "  destroy-dev  - Destroy development environment"

install-deps:
    pip install --upgrade pip
    pip install ansible-lint ansible-core yamllint
    ansible-galaxy collection install -r requirements.yml

lint:
    @echo "Running ansible-lint..."
    ansible-lint
    @echo "Running yamllint..."
    yamllint .

lint-fix:
    @echo "Running ansible-lint with auto-fix..."
    ansible-lint --fix

syntax-check:
    @echo "Running syntax check on all playbooks..."
    @for playbook in playbooks/*.yml; do \
        if [ -f "$playbook" ]; then \
            echo "Checking $playbook..."; \
            ansible-playbook --syntax-check "$playbook"; \
        fi \
    done
    @for playbook in playbooks/maintenance/*.yml; do \
        if [ -f "$playbook" ]; then \
            echo "Checking $playbook..."; \
            ansible-playbook --syntax-check "$playbook"; \
        fi \
    done

test: lint syntax-check
    @echo "All tests passed!"

clean:
    @echo "Cleaning build artifacts..."
    rm -rf build/projects/*
    rm -rf build/generated/*
    rm -rf build/isos/*
    find . -name "*.retry" -delete
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

deploy-dev:
    ansible-playbook -i inventory/environments/dev playbooks/deploy.yml

destroy-dev:
    ansible-playbook -i inventory/environments/dev playbooks/destroy.yml

create-iso-dev:
    ansible-playbook -i inventory/environments/dev playbooks/create-iso.yml

bootstrap-dev:
    ansible-playbook -i inventory/environments/dev playbooks/bootstrap.yml
EOF

# Phase 5: Create GitHub Actions
echo "Creating GitHub Actions workflow..."
mkdir -p .github/workflows
cat > .github/workflows/ansible-lint.yml << 'EOF'
---
name: Ansible Lint

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  ansible-lint:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install ansible-lint ansible-core yamllint
          ansible-galaxy collection install -r requirements.yml

      - name: Run ansible-lint
        run: ansible-lint

      - name: Run yamllint
        run: yamllint .

      - name: Run ansible syntax check
        run: |
          find playbooks/ -name "*.yml" -exec ansible-playbook --syntax-check {} \;
EOF

# Phase 6: Update gitignore
echo "Updating .gitignore..."
cat >> .gitignore << 'EOF'

# Build artifacts
build/
secrets/*.txt
secrets/*.pub
secrets/*.pem
secrets/*.key
!secrets/*.example
!secrets/.keep

# Generated configs
generated/
*.retry
.ansible/
**/__pycache__/
*.pyc
EOF

# Phase 7: Create secrets examples
echo "Creating secrets examples..."
touch secrets/.keep
cat > secrets/pull-secret.txt.example << 'EOF'
# Place your Red Hat pull secret here
# Get it from: https://console.redhat.com/openshift/install/pull-secret
{"auths":{"cloud.openshift.com":{"auth":"...","email":"..."}}}
EOF

cat > secrets/ssh-key.pub.example << 'EOF'
# Place your SSH public key here
# Example: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB... user@host
EOF

# Phase 8: Create inventory files
echo "Creating inventory configurations..."

# Create main inventory configuration
cat > inventory/group_vars/all.yml << 'EOF'
---
# Global configuration for PSI SNO deployments

# ============================================================================
# OpenStack Configuration
# ============================================================================
project_provider_network: "provider_net_shared_3"

# Security groups
psi_sno_sg_sno: "sno-psi-sg-sno"
psi_sno_sg_openstack: "sno-psi-sg-openstack"
psi_sno_router_sno: "sno-psi-router"

# Network configuration
project_openstack_cidr: "192.168.200.0/24"
project_instance_ip_os: "{{ (project_openstack_cidr | ansible.utils.ipaddr('100')) | ansible.utils.ipaddr('address') }}"

# ============================================================================
# Compute Configuration
# ============================================================================
sno_flavor: "g.memory.xxl"
sno_volume_size: 120

# ============================================================================
# OpenShift Configuration
# ============================================================================
ocp_version: "4.18.10"
ocp_arch: "x86_64"

# Build directories
iso_download_dir: "{{ playbook_dir }}/../build/isos"
project_build_dir: "{{ playbook_dir }}/../build/projects"

# ISO configuration
sno_iso_image_name: "rhcos-live.iso"
sno_iso_base: "rhcos-live"

# ============================================================================
# Machine Config Generation
# ============================================================================
butane_templates_dir: "../configs/openshift/machine-configs/butane"
ignition_output_dir: "../build/generated"
butane_executable: "butane"

# ============================================================================
# DNS Configuration
# ============================================================================
dns_name: "nfv-dns"
dns_cidr: "192.168.100.0/24"
dns_instance_ip: "{{ dns_cidr | ansible.utils.ipaddr('100') | ansible.utils.ipaddr('address') }}"
dns_fip: "10.0.108.151"
dns_root: "/etc/coredns/clusters"

# ============================================================================
# Timeouts and Retry Configuration
# ============================================================================
bootstrap_timeout_minutes: 30
wait_timeout_minutes: 30
EOF

# Create environment-specific inventories
for env in dev staging prod; do
    echo "localhost ansible_connection=local" > "inventory/environments/$env/inventory.yml"

    # Create environment-specific group vars
    cat > "inventory/environments/$env/group_vars/all.yml" << EOF
---
# $env environment overrides
environment_name: "$env"
EOF
done

# Development environment specific settings
cat >> inventory/environments/dev/group_vars/all.yml << 'EOF'

# Use smaller resources for development
sno_flavor: "g.memory.large"
sno_volume_size: 80

# Development DNS server
dns_fip: "10.0.108.150"

# Development network ranges
project_openstack_cidr: "192.168.100.0/24"

# Faster timeouts for development
bootstrap_timeout_minutes: 20
wait_timeout_minutes: 15
EOF

# Phase 9: Create role metadata files
echo "Creating role metadata files..."

for role_path in roles/common roles/openshift/{iso-builder,cluster-deployer,bootstrap} roles/infrastructure/{openstack-networks,security-groups,floating-ips} roles/dns/{coredns-server,cluster-dns}; do
    if [ -d "$role_path" ]; then
        role_name=$(basename "$role_path")
        cat > "$role_path/meta/main.yml" << EOF
---
galaxy_info:
  author: PSI SNO Team
  description: $role_name role for PSI SNO deployments
  company: Red Hat
  license: MIT
  min_ansible_version: "2.14"
  platforms:
    - name: EL
      versions:
        - "8"
        - "9"
  galaxy_tags:
    - openstack
    - openshift
    - sno

dependencies: []
EOF

        # Create empty default files
        echo "---" > "$role_path/defaults/main.yml"
        echo "---" > "$role_path/handlers/main.yml"
        echo "---" > "$role_path/vars/main.yml"
    fi
done

# Phase 10: Update task files for lint compliance
echo ""
echo "Phase 10: Updating task files for ansible-lint compliance..."

# Function to update a file with proper FQCN
update_file_for_lint() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "  Updating $file..."

        # Create backup
        cp "$file" "$file.bak"

        # Update module names to use FQCN
        sed -i 's/^  debug:/  ansible.builtin.debug:/g' "$file"
        sed -i 's/^  set_fact:/  ansible.builtin.set_fact:/g' "$file"
        sed -i 's/^  fail:/  ansible.builtin.fail:/g' "$file"
        sed -i 's/^  assert:/  ansible.builtin.assert:/g' "$file"
        sed -i 's/^  include_tasks:/  ansible.builtin.include_tasks:/g' "$file"
        sed -i 's/^  include_role:/  ansible.builtin.include_role:/g' "$file"
        sed -i 's/^  import_tasks:/  ansible.builtin.import_tasks:/g' "$file"
        sed -i 's/^  template:/  ansible.builtin.template:/g' "$file"
        sed -i 's/^  copy:/  ansible.builtin.copy:/g' "$file"
        sed -i 's/^  file:/  ansible.builtin.file:/g' "$file"
        sed -i 's/^  stat:/  ansible.builtin.stat:/g' "$file"
        sed -i 's/^  command:/  ansible.builtin.command:/g' "$file"
        sed -i 's/^  shell:/  ansible.builtin.shell:/g' "$file"
        sed -i 's/^  lineinfile:/  ansible.builtin.lineinfile:/g' "$file"
        sed -i 's/^  systemd:/  ansible.builtin.systemd:/g' "$file"
        sed -i 's/^  systemd_service:/  ansible.builtin.systemd_service:/g' "$file"
        sed -i 's/^  pause:/  ansible.builtin.pause:/g' "$file"
        sed -i 's/^  find:/  ansible.builtin.find:/g' "$file"
        sed -i 's/^  tempfile:/  ansible.builtin.tempfile:/g' "$file"
        sed -i 's/^  slurp:/  ansible.builtin.slurp:/g' "$file"
        sed -i 's/^  wait_for:/  ansible.builtin.wait_for:/g' "$file"
        sed -i 's/^  user:/  ansible.builtin.user:/g' "$file"
        sed -i 's/^  package:/  ansible.builtin.package:/g' "$file"
        sed -i 's/^  get_url:/  ansible.builtin.get_url:/g' "$file"
        sed -i 's/^  unarchive:/  ansible.builtin.unarchive:/g' "$file"

        # Fix name templates that might cause lint issues
        sed -i 's/ # noqa name\[template\]//g' "$file"

        # Add quiet: true to assert tasks if not present
        if grep -q "ansible.builtin.assert:" "$file" && ! grep -A5 "ansible.builtin.assert:" "$file" | grep -q "quiet:"; then
            sed -i '/ansible\.builtin\.assert:/,/^[[:space:]]*[^[:space:]]/ {
                /that:/a\
    quiet: true
            }' "$file"
        fi
    fi
}

# Update all YAML files in roles and playbooks
find roles/ playbooks/ -name "*.yml" -type f | while read -r file; do
    update_file_for_lint "$file"
done

# Phase 11: Create essential role task files
echo ""
echo "Phase 11: Creating essential role task files..."

# Create common role validation task
cat > roles/common/tasks/main.yml << 'EOF'
---
- name: Run common validation tasks
  ansible.builtin.include_tasks: validate-config.yml
EOF

cat > roles/common/tasks/validate-config.yml << 'EOF'
---
- name: Validate OpenStack connectivity
  openstack.cloud.auth:
  register: os_auth
  failed_when: false

- name: Fail if OpenStack authentication failed
  ansible.builtin.fail:
    msg: "OpenStack authentication failed. Please check your credentials."
  when: os_auth.failed | default(false)

- name: Validate required OpenStack resources exist
  block:
    - name: Check if provider network exists
      openstack.cloud.networks_info:
        name: "{{ project_provider_network }}"
      register: provider_net_check

    - name: Fail if provider network doesn't exist
      ansible.builtin.fail:
        msg: "Provider network '{{ project_provider_network }}' not found"
      when: provider_net_check.networks | length == 0

- name: Validate required files exist
  ansible.builtin.stat:
    path: "{{ item }}"
  register: file_check
  failed_when: not file_check.stat.exists
  loop:
    - "{{ playbook_dir }}/../secrets/pull-secret.txt"
    - "{{ playbook_dir }}/../secrets/ssh-key.pub"
  loop_control:
    label: "{{ item }}"
EOF

# Create security groups role
mkdir -p roles/infrastructure/security-groups/tasks
cat > roles/infrastructure/security-groups/tasks/main.yml << 'EOF'
---
- name: Create SNO security groups
  ansible.builtin.include_tasks: create_sno_security_groups.yml

- name: Create OpenStack security groups
  ansible.builtin.include_tasks: create_openstack_security_groups.yml
EOF

cat > roles/infrastructure/security-groups/tasks/create_sno_security_groups.yml << 'EOF'
---
- name: Ensure SNO security group exists
  openstack.cloud.security_group:
    state: present
    name: "{{ psi_sno_sg_sno }}"
    description: "Security group for SNO clusters"
    security_group_rules:
      - protocol: icmp
        remote_ip_prefix: "0.0.0.0/0"
        description: "Allow ICMP"
        direction: ingress
      - protocol: tcp
        port_range_min: 22
        port_range_max: 22
        remote_ip_prefix: "0.0.0.0/0"
        description: "SSH access"
        direction: ingress
      - protocol: tcp
        port_range_min: 80
        port_range_max: 80
        remote_ip_prefix: "0.0.0.0/0"
        description: "HTTP access"
        direction: ingress
      - protocol: tcp
        port_range_min: 443
        port_range_max: 443
        remote_ip_prefix: "0.0.0.0/0"
        description: "HTTPS access"
        direction: ingress
      - protocol: tcp
        port_range_min: 6443
        port_range_max: 6443
        remote_ip_prefix: "0.0.0.0/0"
        description: "Kubernetes API access"
        direction: ingress
      - protocol: tcp
        port_range_min: 22623
        port_range_max: 22623
        remote_ip_prefix: "0.0.0.0/0"
        description: "Machine Config Server access"
        direction: ingress
EOF

cat > roles/infrastructure/security-groups/tasks/create_openstack_security_groups.yml << 'EOF'
---
- name: Create VXLAN security group for the OS network
  openstack.cloud.security_group:
    state: present
    name: "{{ psi_sno_sg_openstack }}"
    description: "VXLAN security group"
    security_group_rules:
      - protocol: tcp
        port_range_min: 4789
        port_range_max: 4789
        remote_ip_prefix: "0.0.0.0/0"
        direction: ingress
        description: "VXLAN traffic"
      - protocol: udp
        port_range_min: 4789
        port_range_max: 4789
        remote_ip_prefix: "0.0.0.0/0"
        direction: ingress
        description: "VXLAN traffic UDP"
EOF

# Phase 12: Create backward compatibility symlinks
echo ""
echo "Phase 12: Creating backward compatibility symlinks..."
ln -sf playbooks/deploy.yml deploy.yml
ln -sf playbooks/destroy.yml destroy.yml
ln -sf playbooks/bootstrap.yml bootstrap.yml
ln -sf inventory/group_vars/all.yml common_vars.yml

# Phase 13: Clean up backup files
echo ""
echo "Phase 13: Cleaning up..."
find . -name "*.bak" -delete 2>/dev/null || true

echo ""
echo "========================================"
echo "Setup completed successfully!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Install dependencies: make install-deps"
echo "2. Configure secrets:"
echo "   cp secrets/pull-secret.txt.example secrets/pull-secret.txt"
echo "   cp secrets/ssh-key.pub.example secrets/ssh-key.pub"
echo "   # Edit with your actual secrets"
echo "3. Test the setup: make test"
echo "4. Deploy to development: make deploy-dev"
echo ""
echo "Repository structure:"
echo "- playbooks/           # All playbooks"
echo "- inventory/           # Inventory and variables"
echo "- roles/               # Organized roles"
echo "- configs/             # Configuration templates"
echo "- build/               # Build artifacts (gitignored)"
echo "- secrets/             # Secrets (gitignored)"
echo ""
echo "Backup available at: ../psi-sno-backup-$TIMESTAMP"
echo "Remove backup when satisfied with migration: rm -rf ../psi-sno-backup-$TIMESTAMP"
