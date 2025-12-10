#!/bin/bash
# Pattern CR Preview Tool
# Generates and displays the Pattern Custom Resource that will be created
# WITHOUT actually deploying it to the cluster
#
# Usage: ./scripts/preview-pattern-cr.sh [--save OUTPUT_FILE]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
SAVE_TO_FILE=""
if [[ "${1:-}" == "--save" && -n "${2:-}" ]]; then
    SAVE_TO_FILE="$2"
fi

# ============================================================
# Helper Functions
# ============================================================

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}"
}

print_info() {
    echo -e "${GREEN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# ============================================================
# Prerequisites Check
# ============================================================

check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing=0

    # Check helm
    if command -v helm &> /dev/null; then
        print_success "helm found: $(helm version --short)"
    else
        print_error "helm not found - required for generating Pattern CR"
        missing=$((missing + 1))
    fi

    # Check yq (optional but recommended)
    if command -v yq &> /dev/null; then
        print_success "yq found"
    else
        print_warning "yq not found (optional, for enhanced output formatting)"
    fi

    echo ""

    if [[ $missing -gt 0 ]]; then
        print_error "Missing required tools. Please install them before proceeding."
        exit 1
    fi
}

# ============================================================
# Values File Validation
# ============================================================

validate_values_files() {
    print_header "Validating Values Files"

    cd "$PROJECT_ROOT"

    local errors=0

    # Check if values files exist
    if [[ ! -f "values-global.yaml" ]]; then
        print_error "values-global.yaml not found"
        print_info "Run: ./scripts/configure-cluster-values.sh"
        errors=$((errors + 1))
    else
        print_success "Found values-global.yaml"

        # Check for placeholders
        if grep -q "{{ CLUSTER_DOMAIN }}" values-global.yaml 2>/dev/null; then
            print_warning "values-global.yaml contains uncustomized placeholders"
            print_info "Run: ./scripts/configure-cluster-values.sh"
            errors=$((errors + 1))
        fi
    fi

    if [[ ! -f "values-hub.yaml" ]]; then
        print_error "values-hub.yaml not found"
        print_info "Run: ./scripts/configure-cluster-values.sh"
        errors=$((errors + 1))
    else
        print_success "Found values-hub.yaml"

        # Check for placeholders
        if grep -q "{{ CLUSTER_DOMAIN }}" values-hub.yaml 2>/dev/null; then
            print_warning "values-hub.yaml contains uncustomized placeholders"
            print_info "Run: ./scripts/configure-cluster-values.sh"
            errors=$((errors + 1))
        fi
    fi

    echo ""

    if [[ $errors -gt 0 ]]; then
        print_error "Values files validation failed"
        exit 1
    fi
}

# ============================================================
# Extract Configuration
# ============================================================

extract_pattern_name() {
    yq eval '.global.pattern' values-global.yaml 2>/dev/null || echo "self-healing-platform"
}

extract_git_url() {
    yq eval '.git.repoURL' values-global.yaml 2>/dev/null || echo "unknown"
}

extract_git_revision() {
    yq eval '.git.revision' values-global.yaml 2>/dev/null || echo "main"
}

# ============================================================
# Generate Pattern CR
# ============================================================

generate_pattern_cr() {
    print_header "Generating Pattern CR"

    cd "$PROJECT_ROOT"

    local pattern_name
    pattern_name=$(extract_pattern_name)

    local git_url
    git_url=$(extract_git_url)

    local git_revision
    git_revision=$(extract_git_revision)

    print_info "Pattern Name: $pattern_name"
    print_info "Git URL: $git_url"
    print_info "Git Revision: $git_revision"
    echo ""

    print_info "Running helm template to generate Pattern CR..."

    # Generate Pattern CR using helm template
    local helm_output
    if helm_output=$(helm template "$pattern_name" oci://quay.io/hybridcloudpatterns/pattern-install \
        --include-crds \
        -f values-global.yaml \
        -f values-hub.yaml \
        --set global.pattern="$pattern_name" \
        --set main.git.repoURL="$git_url" \
        --set main.git.revision="$git_revision" 2>&1); then

        print_success "Pattern CR generated successfully"
        echo ""

        # Display or save output
        if [[ -n "$SAVE_TO_FILE" ]]; then
            echo "$helm_output" > "$SAVE_TO_FILE"
            print_success "Pattern CR saved to: $SAVE_TO_FILE"
        else
            print_header "Pattern CR Preview"
            echo ""
            echo -e "${CYAN}# Generated Pattern CR for: $pattern_name${NC}"
            echo -e "${CYAN}# Git URL: $git_url${NC}"
            echo -e "${CYAN}# Git Revision: $git_revision${NC}"
            echo ""

            # Pretty print with yq if available
            if command -v yq &> /dev/null; then
                echo "$helm_output" | yq eval '.' -
            else
                echo "$helm_output"
            fi
        fi

        echo ""
        analyze_pattern_cr "$helm_output"

    else
        print_error "Failed to generate Pattern CR"
        echo ""
        echo "$helm_output"
        exit 1
    fi
}

# ============================================================
# Analyze Pattern CR
# ============================================================

analyze_pattern_cr() {
    local cr_content="$1"

    print_header "Pattern CR Analysis"

    # Extract key components
    local pattern_name
    pattern_name=$(echo "$cr_content" | yq eval 'select(.kind == "Pattern") | .metadata.name' - 2>/dev/null || echo "unknown")

    local git_url
    git_url=$(echo "$cr_content" | yq eval 'select(.kind == "Pattern") | .spec.gitConfig.targetRepo' - 2>/dev/null || echo "unknown")

    local git_revision
    git_revision=$(echo "$cr_content" | yq eval 'select(.kind == "Pattern") | .spec.gitConfig.targetRevision' - 2>/dev/null || echo "unknown")

    echo "Pattern Details:"
    echo "  Name: $pattern_name"
    echo "  Git URL: $git_url"
    echo "  Git Revision: $git_revision"
    echo ""

    # Count resources
    local resource_count
    resource_count=$(echo "$cr_content" | grep -c "^kind:" || echo "0")

    echo "Resources to be created: $resource_count"
    echo ""

    # List resources
    echo "Resource types:"
    echo "$cr_content" | grep "^kind:" | sort | uniq -c
    echo ""
}

# ============================================================
# Deployment Readiness Check
# ============================================================

deployment_readiness_check() {
    print_header "Deployment Readiness Check"

    local warnings=0

    # Check if connected to cluster
    if command -v oc &> /dev/null; then
        if oc whoami &> /dev/null; then
            local current_user
            current_user=$(oc whoami)
            print_success "Connected to cluster as: $current_user"

            # Check if Validated Patterns Operator is installed
            if oc get csv -n openshift-operators | grep -q "patterns-operator" 2>/dev/null; then
                print_success "Validated Patterns Operator is installed"
            else
                print_warning "Validated Patterns Operator not found"
                print_info "The operator will be installed automatically during deployment"
                warnings=$((warnings + 1))
            fi
        else
            print_warning "Not connected to OpenShift cluster"
            print_info "Cannot verify cluster readiness"
            warnings=$((warnings + 1))
        fi
    else
        print_warning "oc CLI not available"
        print_info "Cannot verify cluster connection"
        warnings=$((warnings + 1))
    fi

    # Check if values-secret.yaml exists
    if [[ ! -f "$PROJECT_ROOT/values-secret.yaml" ]]; then
        print_warning "values-secret.yaml not found"
        print_info "Create it from template: cp values-secret.yaml.template values-secret.yaml"
        warnings=$((warnings + 1))
    else
        print_success "values-secret.yaml exists"

        # Check if it still contains placeholders
        if grep -q "{{ " "$PROJECT_ROOT/values-secret.yaml" 2>/dev/null; then
            print_warning "values-secret.yaml contains placeholder values"
            print_info "Edit the file with your actual credentials"
            warnings=$((warnings + 1))
        fi
    fi

    echo ""

    if [[ $warnings -eq 0 ]]; then
        print_success "All readiness checks passed!"
    else
        print_warning "Deployment readiness check found $warnings warnings"
        print_info "Review warnings above before deploying"
    fi

    echo ""
}

# ============================================================
# Next Steps
# ============================================================

show_next_steps() {
    print_header "Next Steps"

    echo ""
    print_info "1. Review the Pattern CR above"
    echo ""
    print_info "2. If everything looks correct, validate cluster prerequisites:"
    echo "     ansible-playbook ansible/playbooks/validate_new_cluster.yml"
    echo ""
    print_info "3. Deploy the pattern using the Validated Patterns Operator:"
    echo "     make -f common/Makefile operator-deploy"
    echo ""
    print_info "4. Monitor deployment progress:"
    echo "     make -f common/Makefile argo-healthcheck"
    echo "     oc get pattern -n openshift-operators --watch"
    echo ""
    print_info "For detailed instructions, see: docs/guides/NEW-CLUSTER-DEPLOYMENT.md"
    echo ""
}

# ============================================================
# Main
# ============================================================

main() {
    print_header "Pattern CR Preview Tool"
    echo ""
    echo "This tool generates a preview of the Pattern Custom Resource"
    echo "that will be created during deployment WITHOUT actually deploying it."
    echo ""

    check_prerequisites
    validate_values_files
    generate_pattern_cr
    deployment_readiness_check
    show_next_steps
}

# Run main
main "$@"
