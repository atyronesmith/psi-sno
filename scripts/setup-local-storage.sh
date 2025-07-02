#!/bin/bash

# Setup Local Storage for RHOSO
# Updated for Single Node OpenShift with correct persistent volume structure

set -euo pipefail

# Configuration - SNO optimized storage setup
BASE_PATH="/mnt/openstack"
STORAGE_SERVICES=("rabbitmq" "mariadb" "galera" "glance" "cinder")
STORAGE_CLASS="local-storage"

echo "=== PSI Local Storage Setup (SNO Optimized) ==="
echo "Setting up local storage directories for RHOSO services on Single Node OpenShift..."

# Function to create storage directories using oc debug (for SNO)
create_storage_directories() {
    local node_name=$1
    echo "Creating storage directories on node: ${node_name}..."

    oc debug node/$node_name -- chroot /host bash -c "
        mkdir -p ${BASE_PATH}/pv1 \
                 ${BASE_PATH}/pv2 \
                 ${BASE_PATH}/pv3 \
                 ${BASE_PATH}/pv4 \
                 ${BASE_PATH}/pv5 &&
        chmod 755 ${BASE_PATH}/pv* &&
        echo '✅ Storage directories created:' &&
        ls -la ${BASE_PATH}/
    "
}

# Check cluster access and setup storage
if command -v oc &> /dev/null && oc cluster-info &> /dev/null; then
    echo ""
    echo "=== OpenShift Cluster Detected ==="

    NODE_NAME=$(oc get nodes -o jsonpath='{.items[0].metadata.name}')
    echo "Target node: ${NODE_NAME}"

    # Create storage directories using oc debug
    create_storage_directories "$NODE_NAME"

    echo ""
    echo "=== Applying Persistent Volumes ==="
    echo "Applying PV manifests from lib/storage/persistent-volumes.yaml..."

    if [ -f "lib/storage/persistent-volumes.yaml" ]; then
        oc apply -f lib/storage/persistent-volumes.yaml
        echo "✅ Persistent volumes applied successfully!"

        echo ""
        echo "=== Verifying Storage Setup ==="
        echo "Available persistent volumes:"
        oc get pv | grep -E "(rabbitmq|mariadb|galera|glance|cinder)" || echo "No OpenStack PVs found yet..."

    else
        echo "❌ Error: lib/storage/persistent-volumes.yaml not found"
        echo "Please ensure you're running from the project root directory"
        exit 1
    fi

else
    echo ""
    echo "=== Cluster Not Accessible ==="
    echo "OpenShift cluster is not accessible. Please ensure:"
    echo "1. You're logged into the cluster: oc login"
    echo "2. The cluster is running and accessible"
    echo "3. You have the necessary permissions"
    exit 1
fi

echo ""
echo "=== Setup Complete ==="
echo "✅ Storage directories created: ${BASE_PATH}/pv{1..5}"
echo "✅ Persistent volumes applied and ready"
echo "✅ Storage mapping:"
echo "   - pv1: RabbitMQ (10Gi)"
echo "   - pv2: MariaDB (10Gi)"
echo "   - pv3: Galera (10Gi)"
echo "   - pv4: Glance (50Gi)"
echo "   - pv5: Cinder (20Gi)"
echo ""
echo "🎯 Ready to deploy RHOSO with: make deploy-psi PROJECT=yourproject"