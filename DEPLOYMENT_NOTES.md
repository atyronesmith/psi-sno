# RHOSO Single Node OpenShift (SNO) Deployment Notes

## Overview
This document describes the configuration changes made to optimize Red Hat OpenStack Services on OpenShift (RHOSO) for Single Node OpenShift deployments.

## Key Changes Applied

### 1. Service Replica Optimization
All services have been optimized for SNO with `replicas: 1` instead of the default `replicas: 3`:

- **RabbitMQ**: `replicas: 1` (was 3)
- **Galera**: `replicas: 1` (was 3)
- **Memcached**: `replicas: 1` (was 3)
- **OVN DB Cluster**: `replicas: 1` (was 3)
- **OVN Northd**: `replicas: 1` (was 3)

### 2. Storage Configuration
- **RabbitMQ Storage**: Updated from `1Gi` to `10Gi` to match PV requirements
- **Storage Path**: Uses `/mnt/openstack/pv{1-5}` structure
- **Persistent Volume Mapping**:
  - `pv1`: RabbitMQ (10Gi)
  - `pv2`: MariaDB (10Gi)
  - `pv3`: Galera (10Gi)
  - `pv4`: Glance (50Gi)
  - `pv5`: Cinder (20Gi)

### 3. Automated Storage Setup
- **Script**: `scripts/setup-local-storage.sh` - Fully automated storage setup
- **Make Target**: `make setup-storage` - One-command storage preparation
- **Integration**: Automatically creates directories and applies persistent volumes

## Deployment Workflow

### Prerequisites
```bash
# Activate virtual environment
source ~/psi/bin/activate

# Set OpenStack cloud
export OS_CLOUD=psi

# Verify cluster access
oc cluster-info
```

### Complete Deployment
```bash
# 1. Setup storage infrastructure
make setup-storage

# 2. Deploy RHOSO with specific project
make deploy-psi PROJECT=psi-example

# 3. Monitor deployment
oc get pods -n openstack
oc get openstackcontrolplane -n openstack
```

### Storage-Only Setup
```bash
# If you only need to setup storage
make setup-storage
```

## Files Modified

### Configuration Templates
- `roles/openshift/rhoso-control-plane/templates/openstack-control-plane.yaml.j2`
  - Updated all service replicas to 1 for SNO compatibility
  - Fixed RabbitMQ storage request to 10Gi

### Storage Infrastructure
- `scripts/setup-local-storage.sh` - Completely rewritten for SNO
- `lib/storage/persistent-volumes.yaml` - Persistent volume definitions
- `Makefile` - Enhanced setup-storage target

### Documentation
- `.cursorrules` - Updated with current cluster status and deployment notes
- `DEPLOYMENT_NOTES.md` - This file

## Troubleshooting

### Common Issues
1. **RabbitMQ Pods Pending**: Ensure storage directories exist and PVs are available
2. **Storage Mount Failures**: Run `make setup-storage` to create directories
3. **Replica Scaling Errors**: RabbitMQ clusters don't support scale-down; delete and recreate

### Verification Commands
```bash
# Check storage setup
oc get pv | grep -E "(rabbitmq|mariadb|galera|glance|cinder)"

# Check service status
oc get pods -n openstack | grep -E "(rabbitmq|galera|memcached)"

# Check control plane status
oc get openstackcontrolplane -n openstack -o yaml
```

## Success Indicators
- All service pods show `1/1 Running` status
- RabbitMQ cluster shows `AllReplicasReady: True`
- OpenStackControlPlane progresses past RabbitMQ to next services
- Storage volumes are `Bound` to correct services

## Performance Notes
- SNO resource constraints require 1 replica for all services
- Storage I/O is optimized for local storage on single node
- Memory limits are set appropriately for consolidated deployment

---
*Last updated: After successful RabbitMQ replica reduction and storage optimization*
