# validated_patterns_common - Detailed Documentation

**Role Name:** validated_patterns_common
**Version:** 1.0
**Last Updated:** 2025-10-27

---

## Table of Contents

1. [Overview](#overview)
2. [Purpose](#purpose)
3. [Requirements](#requirements)
4. [Variables](#variables)
5. [Tasks](#tasks)
6. [Dependencies](#dependencies)
7. [Usage Examples](#usage-examples)
8. [Testing](#testing)
9. [Troubleshooting](#troubleshooting)

---

## Overview

The `validated_patterns_common` role deploys the common infrastructure required for Validated Patterns, including the rhvp.cluster_utils collection, Helm repository configuration, and the clustergroup-chart with multisource architecture support.

### Key Features

- ✅ rhvp.cluster_utils collection installation
- ✅ Helm repository configuration
- ✅ clustergroup-chart v0.9.* deployment
- ✅ Multisource architecture support
- ✅ OpenShift GitOps integration
- ✅ ArgoCD configuration

### When to Use

Use this role:
- **After prerequisites validation** - Deploy common infrastructure
- **Before pattern deployment** - Set up GitOps foundation
- **For pattern development** - Configure Helm and ArgoCD
- **In CI/CD pipelines** - Automated infrastructure setup

---

## Purpose

This role ensures that:

1. **rhvp.cluster_utils Collection** - Installed and available
2. **Helm Repositories** - Configured for pattern charts
3. **clustergroup-chart** - Deployed with correct version (0.9.*)
4. **Multisource Architecture** - Enabled for GitOps
5. **ArgoCD Integration** - Configured in openshift-gitops namespace

### Deployment Flow

```
┌─────────────────────────────────────────┐
│  validated_patterns_common              │
└─────────────────────────────────────────┘
              ↓
    ┌─────────────────────┐
    │ Install             │
    │ rhvp.cluster_utils  │
    │ Collection          │
    └─────────────────────┘
              ↓
    ┌─────────────────────┐
    │ Configure Helm      │
    │ Repositories        │
    └─────────────────────┘
              ↓
    ┌─────────────────────┐
    │ Deploy              │
    │ clustergroup-chart  │
    │ v0.9.*              │
    └─────────────────────┘
              ↓
    ┌─────────────────────┐
    │ Enable Multisource  │
    │ Architecture        │
    └─────────────────────┘
              ↓
    ┌─────────────────────┐
    │ Display Summary     │
    └─────────────────────┘
```

---

## Requirements

### Ansible Requirements

- **Ansible Core:** 2.12 or higher
- **Python:** 3.8 or higher

### Ansible Collections

```yaml
collections:
  - kubernetes.core (>= 2.3.0)
  - community.general (>= 5.0.0)
  - rhvp.cluster_utils (>= 1.0.0)
```

### OpenShift Requirements

- **OpenShift Version:** 4.12 or higher
- **OpenShift GitOps:** Installed and running
- **Cluster Access:** Valid kubeconfig with cluster-admin permissions

### External Tools

- **Helm:** v3.12 or higher
- **oc CLI:** OpenShift command-line tool

---

## Variables

### Default Variables

All default variables are defined in `defaults/main.yml`:

#### rhvp.cluster_utils Collection Version

```yaml
validated_patterns_rhvp_collection_version: "1.0.0"
```

**Description:** Version of rhvp.cluster_utils collection to install
**Type:** String
**Default:** "1.0.0"
**Valid Values:** Any valid collection version

#### clustergroup-chart Version

```yaml
validated_patterns_clustergroup_chart_version: "0.9.*"
```

**Description:** Version of clustergroup-chart to deploy (must be 0.9.*)
**Type:** String
**Default:** "0.9.*"
**Valid Values:** "0.9.0", "0.9.1", "0.9.*"

**Important:** Must use 0.9.* for multisource architecture support

#### Pattern Name

```yaml
validated_patterns_pattern_name: "common"
```

**Description:** Name of the pattern being deployed
**Type:** String
**Default:** "common"
**Valid Values:** Any valid pattern name

#### Target Revision

```yaml
validated_patterns_target_revision: "main"
```

**Description:** Git branch/tag for GitOps synchronization
**Type:** String
**Default:** "main"
**Valid Values:** Any valid Git reference (branch, tag, commit SHA)

#### Multisource Configuration

```yaml
validated_patterns_multisource_enabled: true
```

**Description:** Enable multisource architecture for ArgoCD
**Type:** Boolean
**Default:** true
**Valid Values:** true, false

**Note:** Required for modern Validated Patterns

#### GitOps Configuration

```yaml
validated_patterns_gitops_namespace: "openshift-gitops"
validated_patterns_argocd_instance_name: "openshift-gitops"
```

**Description:** GitOps namespace and ArgoCD instance name
**Type:** String
**Defaults:**
- `gitops_namespace`: "openshift-gitops"
- `argocd_instance_name`: "openshift-gitops"

**Valid Values:** Any valid Kubernetes namespace/name

### Variable Customization

Override variables in your playbook:

```yaml
---
- name: Deploy common infrastructure with custom settings
  hosts: localhost
  vars:
    validated_patterns_pattern_name: "my-pattern"
    validated_patterns_target_revision: "v1.0.0"
    validated_patterns_clustergroup_chart_version: "0.9.1"
  roles:
    - validated_patterns_common
```

---

## Tasks

### Main Tasks (tasks/main.yml)

The role executes the following task files in order:

#### 1. install_collection.yml

**Purpose:** Install rhvp.cluster_utils collection

**Tasks:**
- Check if collection is already installed
- Install collection if missing
- Verify installation

**Variables Used:**
- `validated_patterns_rhvp_collection_version`

**Example Output:**
```
TASK [Install rhvp.cluster_utils collection] *****
ok: [localhost] => {
    "msg": "rhvp.cluster_utils v1.0.0 installed"
}
```

#### 2. configure_helm_repos.yml

**Purpose:** Configure Helm repositories for pattern charts

**Tasks:**
- Add validated-patterns Helm repository
- Update Helm repository cache
- Verify repository configuration

**Example Output:**
```
TASK [Configure Helm repositories] *****
ok: [localhost] => {
    "msg": "Helm repositories configured"
}
```

#### 3. deploy_clustergroup_chart.yml

**Purpose:** Deploy clustergroup-chart with multisource support

**Tasks:**
- Deploy clustergroup-chart v0.9.*
- Configure multisource architecture
- Integrate with ArgoCD
- Verify deployment

**Variables Used:**
- `validated_patterns_clustergroup_chart_version`
- `validated_patterns_multisource_enabled`
- `validated_patterns_gitops_namespace`
- `validated_patterns_argocd_instance_name`

**Example Output:**
```
TASK [Deploy clustergroup-chart] *****
ok: [localhost] => {
    "msg": "clustergroup-chart v0.9.* deployed with multisource support"
}
```

---

## Dependencies

### Role Dependencies

This role should be run after:
- `validated_patterns_prerequisites` - Ensures cluster is ready

### Collection Dependencies

Defined in `meta/main.yml`:

```yaml
collections:
  - kubernetes.core
  - community.general
  - rhvp.cluster_utils
```

### External Dependencies

- **Helm:** Must be installed and configured
- **OpenShift GitOps:** Must be installed
- **ArgoCD:** Must be running in openshift-gitops namespace

---

## Usage Examples

### Example 1: Basic Usage

```yaml
---
- name: Deploy common infrastructure
  hosts: localhost
  connection: local
  gather_facts: no
  roles:
    - validated_patterns_common
```

Run:

```bash
ansible-playbook deploy_common.yml
```

### Example 2: Custom Pattern

```yaml
---
- name: Deploy common for custom pattern
  hosts: localhost
  connection: local
  gather_facts: no
  vars:
    validated_patterns_pattern_name: "my-pattern"
    validated_patterns_target_revision: "v1.0.0"
  roles:
    - validated_patterns_common
```

### Example 3: Complete Workflow

```yaml
---
- name: Complete pattern deployment
  hosts: localhost
  connection: local
  gather_facts: no

  roles:
    # Step 1: Validate prerequisites
    - validated_patterns_prerequisites

    # Step 2: Deploy common infrastructure
    - validated_patterns_common

    # Step 3: Deploy pattern (next role)
    # - validated_patterns_deploy
```

### Example 4: With ansible-navigator

```bash
ansible-navigator run deploy_common.yml \
  --execution-environment-image quay.io/ansible/creator-ee:latest \
  --mode stdout
```

---

## Testing

### Running Tests

The role includes a test playbook in `tests/test.yml`:

```bash
# Run tests
cd ansible/roles/validated_patterns_common
ansible-playbook tests/test.yml

# Run with ansible-navigator
ansible-navigator run tests/test.yml --mode stdout
```

### Test Coverage

The test playbook validates:
- ✅ Role executes without errors
- ✅ rhvp.cluster_utils collection is installed
- ✅ Helm repositories are configured
- ✅ clustergroup-chart is deployed
- ✅ Multisource architecture is enabled

### Manual Testing

Verify deployment:

```bash
# Check collection installation
ansible-galaxy collection list | grep rhvp

# Check Helm repositories
helm repo list

# Check clustergroup-chart
helm list -A | grep clustergroup

# Check ArgoCD applications
oc get applications -n openshift-gitops
```

---

## Troubleshooting

### Common Issues

#### 1. Collection Installation Fails

**Symptom:**
```
FAILED! => {"msg": "Failed to install rhvp.cluster_utils collection"}
```

**Solution:**
```bash
# Manual installation
ansible-galaxy collection install rhvp.cluster_utils:1.0.0

# Or from requirements file
ansible-galaxy collection install -r files/requirements.yml
```

#### 2. Helm Repository Not Found

**Symptom:**
```
FAILED! => {"msg": "Helm repository not configured"}
```

**Solution:**
```bash
# Add repository manually
helm repo add validated-patterns https://validatedpatterns.io/charts
helm repo update
```

#### 3. clustergroup-chart Deployment Fails

**Symptom:**
```
FAILED! => {"msg": "Failed to deploy clustergroup-chart"}
```

**Solution:**
```bash
# Check Helm version
helm version  # Must be v3.12+

# Check chart availability
helm search repo clustergroup

# Manual deployment
helm install clustergroup validated-patterns/clustergroup-chart \
  --version 0.9.* \
  --namespace openshift-gitops
```

#### 4. Multisource Not Enabled

**Symptom:**
```
FAILED! => {"msg": "Multisource architecture not supported"}
```

**Solution:**
- Ensure clustergroup-chart version is 0.9.* or higher
- Verify ArgoCD version supports multisource
- Check ArgoCD configuration:
  ```bash
  oc get argocd openshift-gitops -n openshift-gitops -o yaml
  ```

#### 5. ArgoCD Not Found

**Symptom:**
```
FAILED! => {"msg": "ArgoCD instance not found in openshift-gitops"}
```

**Solution:**
```bash
# Check OpenShift GitOps operator
oc get csv -n openshift-operators | grep gitops

# Check ArgoCD instance
oc get argocd -n openshift-gitops

# If missing, install OpenShift GitOps operator
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: stable
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

### Debug Mode

Enable debug output:

```yaml
---
- name: Debug common deployment
  hosts: localhost
  vars:
    ansible_verbosity: 2
  roles:
    - validated_patterns_common
```

Run with verbose output:

```bash
ansible-playbook deploy_common.yml -vv
```

---

## Best Practices

1. **Run After Prerequisites** - Always run validated_patterns_prerequisites first
2. **Use Correct Chart Version** - Must use clustergroup-chart v0.9.* for multisource
3. **Verify GitOps** - Ensure OpenShift GitOps is installed before running
4. **Check Helm** - Verify Helm v3.12+ is installed
5. **Save Configuration** - Document custom variables for reproducibility

---

## Additional Resources

- **Validated Patterns:** https://validatedpatterns.io
- **rhvp.cluster_utils:** https://github.com/validatedpatterns/cluster-utils
- **Helm Documentation:** https://helm.sh/docs/
- **ArgoCD Documentation:** https://argo-cd.readthedocs.io/

---

**Document Version:** 1.0
**Last Updated:** 2025-10-27
**Maintained By:** Validated Patterns Toolkit Development Team
