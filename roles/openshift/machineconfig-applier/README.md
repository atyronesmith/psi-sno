# OpenShift MachineConfig Applier Role

This Ansible role applies MachineConfig resources to an OpenShift cluster. It's designed to work with the PSI-SNO deployment environment.

## Purpose

The role applies MachineConfig YAML files to a running OpenShift cluster, specifically designed for applying the converted chrony time synchronization configuration to master nodes.

## Requirements

- Access to a running OpenShift cluster
- `oc` CLI tool configured and authenticated
- Python virtual environment activated (`source ~/psi/bin/activate`)
- OS_CLOUD environment variable set (`export OS_CLOUD=psi`)
- `kubernetes.core` Ansible collection

## Role Variables

### Default Variables (`defaults/main.yml`)

- `machineconfig_file_path`: Path to the MachineConfig YAML file (default: `99-master-chrony-machineconfig.yaml`)
- `wait_for_update`: Whether to wait for MachineConfigPool to be fully updated (default: `false`)
- `wait_timeout`: Timeout for waiting operations in seconds (default: `300`)

### Variable Overrides

You can override these variables when calling the role:

```yaml
- role: openshift/machineconfig-applier
  vars:
    machineconfig_file_path: "path/to/custom-machineconfig.yaml"
    wait_for_update: true
    wait_timeout: 600
```

## Usage

### Via Make Target (Recommended)

```bash
# Apply the chrony MachineConfig to PSI cluster
make apply-machineconfig-psi
```

### Via Ansible Playbook

```bash
# Apply using the playbook
ansible-playbook playbooks/apply-machineconfig.yml

# Apply with custom file path
ansible-playbook playbooks/apply-machineconfig.yml -e machineconfig_file_path="my-custom.yaml"

# Apply and wait for full update
ansible-playbook playbooks/apply-machineconfig.yml -e wait_for_update=true
```

### Direct Role Usage

```yaml
---
- name: Apply MachineConfig
  hosts: localhost
  roles:
    - role: openshift/machineconfig-applier
      vars:
        machineconfig_file_path: "99-master-chrony-machineconfig.yaml"
        wait_for_update: false
```

## What the Role Does

1. **Cluster Connectivity Check**: Verifies OpenShift cluster is accessible
2. **File Validation**: Checks that the MachineConfig file exists
3. **MachineConfig Application**: Applies the configuration to the cluster
4. **Status Monitoring**: Displays MachineConfigPool status and update progress
5. **Optional Wait**: Can wait for the MachineConfigPool to be fully updated

## Expected Behavior

- **Node Reboots**: Master nodes will automatically reboot to apply the new configuration
- **Rolling Updates**: The Machine Config Operator handles rolling updates safely
- **Monitoring**: Use `oc get mcp master -w` to monitor the update progress

## Example Output

```
✅ MachineConfig application completed!

Next steps:
1. Monitor the MachineConfigPool: oc get mcp master -w
2. Check node updates: oc get nodes
3. Verify chrony configuration after nodes reboot

Note: Nodes will automatically reboot to apply the new configuration.
```

## Dependencies

- `kubernetes.core` collection (specified in `meta/main.yml`)
- OpenShift cluster with proper authentication

## Tags

The role supports these tags:
- `apply_machineconfig`: Run only the MachineConfig application tasks
- `machineconfig`: Run all machine configuration related tasks

## Error Handling

The role includes proper error handling for:
- Cluster connectivity issues
- Missing MachineConfig files
- Authentication problems
- Timeout scenarios

## Integration with PSI-SNO Project

This role is specifically designed to work with the PSI-SNO project's chrony MachineConfig (`99-master-chrony-machineconfig.yaml`) that was converted from the Butane template (`99-master-chrony.bu.j2`).

The typical workflow is:
1. Generate Butane templates: `make gen-machineconfig-psi`
2. Convert to MachineConfig format (manual step)
3. Apply to cluster: `make apply-machineconfig-psi`
