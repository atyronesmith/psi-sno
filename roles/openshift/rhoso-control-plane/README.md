# OpenShift RHOSO Control Plane Role

This role deploys Red Hat OpenStack Services on OpenShift (RHOSO) 18.0 control plane services on an existing OpenShift cluster.

## Description

RHOSO 18.0 represents a major architectural shift where OpenStack services run as containers on OpenShift rather than traditional bare-metal deployments. This role automates the deployment of the RHOSO control plane including:

- Operator installation (RHOSO, Cert-Manager, MetalLB)
- Namespace and RBAC setup
- Storage configuration
- Network configuration
- Service deployment (Keystone, Glance, Cinder, Neutron, Nova, Horizon)
- Load balancer configuration
- Monitoring and validation

## Requirements

- OpenShift 4.16.0 or later
- Minimum 8 CPU cores and 16GB memory in the cluster
- Storage class for persistent volumes
- Network connectivity to Red Hat repositories

## Usage

### Basic Deployment

```yaml
- name: Deploy RHOSO control plane
  include_role:
    name: openshift/rhoso-control-plane
    tasks_from: deploy_control_plane
```

### Available Tasks

- `deploy_control_plane`: Full RHOSO control plane deployment
- `validate_cluster`: Validate OpenShift cluster readiness
- `status_check`: Check RHOSO deployment status
- `cleanup`: Remove RHOSO control plane services

## License

MIT