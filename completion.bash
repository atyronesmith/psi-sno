#!/bin/bash
# Bash completion for PSI-SNO Makefile targets
# Usage: source completion.bash

_make_completion() {
    local cur prev targets

    # Current word being completed
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Define all available make targets
    targets="help lint lint-fix syntax-check test clean install-deps setup-venv activate-venv download-iso create-iso create-iso-psi bootstrap-psi validate-psi info-psi start-psi stop-psi deploy-psi destroy-psi health-check-psi logs-psi backup-psi restore-psi vxlan-create vxlan-delete vxlan-status delete-project delete-project-y delete-project-name boot-sno"

    # Handle PROJECT parameter for specific targets (optional for deploy-psi and boot-sno)
    if [[ "$prev" == "deploy-psi" || "$prev" == "boot-sno" || "$prev" == "delete-project-name" ]]; then
        # If previous word is a target that needs PROJECT, suggest PROJECT=
        if [[ "$cur" == P* ]]; then
            COMPREPLY=($(compgen -W "PROJECT=" -- "$cur"))
            return 0
        fi
        # If user typed PROJECT=, suggest available project names from build/projects/
        if [[ "$cur" == PROJECT=* ]]; then
            local project_part="${cur#PROJECT=}"
            local projects=""
            if [[ -d "build/projects" ]]; then
                projects=$(ls -1 build/projects/ 2>/dev/null | tr '\n' ' ')
            fi
            COMPREPLY=($(compgen -W "$projects" -P "PROJECT=" -- "$project_part"))
            return 0
        fi
    fi

    # Handle -y flag for delete targets
    if [[ "$prev" == "delete-project" || "$prev" == "delete-project-y" ]]; then
        COMPREPLY=($(compgen -W "-y" -- "$cur"))
        return 0
    fi

    # Default completion: suggest make targets
    COMPREPLY=($(compgen -W "$targets" -- "$cur"))
    return 0
}

# Register completion function for 'make' command
complete -F _make_completion make

# Also provide a direct function to show available targets
show_make_targets() {
    echo "Available make targets:"
    echo "  Development: help lint lint-fix syntax-check test clean install-deps setup-venv activate-venv"
    echo "  PSI Environment: deploy-psi destroy-psi create-iso-psi bootstrap-psi validate-psi info-psi start-psi stop-psi health-check-psi logs-psi backup-psi restore-psi"
    echo "  Server Management: boot-sno"
    echo "  Project Management: delete-project delete-project-y delete-project-name"
    echo "  VXLAN: vxlan-create vxlan-delete vxlan-status"
    echo ""
    echo "Usage examples:"
    echo "  make deploy-psi PROJECT=my-cluster    # or just: make deploy-psi"
    echo "  make boot-sno PROJECT=my-cluster      # or just: make boot-sno"
    echo "  make delete-project-name PROJECT=my-cluster"
}

echo "PSI-SNO Makefile completion loaded!"
echo "Try: make <TAB><TAB> to see available targets"
echo "For PROJECT targets, type: make deploy-psi PROJECT=<TAB>"
echo "Run 'show_make_targets' to see all available targets"