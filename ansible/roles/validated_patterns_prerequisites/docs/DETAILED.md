# validated_patterns_prerequisites - Detailed Documentation

**Role Name:** validated_patterns_prerequisites
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

The `validated_patterns_prerequisites` role validates that an OpenShift cluster meets all requirements for deploying Validated Patterns. It performs comprehensive checks on cluster version, resources, operators, network connectivity, RBAC permissions, and storage.

### Key Features

- ✅ OpenShift version validation
- ✅ Cluster resource checks (nodes, CPU, memory)
- ✅ Operator availability verification
- ✅ Network connectivity testing
- ✅ RBAC permissions validation
- ✅ Storage class verification
- ✅ Detailed validation reporting

### When to Use

Use this role:
- **Before pattern deployment** - Validate cluster readiness
- **In CI/CD pipelines** - Automated prerequisite checks
- **For troubleshooting** - Identify cluster issues
- **For documentation** - Generate cluster capability reports

---

## Purpose

This role ensures that:

1. **Cluster Version** - OpenShift 4.12+ is installed
2. **Cluster Resources** - Sufficient nodes, CPU, and memory
3. **Required Operators** - OpenShift GitOps is available
4. **Network Connectivity** - Cluster can reach required endpoints
5. **RBAC Permissions** - User has necessary permissions
6. **Storage** - Default storage class is configured

### Validation Flow

```
┌─────────────────────────────────────────┐
│  validated_patterns_prerequisites       │
└─────────────────────────────────────────┘
              ↓
    ┌─────────────────────┐
    │ Check OpenShift     │
    │ Version (4.12+)     │
    └─────────────────────┘
              ↓
    ┌─────────────────────┐
    │ Check Operators     │
    │ (GitOps required)   │
    └─────────────────────┘
              ↓
    ┌─────────────────────┐
    │ Check Resources     │
    │ (Nodes, CPU, RAM)   │
    └─────────────────────┘
              ↓
    ┌─────────────────────┐
    │ Check Network       │
    │ (Connectivity)      │
    └─────────────────────┘
              ↓
    ┌─────────────────────┐
    │ Check RBAC          │
    │ (Permissions)       │
    └─────────────────────┘
              ↓
    ┌─────────────────────┐
    │ Check Storage       │
    │ (Default class)     │
    └─────────────────────┘
              ↓
    ┌─────────────────────┐
    │ Display Summary     │
    │ (Pass/Fail)         │
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
```

Install collections:

```bash
ansible-galaxy collection install kubernetes.core community.general
```

### OpenShift Requirements

- **OpenShift Version:** 4.12 or higher
- **Cluster Access:** Valid kubeconfig with cluster-admin permissions
- **CLI Tools:** `oc` command-line tool

### Python Requirements

```
kubernetes>=12.0.0
openshift>=0.12.0
PyYAML>=5.4.0
```

---

## Variables

### Default Variables

All default variables are defined in `defaults/main.yml`:

#### Minimum OpenShift Version

```yaml
validated_patterns_min_openshift_version: "4.12"
```

**Description:** Minimum required OpenShift version
**Type:** String
**Default:** "4.12"
**Valid Values:** "4.12", "4.13", "4.14", etc.

#### Minimum Cluster Resources

```yaml
validated_patterns_min_nodes: 3
validated_patterns_min_cpu: 8  # in cores
validated_patterns_min_memory: 16  # in GB
```

**Description:** Minimum cluster resource requirements
**Type:** Integer
**Defaults:**
- `validated_patterns_min_nodes`: 3
- `validated_patterns_min_cpu`: 8 cores
- `validated_patterns_min_memory`: 16 GB

**Valid Values:**
- `min_nodes`: 1-100
- `min_cpu`: 4-1000 cores
- `min_memory`: 8-10000 GB

#### Required Operators

```yaml
validated_patterns_required_operators:
  - openshift-gitops-operator
```

**Description:** List of operators that must be installed
**Type:** List of strings
**Default:** `["openshift-gitops-operator"]`
**Valid Values:** Any valid operator name from OperatorHub

#### Optional Operators

```yaml
validated_patterns_optional_operators:
  - openshift-pipelines-operator
  - advanced-cluster-management
```

**Description:** List of operators that are optional but recommended
**Type:** List of strings
**Default:** `["openshift-pipelines-operator", "advanced-cluster-management"]`
**Valid Values:** Any valid operator name from OperatorHub

### Variable Customization

Override variables in your playbook:

```yaml
---
- name: Validate prerequisites with custom settings
  hosts: localhost
  vars:
    validated_patterns_min_openshift_version: "4.14"
    validated_patterns_min_nodes: 5
    validated_patterns_min_cpu: 16
    validated_patterns_min_memory: 32
    validated_patterns_required_operators:
      - openshift-gitops-operator
      - openshift-pipelines-operator
  roles:
    - validated_patterns_prerequisites
```

---

## Tasks

### Main Tasks (tasks/main.yml)

The role executes the following task files in order:

#### 1. check_openshift_version.yml

**Purpose:** Validate OpenShift cluster version

**Tasks:**
- Get cluster version information
- Parse version string
- Compare with minimum required version
- Fail if version is too old

**Variables Used:**
- `validated_patterns_min_openshift_version`

**Example Output:**
```
TASK [Check OpenShift version] *****
ok: [localhost] => {
    "msg": "OpenShift version 4.14.0 meets minimum requirement 4.12"
}
```

#### 2. check_operators.yml

**Purpose:** Verify required operators are installed

**Tasks:**
- List all installed operators
- Check for required operators
- Check for optional operators
- Report operator status

**Variables Used:**
- `validated_patterns_required_operators`
- `validated_patterns_optional_operators`

**Example Output:**
```
TASK [Check required operators] *****
ok: [localhost] => {
    "msg": "All required operators are installed: openshift-gitops-operator"
}
```

#### 3. check_cluster_resources.yml

**Purpose:** Validate cluster has sufficient resources

**Tasks:**
- Count cluster nodes
- Calculate total CPU cores
- Calculate total memory
- Compare with minimum requirements
- Fail if resources are insufficient

**Variables Used:**
- `validated_patterns_min_nodes`
- `validated_patterns_min_cpu`
- `validated_patterns_min_memory`

**Example Output:**
```
TASK [Check cluster resources] *****
ok: [localhost] => {
    "msg": "Cluster resources: 3 nodes, 12 CPU cores, 24 GB memory"
}
```

#### 4. check_network.yml

**Purpose:** Test network connectivity

**Tasks:**
- Test connectivity to OpenShift API
- Test connectivity to image registries
- Test DNS resolution
- Report network status

**Example Output:**
```
TASK [Check network connectivity] *****
ok: [localhost] => {
    "msg": "Network connectivity verified"
}
```

#### 5. check_rbac.yml

**Purpose:** Validate user permissions

**Tasks:**
- Check current user
- Verify cluster-admin permissions
- Test resource creation permissions
- Report permission status

**Example Output:**
```
TASK [Check RBAC permissions] *****
ok: [localhost] => {
    "msg": "User has cluster-admin permissions"
}
```

#### 6. check_storage.yml

**Purpose:** Verify storage configuration

**Tasks:**
- List storage classes
- Identify default storage class
- Verify storage class is functional
- Report storage status

**Example Output:**
```
TASK [Check storage] *****
ok: [localhost] => {
    "msg": "Default storage class: gp3-csi"
}
```

---

## Dependencies

### Role Dependencies

This role has no dependencies on other Ansible roles.

### Collection Dependencies

Defined in `meta/main.yml`:

```yaml
collections:
  - kubernetes.core
  - community.general
```

### External Dependencies

- **OpenShift CLI (`oc`):** Used for cluster operations
- **Kubernetes Python Client:** Used by kubernetes.core collection
- **Valid kubeconfig:** Must be configured before running role

---

## Usage Examples

### Example 1: Basic Usage

```yaml
---
- name: Validate cluster prerequisites
  hosts: localhost
  connection: local
  gather_facts: no
  roles:
    - validated_patterns_prerequisites
```

Run:

```bash
ansible-playbook validate_prerequisites.yml
```

### Example 2: Custom Requirements

```yaml
---
- name: Validate with custom requirements
  hosts: localhost
  connection: local
  gather_facts: no
  vars:
    validated_patterns_min_openshift_version: "4.14"
    validated_patterns_min_nodes: 5
    validated_patterns_min_cpu: 16
    validated_patterns_min_memory: 32
  roles:
    - validated_patterns_prerequisites
```

### Example 3: CI/CD Pipeline

```yaml
---
- name: CI/CD prerequisite check
  hosts: localhost
  connection: local
  gather_facts: no
  vars:
    validated_patterns_required_operators:
      - openshift-gitops-operator
      - openshift-pipelines-operator
      - advanced-cluster-management
  roles:
    - validated_patterns_prerequisites

  post_tasks:
    - name: Generate validation report
      copy:
        content: |
          Cluster Validation Report
          =========================
          OpenShift Version: {{ ocp_version }}
          Nodes: {{ cluster_nodes.resources | length }}
          Storage Classes: {{ storage_classes.resources | length }}
        dest: /tmp/validation-report.txt
```

### Example 4: With ansible-navigator

```bash
ansible-navigator run validate_prerequisites.yml \
  --execution-environment-image quay.io/ansible/creator-ee:latest \
  --mode stdout
```

---

## Testing

### Running Tests

The role includes a test playbook in `tests/test.yml`:

```bash
# Run tests
cd ansible/roles/validated_patterns_prerequisites
ansible-playbook tests/test.yml

# Run with ansible-navigator
ansible-navigator run tests/test.yml --mode stdout
```

### Test Coverage

The test playbook validates:
- ✅ Role executes without errors
- ✅ All prerequisite checks complete
- ✅ Validation summary is displayed
- ✅ Variables can be overridden

### Manual Testing

Test individual checks:

```bash
# Test OpenShift version
oc version

# Test operators
oc get csv -A | grep gitops

# Test cluster resources
oc get nodes
oc describe nodes | grep -E "cpu|memory"

# Test storage
oc get storageclass
```

---

## Troubleshooting

### Common Issues

#### 1. OpenShift Version Too Old

**Symptom:**
```
FAILED! => {"msg": "OpenShift version 4.11 is below minimum 4.12"}
```

**Solution:**
- Upgrade OpenShift cluster to 4.12+
- Or override minimum version (not recommended):
  ```yaml
  validated_patterns_min_openshift_version: "4.11"
  ```

#### 2. Required Operator Not Found

**Symptom:**
```
FAILED! => {"msg": "Required operator not found: openshift-gitops-operator"}
```

**Solution:**
```bash
# Install OpenShift GitOps operator
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

#### 3. Insufficient Cluster Resources

**Symptom:**
```
FAILED! => {"msg": "Cluster has only 2 nodes, minimum 3 required"}
```

**Solution:**
- Add more nodes to cluster
- Or override minimum (for testing only):
  ```yaml
  validated_patterns_min_nodes: 2
  ```

#### 4. RBAC Permission Denied

**Symptom:**
```
FAILED! => {"msg": "User does not have cluster-admin permissions"}
```

**Solution:**
```bash
# Login as cluster-admin
oc login -u system:admin

# Or grant cluster-admin to user
oc adm policy add-cluster-role-to-user cluster-admin <username>
```

#### 5. No Default Storage Class

**Symptom:**
```
FAILED! => {"msg": "No default storage class found"}
```

**Solution:**
```bash
# Set default storage class
oc patch storageclass <storage-class-name> \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Debug Mode

Enable debug output:

```yaml
---
- name: Debug prerequisite checks
  hosts: localhost
  vars:
    ansible_verbosity: 2
  roles:
    - validated_patterns_prerequisites
```

Run with verbose output:

```bash
ansible-playbook validate_prerequisites.yml -vv
```

---

## Best Practices

1. **Always Run First** - Run this role before any pattern deployment
2. **CI/CD Integration** - Include in automated pipelines
3. **Custom Requirements** - Override defaults for specific patterns
4. **Save Reports** - Generate validation reports for documentation
5. **Regular Checks** - Re-run after cluster changes

---

## Additional Resources

- **Validated Patterns:** https://validatedpatterns.io
- **OpenShift Documentation:** https://docs.openshift.com
- **Ansible Documentation:** https://docs.ansible.com

---

**Document Version:** 1.0
**Last Updated:** 2025-10-27
**Maintained By:** Validated Patterns Toolkit Development Team
