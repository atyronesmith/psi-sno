# Red Hat OpenStack Services on OpenShift (RHOSO) 18.0 Reference

## Overview

Red Hat OpenStack Services on OpenShift (RHOSO) 18.0 represents a major architectural shift from traditional Red Hat OpenStack Platform deployments. Starting with version 18.0, Red Hat has rebranded and re-architected OpenStack to run as **containers on OpenShift** rather than traditional bare-metal or VM deployments.

### Key Architectural Changes

- **Product Rebranding**: Red Hat OpenStack Platform → Red Hat OpenStack Services on OpenShift (RHOSO)
- **Container-based Deployment**: All OpenStack services run as containers on OpenShift
- **Kubernetes-native**: Leverages OpenShift/Kubernetes for orchestration and management
- **Control Plane**: Runs on Red Hat OpenShift Container Platform (RHOCP)
- **Data Plane**: Can use pre-provisioned nodes or bare-metal nodes

## Documentation Structure

The RHOSO 18.0 documentation is organized into several key guides:

### Main Documentation URLs
- **Deploying Guide**: `https://docs.redhat.com/en/documentation/red_hat_openstack_services_on_openshift/18.0/html-single/deploying_red_hat_openstack_services_on_openshift/index`
- **Customization Guide**: `https://docs.redhat.com/en/documentation/red_hat_openstack_services_on_openshift/18.0/html-single/customizing_the_red_hat_openstack_services_on_openshift_deployment/index`

## Supported Deployment Topologies

1. **Compact Topology**: Control plane and data plane on the same nodes
2. **Distributed Topology**: Separate control plane and data plane nodes
3. **Edge Deployments**: Optimized for edge computing scenarios

## Major Customization Areas

### 1. Block Storage Service (Cinder) Customization

#### Volume Types
- Create different performance levels for cloud users
- Configure backend-specific properties using Extra Specs
- Support for private volume types with restricted access
- Multi-attach volume types for shared storage scenarios

#### Quality of Service (QoS) Specifications
- **Performance Limits**: IOPS and data transfer rate controls
- **Consumer Types**:
  - `front-end`: Compute service applies limits
  - `back-end`: Storage driver applies limits
  - `both`: Both consumers apply limits
- **Limit Types**: Fixed limits, burst limits, total/read/write limits

#### Volume Encryption
- Encrypted volume types using LUKS provider
- AES-XTS-Plain64 cipher with 256-bit keys
- Front-end encryption control via Compute service

#### Project Quotas
- `volumes`: Number of volumes per project (default: 10)
- `snapshots`: Number of snapshots per project (default: 10)
- `gigabytes`: Total storage in GB per project (default: 1000)
- `per-volume-gigabytes`: Maximum size per volume (default: unlimited)

### 2. Image Service (Glance) Customization

#### Image Import Workflow
- **Distributed Import**: Parallel image processing across nodes
- **URI Filtering**: Allowlist/blocklist for web-download sources
- **Copy-image Method**: Efficient image copying between services
- **Format Validation**: Enable/reject specific disk formats

#### Performance and Security
- **Image Caching**: Improve scalability and reduce network overhead
- **Sparse Upload**: Optimize storage for sparse images
- **Signature Verification**: Validate image integrity and authenticity
- **Metadata Security**: Secure metadef APIs

#### Image Quotas
- Project-specific image storage limits
- Configurable quota enforcement policies

### 3. Object Storage Service (Swift) Customization

#### Ring Management
- **Custom Rings**: Configure storage ring topology
- **Replication Control**: Manage data replication policies
- **Zone Configuration**: Define failure domains

#### Performance Tuning
- **Default Parameters**: Adjust connection timeouts, retry policies
- **Concurrent Operations**: Configure parallel processing limits
- **Health Monitoring**: Set up cluster health checks and alerting

### 4. Shared File Systems Service (Manila) Customization

#### Share Types
- Define different storage backends and capabilities
- Configure protocol support (NFS, CIFS, etc.)
- Set driver-specific properties

#### Quota Management
- **Project Quotas**: Control share count and total capacity
- **User Quotas**: Per-user limits within projects
- **Share Type Quotas**: Limits specific to share types

#### Share Management
- **Manage/Unmanage**: Import existing shares into Manila
- **Migration**: Move shares between backends
- **Snapshot Management**: Configure snapshot policies

## Command-Line Interface

### Key CLI Tools
- **OpenStack CLI**: `openstack` commands for service management
- **Cinder CLI**: `cinder` commands for advanced block storage operations
- **OC CLI**: OpenShift/Kubernetes commands for container management

### Common Operations

#### Block Storage Management
```bash
# Create volume type with QoS
openstack volume type create --property thin_provisioning=true MyVolumeType

# Create QoS specification
openstack volume qos create --property read_iops_sec=5000 --consumer front-end myqoslimits

# Associate QoS with volume type
openstack volume qos associate myqoslimits MyVolumeType
```

#### Project Quota Management
```bash
# View quotas
openstack quota show <project>

# Set volume quota
openstack quota set --volumes 50 <project>

# View quota usage
cinder quota-usage <project_id>
```

## Container Integration

### OpenShift Integration Points
- **Operators**: Custom Kubernetes operators manage OpenStack services
- **ConfigMaps**: Store service configurations
- **Secrets**: Manage credentials and certificates
- **Services**: Kubernetes services expose OpenStack APIs
- **PersistentVolumes**: Storage integration with OpenShift storage

### Monitoring and Logging
- **Prometheus**: Metrics collection for OpenStack services
- **Grafana**: Visualization dashboards
- **OpenShift Logging**: Centralized log aggregation
- **Alerting**: Kubernetes-native alerting for service health

## Migration Considerations

### From Traditional OpenStack
- **Service Architecture**: Container-based vs. systemd services
- **Configuration Management**: Kubernetes ConfigMaps vs. file-based configs
- **Networking**: OpenShift SDN integration
- **Storage**: Kubernetes PV/PVC integration
- **High Availability**: Kubernetes-native HA vs. Pacemaker/HAProxy

### Upgrade Path
- RHOSO 18.0 is a new deployment model, not an in-place upgrade
- Migration tools and procedures for moving workloads
- Data migration strategies for persistent storage

## Best Practices

### Deployment Planning
1. **Resource Requirements**: Plan CPU, memory, and storage for OpenShift cluster
2. **Network Design**: Design networks for control plane, data plane, and tenant traffic
3. **Storage Strategy**: Choose appropriate storage backends for different workloads
4. **Security Configuration**: Implement proper RBAC and network policies

### Operations
1. **Monitoring**: Implement comprehensive monitoring for both OpenShift and OpenStack layers
2. **Backup Strategy**: Plan for both application data and configuration backups
3. **Disaster Recovery**: Design cross-site replication and recovery procedures
4. **Scaling**: Plan for horizontal scaling of both compute and storage resources

## Related Technologies

### Integration Points
- **Red Hat OpenShift Container Platform**: Underlying container orchestration
- **Red Hat Ceph Storage**: Primary storage backend for RHOSO
- **Open Virtual Network (OVN)**: Networking backend
- **MetalLB**: Load balancing for bare-metal deployments
- **Cert-Manager**: Certificate lifecycle management

## Support and Lifecycle

### Support Model
- Follows OpenShift support lifecycle
- Container-based updates and patching
- Operator-managed upgrades

### Version Compatibility
- Requires specific OpenShift versions
- Storage backend compatibility matrix
- Client tool version requirements

---

**Last Updated**: $(date)
**Related Documentation**:
- [PSI-SNO Deployment Guide](../README.md)
- [Butane Template Processing](butane-template-processing.md)
- [Troubleshooting Guide](troubleshooting-image-upload.md)