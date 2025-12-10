#!/bin/bash
# Configure Cluster Values Helper Script
# Automates generation of customized values files for new cluster deployments
#
# Usage: ./scripts/configure-cluster-values.sh [--non-interactive]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
NON_INTERACTIVE=false
if [[ "${1:-}" == "--non-interactive" ]]; then
    NON_INTERACTIVE=true
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

prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local result

    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        result="$default"
    else
        read -p "$(echo -e ${BLUE}${prompt}${NC} [${default}]: )" result
        result="${result:-$default}"
    fi

    echo "$result"
}

# ============================================================
# Cluster Detection
# ============================================================

detect_cluster_domain() {
    print_info "Detecting cluster domain..."

    if ! command -v oc &> /dev/null; then
        print_warning "oc CLI not found, cannot auto-detect cluster domain"
        echo ""
        return
    fi

    # Try to get ingress domain
    local domain
    domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "")

    if [[ -n "$domain" ]]; then
        print_success "Detected cluster domain: $domain"
        echo "$domain"
    else
        print_warning "Could not auto-detect cluster domain"
        echo ""
    fi
}

detect_openshift_version() {
    print_info "Detecting OpenShift version..."

    if ! command -v oc &> /dev/null; then
        print_warning "oc CLI not found"
        return
    fi

    local version
    version=$(oc version -o json 2>/dev/null | jq -r '.openshiftVersion // empty' || echo "")

    if [[ -n "$version" ]]; then
        print_success "Detected OpenShift version: $version"
    else
        print_warning "Could not detect OpenShift version"
    fi
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing=0

    # Check oc
    if command -v oc &> /dev/null; then
        print_success "oc CLI found: $(oc version --client -o json | jq -r '.clientVersion.gitVersion')"
    else
        print_error "oc CLI not found"
        missing=$((missing + 1))
    fi

    # Check kubectl
    if command -v kubectl &> /dev/null; then
        print_success "kubectl found: $(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
    else
        print_warning "kubectl not found (optional)"
    fi

    # Check helm
    if command -v helm &> /dev/null; then
        print_success "helm found: $(helm version --short)"
    else
        print_error "helm not found"
        missing=$((missing + 1))
    fi

    # Check yq
    if command -v yq &> /dev/null; then
        print_success "yq found"
    else
        print_warning "yq not found (optional, for advanced customization)"
    fi

    echo ""

    if [[ $missing -gt 0 ]]; then
        print_error "Missing required tools. Please install them before proceeding."
        exit 1
    fi

    detect_openshift_version
    echo ""
}

# ============================================================
# Template Processing
# ============================================================

substitute_placeholders() {
    local template_file="$1"
    local output_file="$2"
    local cluster_domain="$3"
    local git_org="$4"
    local git_repo="$5"
    local git_branch="$6"
    local git_username="$7"

    print_info "Generating $output_file from template..."

    # Copy template and substitute placeholders
    sed -e "s|{{ CLUSTER_DOMAIN }}|${cluster_domain}|g" \
        -e "s|{{ GIT_ORG }}|${git_org}|g" \
        -e "s|{{ GIT_REPO }}|${git_repo}|g" \
        -e "s|{{ GIT_BRANCH }}|${git_branch}|g" \
        -e "s|{{ GIT_USERNAME }}|${git_username}|g" \
        "$template_file" > "$output_file"

    print_success "Created $output_file"
}

# ============================================================
# Main Configuration Flow
# ============================================================

main() {
    print_header "OpenShift AI Ops Platform - Cluster Configuration Helper"
    echo ""
    echo "This script will help you generate customized values files for deploying"
    echo "the Self-Healing Platform to a new OpenShift cluster."
    echo ""

    check_prerequisites

    # Detect cluster domain
    local detected_domain
    detected_domain=$(detect_cluster_domain)

    # ============================================================
    # Gather Configuration
    # ============================================================
    print_header "Configuration Input"

    # Cluster Domain
    local cluster_domain
    if [[ -n "$detected_domain" ]]; then
        cluster_domain=$(prompt_with_default "Enter cluster domain" "$detected_domain")
    else
        cluster_domain=$(prompt_with_default "Enter cluster domain (e.g., apps.cluster-abc123.example.com)" "apps.cluster-example.com")
    fi

    # Git Configuration
    echo ""
    print_info "Git Repository Configuration"
    print_info "Choose between:"
    print_info "  1. Gitea (Development/Air-gapped) - Local git on cluster"
    print_info "  2. GitHub (Production/Cloud) - Public/private GitHub repo"
    echo ""

    local git_type
    git_type=$(prompt_with_default "Enter git type (gitea/github)" "gitea")

    local git_org
    git_org=$(prompt_with_default "Enter Git organization/username" "my-org")

    local git_repo
    git_repo=$(prompt_with_default "Enter Git repository name" "openshift-aiops-platform")

    local git_branch
    git_branch=$(prompt_with_default "Enter Git branch" "main")

    local git_username
    git_username=$(prompt_with_default "Enter Git username" "admin")

    # ============================================================
    # Generate Values Files
    # ============================================================
    print_header "Generating Values Files"

    cd "$PROJECT_ROOT"

    # Check if templates exist
    if [[ ! -f "values-global.yaml.template" ]]; then
        print_error "Template file not found: values-global.yaml.template"
        exit 1
    fi

    if [[ ! -f "values-hub.yaml.template" ]]; then
        print_error "Template file not found: values-hub.yaml.template"
        exit 1
    fi

    # Backup existing files if they exist
    if [[ -f "values-global.yaml" ]]; then
        print_warning "Backing up existing values-global.yaml to values-global.yaml.backup"
        cp values-global.yaml "values-global.yaml.backup.$(date +%Y%m%d-%H%M%S)"
    fi

    if [[ -f "values-hub.yaml" ]]; then
        print_warning "Backing up existing values-hub.yaml to values-hub.yaml.backup"
        cp values-hub.yaml "values-hub.yaml.backup.$(date +%Y%m%d-%H%M%S)"
    fi

    # Generate values-global.yaml
    substitute_placeholders \
        "values-global.yaml.template" \
        "values-global.yaml" \
        "$cluster_domain" \
        "$git_org" \
        "$git_repo" \
        "$git_branch" \
        "$git_username"

    # Generate values-hub.yaml
    substitute_placeholders \
        "values-hub.yaml.template" \
        "values-hub.yaml" \
        "$cluster_domain" \
        "$git_org" \
        "$git_repo" \
        "$git_branch" \
        "$git_username"

    echo ""

    # ============================================================
    # Secrets Configuration
    # ============================================================
    print_header "Secrets Configuration"

    print_warning "IMPORTANT: You need to configure secrets in values-secret.yaml"
    echo ""
    print_info "Copy the template and add your actual credentials:"
    echo "  cp values-secret.yaml.template values-secret.yaml"
    echo ""
    print_info "Required secrets:"
    echo "  - Git password/token"
    echo "  - S3 access key and secret key"
    echo "  - Grafana admin password"
    echo ""
    print_warning "NEVER commit values-secret.yaml to git!"
    echo ""

    if [[ ! -f "values-secret.yaml" ]] && [[ -f "values-secret.yaml.template" ]]; then
        local create_secret
        create_secret=$(prompt_with_default "Create values-secret.yaml now? (yes/no)" "yes")

        if [[ "$create_secret" == "yes" || "$create_secret" == "y" ]]; then
            cp values-secret.yaml.template values-secret.yaml
            print_success "Created values-secret.yaml - EDIT IT WITH YOUR ACTUAL SECRETS"
            print_warning "Remember: NEVER commit this file to git!"
        fi
    fi

    echo ""

    # ============================================================
    # Summary
    # ============================================================
    print_header "Configuration Summary"
    echo ""
    echo "Cluster Domain:    $cluster_domain"
    echo "Git Type:          $git_type"
    echo "Git Organization:  $git_org"
    echo "Git Repository:    $git_repo"
    echo "Git Branch:        $git_branch"
    echo "Git Username:      $git_username"
    echo ""

    print_success "Values files generated successfully!"
    echo ""

    # ============================================================
    # Next Steps
    # ============================================================
    print_header "Next Steps"
    echo ""
    print_info "1. Edit values-secret.yaml with your actual credentials"
    echo "     vi values-secret.yaml"
    echo ""
    print_info "2. Review generated values files:"
    echo "     cat values-global.yaml"
    echo "     cat values-hub.yaml"
    echo ""
    print_info "3. Preview Pattern CR before deployment:"
    echo "     ./scripts/preview-pattern-cr.sh"
    echo ""
    print_info "4. Validate cluster prerequisites:"
    echo "     ansible-playbook ansible/playbooks/validate_new_cluster.yml"
    echo ""
    print_info "5. Deploy the pattern:"
    echo "     make -f common/Makefile operator-deploy"
    echo ""
    print_info "For detailed instructions, see: docs/guides/NEW-CLUSTER-DEPLOYMENT.md"
    echo ""
}

# Run main
main "$@"
