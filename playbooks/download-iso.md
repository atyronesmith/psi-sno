# Ansible Playbook: Download Red Hat CoreOS (RHCOS) ISO

## Overview

This Ansible playbook automates the download of the Red Hat CoreOS (RHCOS) installation ISO for a specific version and architecture of OpenShift Container Platform. The logic is based on the manual steps outlined in the official "Installing on a single node" guide (Chapter 2, Section 2.2.1).

The primary goal of this playbook is to provide a reliable, repeatable, and efficient way to obtain the correct ISO without manual intervention. It is idempotent, meaning it can be run multiple times without changing the result beyond the initial execution.

## Features

* **Idempotent:** Checks if the correct ISO file already exists and exits gracefully if it does, saving time and bandwidth.
* **Efficient:** Checks if the `openshift-install` utility is already in the system's `PATH` and uses it if available, avoiding unnecessary downloads.
* **Automated:** If `openshift-install` is not found, it automatically downloads and extracts the correct version.
* **Reliable:** Uses the `openshift-install` binary to find the official download URL for the RHCOS ISO, ensuring the correct image is always retrieved.
* **Lint Compliant:** The playbook adheres to `ansible-lint` best practices, ensuring code quality, security, and maintainability.
* **Configurable:** Key parameters like OpenShift version, architecture, and download location are easily configured in the `vars` section.

## Requirements

* **Ansible:** The playbook requires Ansible to be installed on the machine where you intend to run it.

## Configuration

Before running the playbook, you can adjust the variables in the `vars` section to match your requirements.

```yaml
  vars:
    # Specify the OpenShift Container Platform version to use if downloading.
    # Example: "latest-4.18", "4.17.0"
    ocp_version: "latest-4.18"

    # Specify the target host architecture.
    # Valid options include: "x86_64", "aarch64", "s390x", "ppc64le"
    architecture: "x86_64"

    # Define the local directory where artifacts will be downloaded if needed.
    download_dir: "/tmp/openshift_install"
```

## Usage

1.  Save the playbook as a YAML file (e.g., `download_rhcos.yml`).
2.  Modify the variables in the `vars` section as needed.
3.  Run the playbook from your terminal using the following command:

```bash
ansible-playbook download_rhcos.yml
```

## Playbook Logic

The playbook executes the following steps in order:

1.  **Check for Existing ISO:** It first checks if the target ISO file (e.g., `rhcos-latest-4.18-x86_64.iso`) already exists in the `download_dir`. If it does, the playbook prints a success message and exits.
2.  **Check for `openshift-install`:** If the ISO is not found, it checks for the `openshift-install` executable in the system's `PATH`.
3.  **Download `openshift-install` (if needed):** If `openshift-install` is not in the `PATH`, the playbook downloads the corresponding tarball from the official OpenShift mirror, extracts the binary into the `download_dir`, and makes it executable.
4.  **Retrieve ISO URL:** The playbook runs `openshift-install coreos print-stream-json` to get a JSON output containing the download URLs for all artifacts. It then parses this JSON to find the precise URL for the `metal` ISO matching the specified `architecture`.
5.  **Download RHCOS ISO:** Using the URL discovered in the previous step, the playbook downloads the ISO file into the `download_dir`.
6.  **Report Success:** Upon successful download, a final message confirms the location of the downloaded ISO and the `openshift-install` binary that was used.
