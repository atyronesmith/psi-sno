# PSI SNO Deployment Guide

A comprehensive guide for deploying Single-Node OpenShift (SNO) clusters with Red Hat OpenStack Services on OpenShift (RHOSO) in Red Hat's PSI environment.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Initial Setup](#initial-setup)
- [Configuration](#configuration)
- [Deployment Workflow](#deployment-workflow)
- [DNS Configuration](#dns-configuration)
- [Post-Deployment Operations](#post-deployment-operations)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Prerequisites

### Required Tools

- **Ansible** (2.9+) with required collections:
  ```bash
  ansible-galaxy collection install openstack.cloud
  ansible-galaxy collection install community.general
  ```

- **OpenShift CLI Tools:**
  - `openshift-install` (4.18.10+)
  - `oc` client

- **Container Runtime:**
  - Podman (for coreos-installer)

- **OpenStack CLI:**
  - `python-openstackclient`
  - Valid OpenStack credentials sourced

### Environment Setup

1. **Source OpenStack credentials:**
   ```bash
   source ~/psi-openrc.sh
   ```

2. **Verify OpenStack connectivity:**
   ```bash
   openstack server list
   ```

3. **Install required Ansible collections:**
   ```bash
   ansible-galaxy collection install -r requirements.yml
   ```

## Repository Structure

```
psi-sno/
├── README.md
├── deploy.yml                    # Main deployment playbook
├── destroy.yml                   # Cleanup playbook
├── bootstrap.yml                 # Bootstrap operations
├── group_vars/
│   └── all.yaml                  # Global configuration
├── install-configs/              # OpenShift install configurations
├── roles/                        # Ansible roles
│   ├── psi-project/             # ISO creation and project management
│   ├── cluster/                 # Infrastructure deployment
│   ├── add-dns-cluster/         # DNS configuration
│   └── create-dns-server/       # DNS server deployment
├── cr/                          # Kubernetes custom resources
├── butane/                      # Machine config templates
├── projects/                    # Generated project directories
└── iso/                         # Downloaded RHCOS ISOs
```

## Initial Setup

### 1. Clone and Configure Repository

```bash
git clone <repository-url> psi-sno
cd psi-sno
```

### 2. Create Secrets Directory

```bash
mkdir -p secrets
```

### 3. Add Required Secrets

**Pull Secret:**
```bash
# Get from https://console.redhat.com/openshift/install/pull-secret
cp ~/pull-secret.txt secrets/pull-secret.txt
```

**SSH Key:**
```bash
cp ~/.ssh/id_rsa.pub secrets/id_rsa.pub
```

### 4. Review Global Configuration

Edit `group_vars/all.yaml` to match your environment:

```yaml
# PSI provider network
project_provider_network: "provider_net_shared_3"

# OpenShift version
ocp_version: "4.18.10"

# Instance flavors
sno_flavor: "g.memory.xxl"
sno_volume_size: 120

# DNS configuration
dns_fip: "10.0.108.151"  # Your DNS server floating IP
```

## Configuration

### 1. Create Install Configuration

Create a new install config in `install-configs/`:

```bash
cp install-configs/nfv-sno2-install-config.yaml install-configs/my-cluster-install-config.yaml
```

Edit the configuration:

```yaml
apiVersion: v1
baseDomain: nfv.com
metadata:
  name: my-cluster  # Your cluster name
networking:
  machineNetwork:
  - cidr: 192.168.150.0/24  # Your desired network CIDR
# ... rest of configuration
```

### 2. Update Network Configuration (Optional)

If you need custom networking, edit `cr/networking.yaml` and `cr/nncp.yaml` to match your requirements.

## Deployment Workflow

### Step 1: Create Project ISO

Generate the OpenShift installation ISO:

```bash
ansible-playbook create_project_iso.yml
```

**What this does:**
- Prompts you to select an install config
- Downloads RHCOS live ISO if needed
- Creates ignition configuration
- Embeds ignition into ISO
- Prepares project directory

### Step 2: Deploy Infrastructure

Deploy the complete infrastructure stack:

```bash
ansible-playbook deploy.yml
```

**What this creates:**
- OpenStack networks (SNO and OpenStack networks)
- Security groups
- Floating IPs
- Bootable volumes
- Compute instances
- DNS records

### Step 3: Bootstrap Cluster

Wait for and verify cluster bootstrap:

```bash
ansible-playbook bootstrap.yml
```

**What this does:**
- Waits for OpenShift bootstrap completion
- Configures server networking
- Sets up time synchronization

### Step 4: Complete Installation

Monitor the installation progress:

```bash
# From the project directory
cd projects/<your-cluster-name>
openshift-install wait-for bootstrap-complete --log-level=debug
openshift-install wait-for install-complete --log-level=debug
```

## DNS Configuration

### Automatic DNS Setup

The deployment automatically configures DNS using the `add-dns-cluster` role:

- **Remote DNS:** Updates CoreDNS server with cluster records
- **Local DNS:** Configures local dnsmasq for development access

### Manual DNS Verification

Verify DNS resolution:

```bash
dig +short api.my-cluster.nfv.com
dig +short *.apps.my-cluster.nfv.com
```

### DNS Server Management

If you need to deploy a new DNS server:

```bash
ansible-playbook -i roles/create-dns-server/tasks/main.yml --tags deploy,setup
```

## Post-Deployment Operations

### Access Your Cluster

1. **Get cluster credentials:**
   ```bash
   cd projects/<your-cluster-name>
   export KUBECONFIG=auth/kubeconfig
   ```

2. **Verify cluster access:**
   ```bash
   oc get nodes
   oc get clusteroperators
   ```

3. **Get console URL:**
   ```bash
   oc get routes -n openshift-console
   ```

### Apply Custom Resources

Deploy networking and storage configurations:

```bash
oc apply -f cr/networking.yaml
oc apply -f cr/local-storage.yaml
```

### Server Management

**Start/Stop server:**
```bash
# Set server action in group_vars or pass as extra var
ansible-playbook deploy.yml -e server_action=hard-reboot
```

**Get server floating IP:**
```bash
ansible-playbook get_server_fip.yml
```

## Troubleshooting

### Common Issues

**1. Bootstrap Timeout:**
```bash
# Check server console in OpenStack
openstack console log show <server-name>

# SSH to server (if accessible)
ssh core@<server-ip>
sudo journalctl -u bootkube.service
```

**2. DNS Resolution Issues:**
```bash
# Check local DNS configuration
cat /etc/NetworkManager/dnsmasq.d/99-*.conf

# Restart NetworkManager
sudo systemctl restart NetworkManager
```

**3. Network Connectivity:**
```bash
# Test from debug pod
oc apply -f cr/simple-pod.yaml
oc exec -it net-debug-container -- /bin/bash
```

### Log Locations

- **Installation logs:** `projects/<cluster-name>/.openshift_install.log`
- **Bootstrap logs:** On cluster node at `/var/log/`
- **OpenStack SDK logs:** `/tmp/openstack_sdk.log`

### Debug Commands

```bash
# List all OpenStack resources for project
openstack server list --name <project-name>
openstack network list --name <project-name>
openstack volume list --name <project-name>

# Check security groups
openstack security group list
openstack security group show <security-group>

# Verify floating IPs
openstack floating ip list
```

## Cleanup

### Complete Environment Cleanup

Remove all resources for a project:

```bash
ansible-playbook destroy.yml
```

**What this removes:**
- Compute instances
- Volumes
- Networks and subnets
- Routers and interfaces
- Ports
- Security groups
- Floating IPs

### Partial Cleanup

**Remove specific resources:**
```bash
# Remove server only
openstack server delete <server-name>

# Remove volume
openstack volume delete <volume-name>

# Remove network
openstack network delete <network-name>
```

### Local Cleanup

```bash
# Remove project directory
rm -rf projects/<project-name>

# Remove local DNS configuration
sudo rm /etc/NetworkManager/dnsmasq.d/99-<project-name>.conf
sudo systemctl restart NetworkManager
```

## Advanced Usage

### Custom Machine Configs

1. Create Butane templates in `butane/` directory
2. Generate machine configs:
   ```bash
   ansible-playbook gen_machineconfig.yml
   ```
3. Apply generated configs:
   ```bash
   oc apply -f cr-gen/
   ```

### Multiple Clusters

Deploy multiple clusters by:
1. Creating separate install configs
2. Running deployment with different project names
3. Each cluster gets isolated networks and resources

### Network Customization

Modify `cr/nncp.yaml` for custom:
- VLAN IDs
- IP address ranges
- Interface names
- DNS servers

## Support and Contributing

For issues and questions:
- Check the troubleshooting section
- Review OpenStack and OpenShift logs
- Consult Red Hat documentation for RHOSO

When reporting issues, include:
- Ansible playbook output
- OpenStack resource states
- OpenShift installation logs
- Network configuration details