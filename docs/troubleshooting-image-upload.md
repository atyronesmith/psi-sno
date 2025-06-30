# OpenStack Image Upload Troubleshooting Guide

## Issue: "Upload an image" task starts but never completes

The `openstack.cloud.image` module in the `openshift/iso-builder` role may start uploading an ISO image but hang indefinitely without completing.

## Root Causes

### 1. **Timeout Configuration Issues**
The current configuration in `roles/openshift/iso-builder/tasks/make_iso.yml` has a timeout of only 300 seconds (5 minutes):

```yaml
- name: Upload an image from a local file named {{ metadata_location }}/{{ project_iso_image }}
  openstack.cloud.image:
    name: "{{ project_iso_image }}"
    container_format: bare
    disk_format: iso
    state: present
    visibility: shared
    filename: "{{ metadata_location }}/{{ project_iso_image }}"
    timeout: 300  # Only 5 minutes - too short for large ISOs
    sdk_log_path: "{{ metadata_location }}/openstack_sdk.log"
    sdk_log_level: DEBUG
```

**Problem**: ISO files are typically 500MB-2GB+, requiring much longer upload times.

### 2. **OpenStack SDK Internal Timeout Bug**
There's a known bug in older versions of the OpenStack SDK where the internal timeout is hardcoded to 60 seconds regardless of the `timeout` parameter passed to the module.

### 3. **Network/Connectivity Issues**
- Slow network connections between Ansible host and OpenStack API
- Network interruptions during large file transfers
- OpenStack Glance service overloaded or misconfigured

### 4. **OpenStack Service Timeouts**
- HAProxy timeout for OpenStack services
- Glance API timeout settings
- Swift backend timeout (if using Swift as Glance backend)

## Solutions

### Solution 1: Increase Timeout Values (Recommended)

Update the timeout in `roles/openshift/iso-builder/tasks/make_iso.yml`:

```yaml
- name: Upload an image from a local file named {{ metadata_location }}/{{ project_iso_image }}
  openstack.cloud.image:
    name: "{{ project_iso_image }}"
    container_format: bare
    disk_format: iso
    state: present
    visibility: shared
    filename: "{{ metadata_location }}/{{ project_iso_image }}"
    timeout: 3600  # Increase to 1 hour
    sdk_log_path: "{{ metadata_location }}/openstack_sdk.log"
    sdk_log_level: DEBUG
  register: image_upload_result
```

### Solution 2: Add Retry Logic

Implement retry logic for upload failures:

```yaml
- name: Upload an image with retry logic
  openstack.cloud.image:
    name: "{{ project_iso_image }}"
    container_format: bare
    disk_format: iso
    state: present
    visibility: shared
    filename: "{{ metadata_location }}/{{ project_iso_image }}"
    timeout: 3600
    sdk_log_path: "{{ metadata_location }}/openstack_sdk.log"
    sdk_log_level: DEBUG
  register: image_upload_result
  retries: 3
  delay: 30
  until: image_upload_result is succeeded
```

### Solution 3: Pre-check for Existing Image

Add a check to avoid re-uploading existing images:

```yaml
- name: Check if image already exists
  openstack.cloud.image_info:
    name: "{{ project_iso_image }}"
  register: existing_image_info

- name: Upload image only if it doesn't exist
  openstack.cloud.image:
    name: "{{ project_iso_image }}"
    container_format: bare
    disk_format: iso
    state: present
    visibility: shared
    filename: "{{ metadata_location }}/{{ project_iso_image }}"
    timeout: 3600
    sdk_log_path: "{{ metadata_location }}/openstack_sdk.log"
    sdk_log_level: DEBUG
  register: image_upload_result
  when: existing_image_info.images | length == 0
```

### Solution 4: Manual Upload Fallback

Add a fallback to manual OpenStack CLI upload:

```yaml
- name: Upload image using OpenStack CLI as fallback
  ansible.builtin.shell: |
    openstack image create \
      --progress \
      --disk-format iso \
      --container-format bare \
      --file "{{ metadata_location }}/{{ project_iso_image }}" \
      "{{ project_iso_image }}"
  when: image_upload_result is failed
  register: cli_upload_result
```

### Solution 5: Configure OpenStack Service Timeouts

If you have access to OpenStack configuration, increase service timeouts:

**For HAProxy (if used):**
```
timeout client 3600s
timeout server 3600s
```

**For Glance API:**
```ini
[DEFAULT]
image_cache_stall_time = 3600
```

## Debugging Steps

### 1. Check OpenStack SDK Log
```bash
tail -f {{ metadata_location }}/openstack_sdk.log
```

### 2. Monitor Upload Progress
```bash
# Check if image is being created
openstack image list | grep {{ project_iso_image }}

# Monitor image status
watch -n 5 "openstack image show {{ project_iso_image }} -c status -c size"
```

### 3. Check Network Connectivity
```bash
# Test connectivity to OpenStack API
curl -I $OS_AUTH_URL

# Check available bandwidth
iperf3 -c <openstack-endpoint>
```

### 4. Check Available Disk Space
```bash
# Check local disk space
df -h {{ metadata_location }}

# Check OpenStack Glance storage
openstack quota show --usage
```

## Environment Variables for Debugging

Set these environment variables for more verbose output:

```bash
export OS_DEBUG=1
export ANSIBLE_DEBUG=1
export ANSIBLE_VERBOSITY=3
```

## Alternative: Manual Upload Process

If automation continues to fail, use manual upload:

```bash
# Navigate to project directory
cd {{ metadata_location }}

# Upload using OpenStack CLI with progress
openstack image create \
  --progress \
  --disk-format iso \
  --container-format bare \
  --public \
  --file "{{ project_iso_image }}" \
  "{{ project_iso_image }}"
```

## Prevention

### 1. Pre-upload Health Checks
- Verify network connectivity
- Check available storage quota
- Validate ISO file integrity

### 2. Monitoring
- Set up monitoring for long-running uploads
- Alert on upload failures
- Track upload performance metrics

### 3. Configuration Management
- Use consistent timeout values across all OpenStack modules
- Document timeout requirements for different file sizes
- Regular testing of upload functionality

## Related Issues

- [Ansible Issue #25775](https://github.com/ansible/ansible/issues/25775) - os_image upload timeout bug
- [Red Hat Bug 1792500](https://bugzilla.redhat.com/show_bug.cgi?id=1792500) - Ansible completed but overcloud deploy command hangs

## See Also

- [OpenStack Image Upload Best Practices](https://docs.openstack.org/glance/latest/)
- [Ansible OpenStack Cloud Collection Documentation](https://docs.ansible.com/ansible/latest/collections/openstack/cloud/image_module.html)