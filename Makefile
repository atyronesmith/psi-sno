.PHONY: help lint lint-fix syntax-check test clean install-deps download-iso create-iso-dev bootstrap-dev validate-dev info-dev start-dev stop-dev deploy-dev destroy-dev

help:
	@echo "Available targets:"
	@echo "  help           - Show this help message"
	@echo "  lint           - Run ansible-lint and yamllint"
	@echo "  lint-fix       - Run ansible-lint with auto-fix where possible"
	@echo "  syntax-check   - Run ansible syntax check on all playbooks"
	@echo "  test           - Run all tests (lint + syntax)"
	@echo "  install-deps   - Install required dependencies"
	@echo "  clean          - Clean build artifacts"
	@echo "  download-iso   - Download the RHCOS ISO using the iso-builder role"
	@echo ""
	@echo "Environment targets:"
	@echo "  deploy-dev     - Deploy to development environment"
	@echo "  destroy-dev    - Destroy development environment"
	@echo "  create-iso-dev - Create ISO for development environment"
	@echo "  bootstrap-dev  - Wait for OpenShift bootstrap completion in dev"
	@echo "  validate-dev   - Run a dry-run deploy with check and diff"
	@echo "  info-dev       - Get cluster info for development environment"
	@echo "  start-dev      - Start the development cluster"
	@echo "  stop-dev       - Stop the development cluster"

install-deps:
	pip install --upgrade pip
	pip install ansible-lint ansible-core yamllint
	ansible-galaxy collection install -r requirements.yml

lint:
	@echo "Running ansible-lint..."
	ansible-lint
	@echo "Running yamllint..."
	yamllint .

lint-fix:
	@echo "Running ansible-lint with auto-fix..."
	ansible-lint --fix

syntax-check:
	@echo "Running syntax check on all playbooks..."
	@for playbook in playbooks/*.yml; do \
		if [ -f "$$playbook" ]; then \
			echo "Checking $$playbook..."; \
			ansible-playbook --syntax-check "$$playbook"; \
		fi \
	done
	@for playbook in playbooks/maintenance/*.yml; do \
		if [ -f "$$playbook" ]; then \
			echo "Checking $$playbook..."; \
			ansible-playbook --syntax-check "$$playbook"; \
		fi \
	done

test: lint syntax-check
	@echo "All tests passed!"

clean:
	@echo "Cleaning build artifacts..."
	rm -rf build/projects/*
	rm -rf build/generated/*
	rm -rf build/isos/*
	find . -name "*.retry" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

deploy-dev:
	ansible-playbook -i inventory/environments/dev playbooks/deploy.yml

destroy-dev:
	ansible-playbook -i inventory/environments/dev playbooks/destroy.yml

create-iso-dev:
	ansible-playbook -i inventory/environments/dev playbooks/create-iso.yml

bootstrap-dev:
	ansible-playbook -i inventory/environments/dev playbooks/bootstrap.yml

validate-dev:
	ansible-playbook -i inventory/environments/dev playbooks/deploy.yml --check --diff

info-dev:
	ansible-playbook -i inventory/environments/dev playbooks/maintenance/get-cluster-info.yml

start-dev:
	ansible-playbook -i inventory/environments/dev playbooks/maintenance/start-cluster.yml

stop-dev:
	ansible-playbook -i inventory/environments/dev playbooks/maintenance/stop-cluster.yml

download-iso:
	ansible-playbook playbooks/download-iso.yml