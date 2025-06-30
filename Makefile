.PHONY: help lint lint-fix syntax-check test clean install-deps setup-venv activate-venv setup-completion download-iso create-iso create-iso-psi bootstrap-psi validate-psi info-psi start-psi stop-psi deploy-psi destroy-psi health-check-psi logs-psi backup-psi restore-psi vxlan-create vxlan-delete vxlan-status delete-project delete-project-y delete-project-name delete-project-all boot-sno gen-machineconfig-psi

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