.PHONY: help lint lint-fix syntax-check test clean install-deps setup-venv activate-venv setup-completion download-iso create-iso create-iso-psi bootstrap-psi validate-psi info-psi start-psi stop-psi deploy-psi destroy-psi health-check-psi logs-psi backup-psi restore-psi vxlan-create vxlan-delete vxlan-status delete-project delete-project-y delete-project-name delete-project-all boot-sno gen-machineconfig-psi apply-machineconfig-psi deploy-nfv-architecture test-nfv-architecture validate-nfv-architecture clean-nfv-architecture setup-storage openstack openstack-init openstack-prep openstack-deploy openstack-workflow

help:
	@echo "Available targets:"
	@echo "  help           - Show this help message"
	@echo ""
	@echo "Development tools:"
	@echo "  setup-venv     - Create and setup Python virtual environment"
	@echo "  activate-venv  - Show instructions to activate virtual environment"
	@echo "  setup-completion - Add bash tab completion to ~/.bashrc"
	@echo "  install-deps   - Install project dependencies"
	@echo "  lint           - Run ansible-lint and yamllint"
	@echo "  lint-fix       - Run ansible-lint with auto-fix"
	@echo "  syntax-check   - Run syntax check on all playbooks"
	@echo "  test           - Run all tests (lint + syntax + molecule)"
	@echo "  clean          - Clean build artifacts and temporary files"
	@echo ""
	@echo "PSI Environment:"
	@echo "  deploy-psi     - Deploy to PSI environment"
	@echo "  deploy-psi PROJECT=name - Deploy specific project (bypasses interactive selection)"
	@echo "  destroy-psi    - Destroy PSI environment"
	@echo "  create-iso-psi - Create ISO for PSI environment"
	@echo "  gen-machineconfig-psi - Generate machine configurations from Butane templates"
	@echo "  apply-machineconfig-psi - Apply MachineConfig to PSI cluster (chrony time sync)"
	@echo "  bootstrap-psi  - Wait for OpenShift bootstrap completion"
	@echo "  validate-psi   - Run validation checks on PSI environment"
	@echo "  info-psi       - Get cluster information"
	@echo "  start-psi      - Start PSI cluster"
	@echo "  stop-psi       - Stop PSI cluster"
	@echo "  health-check-psi - Run health checks on PSI cluster"
	@echo "  logs-psi       - Collect logs from PSI environment"
	@echo "  backup-psi     - Backup PSI cluster configuration"
	@echo "  restore-psi    - Restore PSI cluster from backup"
	@echo ""
	@echo "RHOSO Control Plane:"
	@echo "  deploy-rhoso   - Deploy RHOSO Control Plane"
	@echo "  deploy-rhoso PROJECT=name - Deploy RHOSO for specific project"
	@echo "  deploy-rhoso-psi - Deploy RHOSO Control Plane to PSI (with defaults)"
	@echo ""
	@echo "NFV Architecture (Kustomize-based):"
	@echo "  deploy-nfv-architecture - Deploy NFV validated architecture using Kustomize"
	@echo "  test-nfv-architecture   - Test NFV architecture with dry-run"
	@echo "  validate-nfv-architecture - Validate NFV deployment status"
	@echo "  clean-nfv-architecture  - Clean up NFV architecture resources"
	@echo "  setup-storage          - Setup local storage for OpenStack services"
	@echo "  generate-secrets       - Generate secrets from passwords file"
	@echo ""
	@echo "OpenStack Deployment (install_yamls workflow):"
	@echo "  openstack              - Install OpenStack operators"
	@echo "  openstack-prep         - Prepare dependencies (storage, networking)"
	@echo "  openstack-init         - Initialize OpenStack (prep + operators)"
	@echo "  openstack-deploy       - Deploy OpenStack control plane"
	@echo "  openstack-workflow     - Complete workflow (prep + operators + deploy)"
	@echo ""
	@echo "Server Management:"
	@echo "  boot-sno [PROJECT=name] - Create server that boots from existing volume (interactive if no PROJECT)"
	@echo ""
	@echo "Project Management:"
	@echo "  delete-project      - Interactively delete a project from build/projects/"
	@echo "  delete-project-y    - Select project interactively, skip confirmation prompt"
	@echo "  delete-project-name - Delete specific project: make delete-project-name PROJECT=name"
	@echo "  delete-project-all  - Delete ALL projects: make delete-project-all"
	@echo ""
	@echo "VXLAN management:"
	@echo "  vxlan-create   - Create VXLAN endpoint for internalapi network"
	@echo "  vxlan-delete   - Delete VXLAN endpoint for internalapi network"
	@echo "  vxlan-status   - Show current VXLAN interface status"

setup-venv:
	@echo "Setting up Python virtual environment..."
	@if [ ! -d "venv" ]; then \
		python3 -m venv venv; \
		echo "Virtual environment created at ./venv"; \
	else \
		echo "Virtual environment already exists at ./venv"; \
	fi
	@echo "Activating virtual environment and installing dependencies..."
	@bash -c "source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"
	@bash -c "source venv/bin/activate && ansible-galaxy collection install -r requirements.yml"
	@echo ""
	@echo "Virtual environment setup complete!"
	@echo "To activate: source venv/bin/activate"
	@echo "To deactivate: deactivate"

activate-venv:
	@echo "To activate the virtual environment, run:"
	@echo "  source venv/bin/activate"
	@echo ""
	@echo "To deactivate when done:"
	@echo "  deactivate"

setup-completion:
	@echo "Setting up bash completion for make targets..."
	@if [ -f "completion.bash" ]; then \
		echo "Adding completion.bash to your ~/.bashrc"; \
		echo "" >> ~/.bashrc; \
		echo "# PSI-SNO Makefile completion" >> ~/.bashrc; \
		echo "if [ -f \"$(PWD)/completion.bash\" ]; then" >> ~/.bashrc; \
		echo "    source \"$(PWD)/completion.bash\"" >> ~/.bashrc; \
		echo "fi" >> ~/.bashrc; \
		echo "✅ Completion setup added to ~/.bashrc"; \
		echo "Run 'source ~/.bashrc' or start a new terminal to activate"; \
	else \
		echo "❌ completion.bash not found"; \
	fi

install-deps:
	@echo "Installing dependencies..."
	@if [ -n "$$VIRTUAL_ENV" ]; then \
		echo "Virtual environment detected: $$VIRTUAL_ENV"; \
		pip install --upgrade pip; \
		pip install -r requirements.txt; \
	else \
		echo "No virtual environment detected. Installing system-wide..."; \
		echo "Consider using 'make setup-venv' for isolated installation."; \
		pip install --upgrade pip; \
		pip install ansible-lint ansible-core yamllint molecule[docker] python-openstackclient; \
	fi
	ansible-galaxy collection install -r requirements.yml
	@echo "Verifying installation..."
	ansible --version
	ansible-lint --version

lint:
	@echo "Running ansible-lint..."
	ansible-lint --show-relpath
	@echo "Running yamllint..."
	yamllint .

lint-fix:
	@echo "Running ansible-lint with auto-fix..."
	ansible-lint --fix --show-relpath

syntax-check:
	@echo "Running syntax check on all playbooks..."
	@for playbook in playbooks/*.yml; do \
		if [ -f "$$playbook" ]; then \
			echo "Checking $$playbook..."; \
			ansible-playbook --syntax-check "$$playbook" || exit 1; \
		fi \
	done
	@for playbook in playbooks/maintenance/*.yml; do \
		if [ -f "$$playbook" ]; then \
			echo "Checking $$playbook..."; \
			ansible-playbook --syntax-check "$$playbook" || exit 1; \
		fi \
	done

test: lint syntax-check
	@echo "Running molecule tests..."
	@if [ -d "tests/molecule" ]; then \
		cd tests/molecule && molecule test; \
	fi
	@echo "All tests passed!"

clean:
	@echo "Cleaning build artifacts..."
	rm -rf build/projects/*
	rm -rf build/generated/*
	rm -rf build/isos/*
	rm -rf ~/.ansible/cp/*
	find . -name "*.retry" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.log" -delete
	@echo "Clean completed!"

deploy-psi:
	@echo "Deploying to PSI environment..."
	@if [ -n "$(PROJECT)" ]; then \
		echo "Using project: $(PROJECT)"; \
		ansible-playbook -i inventory/environments/psi playbooks/deploy.yml -e project_name="$(PROJECT)"; \
	else \
		ansible-playbook -i inventory/environments/psi playbooks/deploy.yml; \
	fi

destroy-psi:
	@echo "Destroying PSI environment..."
	ansible-playbook -i inventory/environments/psi playbooks/destroy.yml

create-iso-psi:
	@echo "Creating ISO for PSI environment..."
	ansible-playbook -i inventory/environments/psi playbooks/create-iso.yml

gen-machineconfig-psi:
	@echo "Generating machine configurations from Butane templates..."
	@if [ -z "$$VIRTUAL_ENV" ]; then \
		echo "❌ Error: Virtual environment not activated. Please run 'source ~/psi/bin/activate' first."; \
		exit 1; \
	fi
	@if [ -z "$$OS_CLOUD" ]; then \
		echo "❌ Error: OS_CLOUD environment variable not set. Please run 'export OS_CLOUD=psi' first."; \
		exit 1; \
	fi
	ansible-playbook playbooks/gen-machineconfig.yml --tags machineconfig

apply-machineconfig-psi:
	@echo "Applying MachineConfig to PSI cluster..."
	@if [ -z "$$VIRTUAL_ENV" ]; then \
		echo "❌ Error: Virtual environment not activated. Please run 'source ~/psi/bin/activate' first."; \
		exit 1; \
	fi
	@if [ -z "$$OS_CLOUD" ]; then \
		echo "❌ Error: OS_CLOUD environment variable not set. Please run 'export OS_CLOUD=psi' first."; \
		exit 1; \
	fi
	@echo "🔧 Applying chrony MachineConfig to master nodes..."
	ansible-playbook playbooks/apply-machineconfig.yml

bootstrap-psi:
	@echo "Waiting for OpenShift bootstrap completion in PSI..."
	ansible-playbook -i inventory/environments/psi playbooks/bootstrap.yml

validate-psi:
	@echo "Running validation checks..."
	ansible-playbook -i inventory/environments/psi playbooks/deploy.yml --check --diff

info-psi:
	@echo "Getting cluster information..."
	ansible-playbook -i inventory/environments/psi playbooks/maintenance/get-cluster-info.yml

start-psi:
	@echo "Starting PSI cluster..."
	ansible-playbook -i inventory/environments/psi playbooks/maintenance/start-cluster.yml

stop-psi:
	@echo "Stopping PSI cluster..."
	ansible-playbook -i inventory/environments/psi playbooks/maintenance/stop-cluster.yml

health-check-psi:
	@echo "Running health checks on PSI cluster..."
	@if [ -f "playbooks/maintenance/health-check.yml" ]; then \
		ansible-playbook -i inventory/environments/psi playbooks/maintenance/health-check.yml; \
	else \
		echo "Health check playbook not found. Creating placeholder..."; \
		echo "Please implement playbooks/maintenance/health-check.yml"; \
	fi

logs-psi:
	@echo "Collecting logs from PSI environment..."
	@mkdir -p build/logs/$(shell date +%Y%m%d_%H%M%S)
	@if [ -f "playbooks/maintenance/collect-logs.yml" ]; then \
		ansible-playbook -i inventory/environments/psi playbooks/maintenance/collect-logs.yml; \
	else \
		echo "Log collection playbook not found."; \
	fi

backup-psi:
	@echo "Backing up PSI cluster configuration..."
	@mkdir -p build/backups/$(shell date +%Y%m%d_%H%M%S)
	@if [ -f "playbooks/maintenance/backup.yml" ]; then \
		ansible-playbook -i inventory/environments/psi playbooks/maintenance/backup.yml; \
	else \
		echo "Backup playbook not found."; \
	fi

restore-psi:
	@echo "Restoring PSI cluster from backup..."
	@if [ -f "playbooks/maintenance/restore.yml" ]; then \
		ansible-playbook -i inventory/environments/psi playbooks/maintenance/restore.yml; \
	else \
		echo "Restore playbook not found."; \
	fi

# RHOSO Control Plane deployment
deploy-rhoso:
	@echo "Deploying RHOSO Control Plane..."
	@if [ -z "$$VIRTUAL_ENV" ]; then \
		echo "❌ Error: Virtual environment not activated. Please run 'source ~/psi/bin/activate' first."; \
		exit 1; \
	fi
	@if [ -z "$$OS_CLOUD" ]; then \
		echo "❌ Error: OS_CLOUD environment variable not set. Please run 'export OS_CLOUD=psi' first."; \
		exit 1; \
	fi
	@if [ -n "$(PROJECT)" ]; then \
		echo "Using project: $(PROJECT)"; \
		ansible-playbook -i inventory/environments/psi playbooks/deploy-rhoso-control-plane.yml -e project_name="$(PROJECT)"; \
	else \
		ansible-playbook -i inventory/environments/psi playbooks/deploy-rhoso-control-plane.yml; \
	fi

deploy-rhoso-psi:
	@echo "Deploying RHOSO Control Plane to PSI environment..."
	@if [ -z "$$VIRTUAL_ENV" ]; then \
		echo "❌ Error: Virtual environment not activated. Please run 'source ~/psi/bin/activate' first."; \
		exit 1; \
	fi
	@if [ -z "$$OS_CLOUD" ]; then \
		echo "❌ Error: OS_CLOUD environment variable not set. Please run 'export OS_CLOUD=psi' first."; \
		exit 1; \
	fi
	@if [ -n "$(PROJECT)" ]; then \
		echo "Using project: $(PROJECT)"; \
		ansible-playbook -i inventory/environments/psi playbooks/deploy-rhoso-control-plane.yml -e project_name="$(PROJECT)"; \
	else \
		echo "No project specified, will use default or prompt for selection..."; \
		ansible-playbook -i inventory/environments/psi playbooks/deploy-rhoso-control-plane.yml -e project_name="psi-9l494"; \
	fi

download-iso:
	@echo "Downloading RHCOS ISO..."
	ansible-playbook playbooks/download-iso.yml

create-iso:
	@echo "Creating ISO using iso-builder role..."
	ansible-playbook playbooks/create-iso.yml

vxlan-create:
	@echo "Creating VXLAN endpoint for internalapi network..."
	sudo ./scripts/manage-vxlan.sh create

vxlan-delete:
	@echo "Deleting VXLAN endpoint for internalapi network..."
	sudo ./scripts/manage-vxlan.sh delete

vxlan-status:
	@echo "Checking VXLAN interface status..."
	sudo ./scripts/manage-vxlan.sh status

delete-project:
	@echo "Deleting project directory interactively..."
	ansible-playbook playbooks/delete-project.yml

delete-project-y:
	@echo "Deleting project directory (skipping confirmation prompt)..."
	ansible-playbook playbooks/delete-project.yml -e auto_confirm=true

# Usage: make delete-project-name PROJECT=myproject
delete-project-name:
	@if [ -z "$(PROJECT)" ]; then \
		echo "❌ Error: PROJECT variable is required"; \
		echo "Usage: make delete-project-name PROJECT=<project_name>"; \
		exit 1; \
	fi
	@echo "Deleting project '$(PROJECT)' with auto-confirmation..."
	ansible-playbook playbooks/delete-project.yml -e auto_confirm=true -e target_project="$(PROJECT)"

delete-project-all:
	@echo "Deleting ALL projects with auto-confirmation..."
	ansible-playbook playbooks/delete-project.yml -e auto_confirm=true -e target_project="all"

# Usage: make boot-sno [PROJECT=myproject]
boot-sno:
	@echo "Creating server that boots from volume..."
	@if [ -n "$(PROJECT)" ]; then \
		echo "Using project: $(PROJECT)"; \
		ansible-playbook playbooks/create-volume-boot-server.yml -e project_name="$(PROJECT)"; \
	else \
		echo "No project specified, will prompt for selection..."; \
		ansible-playbook playbooks/create-volume-boot-server.yml; \
	fi

# NFV Architecture Targets (Kustomize-based)
deploy-nfv-architecture:
	@echo "Deploying NFV validated architecture..."
	@if [ -z "$$VIRTUAL_ENV" ]; then \
		echo "❌ Error: Virtual environment not activated. Please run 'source ~/psi/bin/activate' first."; \
		exit 1; \
	fi
	@if [ -z "$$OS_CLOUD" ]; then \
		echo "❌ Error: OS_CLOUD environment variable not set. Please run 'export OS_CLOUD=psi' first."; \
		exit 1; \
	fi
	@./scripts/deploy-nfv-architecture.sh $(if $(SECRETS),--update-secrets)

test-nfv-architecture:
	@echo "Testing NFV architecture with dry-run..."
	@if ! command -v kustomize &> /dev/null; then \
		echo "❌ Error: kustomize is required. Please install kustomize 5.0.1 or higher."; \
		exit 1; \
	fi
	@echo "Building NFV architecture configuration..."
	@cd examples/va/nfv && kustomize build . > /tmp/nfv-architecture-test.yaml
	@echo "✅ NFV architecture configuration built successfully!"
	@echo "Configuration saved to /tmp/nfv-architecture-test.yaml for review"
	@echo "To deploy: make deploy-nfv-architecture"
	@echo "To deploy with secrets update: make deploy-nfv-architecture SECRETS=true"

validate-nfv-architecture:
	@echo "Validating NFV architecture deployment..."
	@if ! oc cluster-info &> /dev/null; then \
		echo "❌ Error: OpenShift cluster is not accessible. Please ensure you're logged in."; \
		exit 1; \
	fi
	@echo "Checking OpenStack namespace..."
	@oc get namespace openstack 2>/dev/null && echo "✅ OpenStack namespace exists" || echo "❌ OpenStack namespace missing"
	@echo "Checking OpenStack operators..."
	@oc get pods -n openstack-operators 2>/dev/null && echo "✅ OpenStack operators found" || echo "❌ OpenStack operators not found"
	@echo "Checking OpenStack control plane..."
	@oc get openstackcontrolplane -n openstack 2>/dev/null && echo "✅ OpenStack control plane found" || echo "❌ OpenStack control plane not found"
	@echo "Checking network configurations..."
	@oc get netconfig -n openstack 2>/dev/null && echo "✅ NetConfig found" || echo "❌ NetConfig not found"
	@oc get networkattachmentdefinition -n openstack 2>/dev/null && echo "✅ NetworkAttachmentDefinitions found" || echo "❌ NetworkAttachmentDefinitions not found"
	@echo "Checking MetalLB configuration..."
	@oc get ipaddresspool -n metallb-system 2>/dev/null && echo "✅ MetalLB IPAddressPools found" || echo "❌ MetalLB IPAddressPools not found"

clean-nfv-architecture:
	@echo "Cleaning up NFV architecture resources..."
	@if ! oc cluster-info &> /dev/null; then \
		echo "❌ Error: OpenShift cluster is not accessible. Please ensure you're logged in."; \
		exit 1; \
	fi
	@echo "Removing OpenStack control plane..."
	@oc delete openstackcontrolplane -n openstack --all --ignore-not-found=true
	@echo "Removing network configurations..."
	@oc delete netconfig -n openstack --all --ignore-not-found=true
	@oc delete networkattachmentdefinition -n openstack --all --ignore-not-found=true
	@echo "Removing MetalLB configurations..."
	@oc delete ipaddresspool -n metallb-system -l osp/lb-addresses-type=standard --ignore-not-found=true
	@oc delete l2advertisement -n metallb-system --all --ignore-not-found=true
	@echo "Removing secrets..."
	@oc delete secret osp-secret -n openstack --ignore-not-found=true
	@echo "✅ NFV architecture cleanup completed!"

# Generate Secrets from passwords file
generate-secrets:
	@echo "Generating OpenStack secrets from passwords file..."
	@./scripts/generate-secrets.sh

# Storage Setup Target
setup-storage:
	@echo "Setting up local storage for OpenStack services..."
	@if [ -z "$$VIRTUAL_ENV" ]; then \
		echo "❌ Error: Virtual environment not activated. Please run 'source ~/psi/bin/activate' first."; \
		exit 1; \
	fi
	@if ! oc cluster-info &> /dev/null; then \
		echo "❌ Error: OpenShift cluster is not accessible. Please ensure you're logged in."; \
		exit 1; \
	fi
	@echo "Running storage setup script..."
	@sudo ./scripts/setup-local-storage.sh
	@echo "✅ Storage setup completed!"
	@echo "You can now deploy OpenStack services that require persistent storage."

# OpenStack Deployment Workflow (inspired by install_yamls)
openstack-prep:
	@echo "Preparing OpenStack dependencies..."
	@if [ -z "$$VIRTUAL_ENV" ]; then \
		echo "❌ Error: Virtual environment not activated. Please run 'source ~/psi/bin/activate' first."; \
		exit 1; \
	fi
	@if ! oc cluster-info &> /dev/null; then \
		echo "❌ Error: OpenShift cluster is not accessible. Please ensure you're logged in."; \
		exit 1; \
	fi
	@echo "Setting up local storage..."
	@$(MAKE) setup-storage
	@echo "Applying base networking and storage components..."
	@cd lib && kustomize build . | oc apply -f -
	@echo "✅ OpenStack dependencies prepared!"

openstack:
	@echo "Installing OpenStack operators..."
	@if [ -z "$$VIRTUAL_ENV" ]; then \
		echo "❌ Error: Virtual environment not activated. Please run 'source ~/psi/bin/activate' first."; \
		exit 1; \
	fi
	@if ! oc cluster-info &> /dev/null; then \
		echo "❌ Error: OpenShift cluster is not accessible. Please ensure you're logged in."; \
		exit 1; \
	fi
	@echo "Creating OpenStack operator subscriptions..."
	@oc apply -f lib/operators/
	@echo "Waiting for operators to be ready..."
	@sleep 30
	@oc get pods -n openstack-operators 2>/dev/null || echo "Operators still starting..."
	@echo "✅ OpenStack operators installation initiated!"

openstack-init: openstack-prep openstack
	@echo "Initializing OpenStack..."
	@echo "Dependencies and operators are now installed."
	@echo "✅ OpenStack initialization completed!"
	@echo "Next step: Run 'make openstack-deploy' to deploy the control plane."

openstack-deploy:
	@echo "Deploying OpenStack control plane..."
	@if [ -z "$$VIRTUAL_ENV" ]; then \
		echo "❌ Error: Virtual environment not activated. Please run 'source ~/psi/bin/activate' first."; \
		exit 1; \
	fi
	@if ! oc cluster-info &> /dev/null; then \
		echo "❌ Error: OpenShift cluster is not accessible. Please ensure you're logged in."; \
		exit 1; \
	fi
	@echo "Deploying NFV-optimized OpenStack control plane..."
	@cd examples/va/nfv && kustomize build . | oc apply -f -
	@echo "✅ OpenStack control plane deployment initiated!"
	@echo "Monitor deployment with: oc get pods -n openstack"
	@echo "Check control plane status: oc get openstackcontrolplane -n openstack"

openstack-workflow:
	@echo "Running complete OpenStack deployment workflow..."
	@if [ -z "$$VIRTUAL_ENV" ]; then \
		echo "❌ Error: Virtual environment not activated. Please run 'source ~/psi/bin/activate' first."; \
		exit 1; \
	fi
	@if [ -z "$$OS_CLOUD" ]; then \
		echo "❌ Error: OS_CLOUD environment variable not set. Please run 'export OS_CLOUD=psi' first."; \
		exit 1; \
	fi
	@./scripts/deploy-openstack-workflow.sh
	@echo "✅ Complete OpenStack workflow executed!"