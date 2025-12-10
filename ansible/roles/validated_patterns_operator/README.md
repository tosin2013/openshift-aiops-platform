# Validated Patterns Operator Role

## Overview

This role wraps the **Validated Patterns Operator** to provide simplified, end-user deployment of Validated Patterns. It is designed for pattern consumers who want to deploy patterns quickly without dealing with the complexity of individual Ansible roles.

## Purpose

**For End Users:** This role provides a simple deployment experience:
1. Edit `values-*.yaml` configuration files
2. Run the playbook
3. The VP Operator handles everything else

**For Developers:** Use the other 6 development roles (prerequisites, common, deploy, gitea, secrets, validate) for pattern development and testing.

## What This Role Does

1. **Installs Validated Patterns Operator** - Deploys the operator to OpenShift
2. **Creates Pattern CR** - Creates a Pattern Custom Resource from your values files
3. **Deploys OpenShift GitOps** - VP Operator installs ArgoCD
4. **Creates Clustergroup Application** - VP Operator creates the initial GitOps application
5. **Validates Deployment** - Ensures all components are healthy

## Requirements

- OpenShift Container Platform 4.12+
- cluster-admin access
- `kubernetes.core` Ansible collection
- Values files configured (`values-global.yaml`, `values-hub.yaml`)

## Role Variables

### Operator Configuration

```yaml
# Operator installation
vp_operator_namespace: "openshift-operators"
vp_operator_name: "patterns-operator"
vp_operator_channel: "stable"
vp_operator_source: "community-operators"
```

### Pattern Configuration

```yaml
# Pattern details
validated_patterns_pattern_name: "validated-patterns-ansible-toolkit"
validated_patterns_git_url: "https://github.com/user/repo.git"
validated_patterns_git_revision: "main"
validated_patterns_target_namespace: "openshift-gitops"
```

### Pre-Deployment Validation

```yaml
# Enable/disable pre-deployment validation
vp_validate_prerequisites: true

# Minimum OpenShift version required
vp_min_openshift_version: "4.18"
```

### Timeouts and Retries

```yaml
# Timeouts (seconds)
vp_operator_install_timeout: 300
vp_pattern_deploy_timeout: 600
vp_gitops_ready_timeout: 600
vp_clustergroup_ready_timeout: 900

# Retry configuration
vp_operator_install_retries: 30
vp_gitops_ready_retries: 60
```

### Validation

```yaml
# Health checks
vp_validate_deployment: true
vp_validate_gitops: true
vp_validate_clustergroup: true
```

## Dependencies

- `kubernetes.core` collection
- OpenShift CLI (`oc`) configured
- Access to Red Hat Operator Hub

## Example Playbook

### End-User Deployment

```yaml
---
- name: Deploy Validated Pattern using VP Operator
  hosts: localhost
  connection: local
  gather_facts: no

  vars:
    validated_patterns_pattern_name: "my-pattern"
    validated_patterns_git_url: "https://github.com/myorg/my-pattern.git"
    validated_patterns_git_revision: "main"

  roles:
    - validated_patterns_operator
```

### With Custom Configuration

```yaml
---
- name: Deploy Pattern with custom settings
  hosts: localhost
  connection: local

  vars:
    validated_patterns_pattern_name: "validated-patterns-ansible-toolkit"
    validated_patterns_git_url: "https://github.com/tosin2013/validated-patterns-ansible-toolkit.git"
    validated_patterns_git_revision: "main"
    vp_operator_channel: "stable"
    vp_debug_mode: true

  roles:
    - validated_patterns_operator
```

## Usage

### Step 1: Configure Values Files

Edit your pattern's values files:

**values-global.yaml:**
```yaml
global:
  pattern: my-pattern
  targetRevision: main
```

**values-hub.yaml:**
```yaml
clusterGroup:
  name: hub
  isHubCluster: true
  applications:
    - name: my-app
      namespace: my-namespace
```

### Step 2: Run the Playbook

```bash
ansible-playbook site.yml --tags production
```

### Step 3: Monitor Deployment

Access ArgoCD UI to monitor application deployment:

```bash
# Get ArgoCD URL
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'

# Get admin password
oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d
```

## Architecture

This role is part of a **dual-workflow architecture**:

### Development Workflow (Roles 1-2, 4-7)
For pattern developers who need full control:
- validated_patterns_prerequisites
- validated_patterns_common
- validated_patterns_deploy
- validated_patterns_gitea
- validated_patterns_secrets
- validated_patterns_validate

### End-User Workflow (Role 3)
For pattern consumers who want simplicity:
- **validated_patterns_operator** (this role)

## What Gets Deployed

1. **Validated Patterns Operator** - In `openshift-operators` namespace
2. **Pattern CR** - Custom resource defining your pattern
3. **OpenShift GitOps** - ArgoCD instance in `openshift-gitops` namespace
4. **Clustergroup Application** - Initial GitOps application
5. **Pattern Components** - All applications defined in values files

## Troubleshooting

### Operator Installation Fails

```bash
# Check operator status
oc get csv -n openshift-operators | grep patterns

# Check operator logs
oc logs -n openshift-operators -l name=patterns-operator
```

### Pattern CR Not Processing

```bash
# Check Pattern CR status
oc get pattern -n openshift-operators

# Describe Pattern CR
oc describe pattern <pattern-name> -n openshift-operators
```

### GitOps Not Deploying

```bash
# Check GitOps operator
oc get csv -n openshift-gitops | grep gitops

# Check ArgoCD instance
oc get argocd -n openshift-gitops

# Check ArgoCD applications
oc get applications -n openshift-gitops
```

## Tags

This role supports the following tags:

- `install` - Install operator only
- `operator` - Operator installation tasks
- `deploy` - Pattern CR creation
- `pattern` - Pattern deployment tasks
- `wait` - Wait for GitOps tasks
- `gitops` - GitOps-related tasks
- `validate` - Validation tasks

## License

Apache 2.0

## Author Information

Validated Patterns Toolkit Development Team
