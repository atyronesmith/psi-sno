#!/bin/bash
#
# generate-secrets.sh
# Generate OpenStack secrets for Kustomize deployments from passwords file
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$PROJECT_ROOT/secrets"
PASSWORDS_FILE="$SECRETS_DIR/passwords.yaml"
OUTPUT_FILE="$PROJECT_ROOT/lib/secrets/osp-secret.yaml"

echo "🔑 Generating OpenStack secrets for Kustomize deployment..."

# Check if passwords file exists
if [ ! -f "$PASSWORDS_FILE" ]; then
    echo "⚠️  Passwords file not found: $PASSWORDS_FILE"
    echo "📁 Copying example file..."
    cp "$SECRETS_DIR/passwords.yaml.example" "$PASSWORDS_FILE"
    echo "✏️  Please edit $PASSWORDS_FILE with your actual passwords"
    echo "🔒 Remember to set secure file permissions: chmod 600 $PASSWORDS_FILE"
fi

# Load passwords from YAML file
echo "📖 Loading passwords from $PASSWORDS_FILE..."

# Function to get password from YAML file and base64 encode it
get_password() {
    local key="$1"
    local default="$2"
    local value
    value=$(grep "^${key}:" "$PASSWORDS_FILE" 2>/dev/null | sed 's/.*: *"\?\([^"]*\)"\?/\1/' || echo "$default")
    echo -n "$value" | base64 -w 0
}

# Extract passwords and encode them
ADMIN_PASSWORD=$(get_password "admin_password" "admin123")
DATABASE_PASSWORD=$(get_password "database_password" "database123")
RABBIT_PASSWORD=$(get_password "rabbit_password" "rabbit123")
SERVICE_PASSWORD=$(get_password "service_password" "service123")
PLACEMENT_PASSWORD=$(get_password "placement_password" "placement123")
KEYSTONE_PASSWORD=$(get_password "keystone_password" "keystone123")
GLANCE_PASSWORD=$(get_password "glance_password" "glance123")
CINDER_PASSWORD=$(get_password "cinder_password" "cinder123")
NEUTRON_PASSWORD=$(get_password "neutron_password" "neutron123")
NOVA_PASSWORD=$(get_password "nova_password" "nova123")
HEAT_PASSWORD=$(get_password "heat_password" "heat123")
HORIZON_PASSWORD=$(get_password "horizon_password" "horizon123")

echo "🏗️  Generating secret manifest..."

# Generate the secret YAML
cat > "$OUTPUT_FILE" << EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: osp-secret
  namespace: openstack
type: Opaque
data:
  # Base64 encoded OpenStack service passwords
  # Generated from secrets/passwords.yaml on $(date)

  # Core infrastructure passwords
  AdminPassword: $ADMIN_PASSWORD
  DatabasePassword: $DATABASE_PASSWORD
  RabbitPassword: $RABBIT_PASSWORD
  ServicePassword: $SERVICE_PASSWORD

  # Individual OpenStack service passwords
  PlacementPassword: $PLACEMENT_PASSWORD
  KeystonePassword: $KEYSTONE_PASSWORD
  GlancePassword: $GLANCE_PASSWORD
  CinderPassword: $CINDER_PASSWORD
  NeutronPassword: $NEUTRON_PASSWORD
  NovaPassword: $NOVA_PASSWORD
  HeatPassword: $HEAT_PASSWORD
  HorizonPassword: $HORIZON_PASSWORD
EOF

echo "✅ Secret manifest generated: $OUTPUT_FILE"
echo "🚀 Ready for Kustomize deployment: cd lib && kustomize build . | oc apply -f -"