# Ansible Role: validated_patterns_jupyter_validator

Deploy and manage the Jupyter Notebook Validator Operator for automated notebook validation.

## Description

This role deploys the [Jupyter Notebook Validator Operator](https://github.com/tosin2013/jupyter-notebook-validator-operator) via kustomize manifests (self-contained in the project).

**Key Features:**
- **Self-contained deployment**: Kustomize manifests included in project (k8s/operators/jupyter-notebook-validator)
- **ADR-030 compliant**: Follows Hybrid Management Pattern (cluster-scoped resources via Ansible)
- **Multi-version support**: Overlays for OCP 4.18, 4.19, 4.20
- **Automatic webhook detection**: Enables webhooks if cert-manager is present
- **NotebookValidationJob CRDs**: Declarative notebook validation resources

**Documentation References:**
- [ADR-029: Jupyter Notebook Validator Operator](../../docs/adrs/029-jupyter-notebook-validator-operator.md)
- [ADR-030: Hybrid Management Model](../../docs/adrs/030-hybrid-management-model-namespaced-argocd.md)
- [Operator GitHub Repository](https://github.com/tosin2013/jupyter-notebook-validator-operator)

## Requirements

- OpenShift 4.18+ or Kubernetes 1.31+
- Ansible 2.9+
- `kubernetes.core` Ansible collection
- cert-manager v1.13+ (optional, for webhook support)

## Role Variables

### Operator Configuration

```yaml
# Enable/disable operator deployment
jupyter_validator_operator_enabled: true

# OpenShift version (determines overlay selection)
jupyter_validator_openshift_version: "4.18"

# Kustomize paths (relative to project root)
jupyter_validator_kustomize_base: "k8s/operators/jupyter-notebook-validator"
jupyter_validator_kustomize_overlay: "overlays/dev-ocp4.18"

# Namespaces
jupyter_validator_operator_namespace: "jupyter-notebook-validator-operator"
jupyter_validator_validation_namespace: "self-healing-platform"

# Operator images (from overlays)
jupyter_validator_images:
  ocp4.18: "quay.io/takinosh/jupyter-notebook-validator-operator:1.0.7-ocp4.18"
  ocp4.19: "quay.io/takinosh/jupyter-notebook-validator-operator:1.0.8-ocp4.19"
  ocp4.20: "quay.io/takinosh/jupyter-notebook-validator-operator:1.0.9-ocp4.20"

# Webhook configuration (auto-detected)
jupyter_validator_enable_webhooks: false
```

## Dependencies

- `kubernetes.core` collection (for kustomize lookup)

## Example Playbooks

### Deploy Operator

```yaml
- name: Deploy Jupyter Notebook Validator Operator
  hosts: localhost
  roles:
    - role: validated_patterns_jupyter_validator
      vars:
        jupyter_validator_operator_enabled: true
        jupyter_validator_openshift_version: "4.18"
```

### Cleanup Operator

```yaml
- name: Cleanup Jupyter Notebook Validator Operator
  hosts: localhost
  roles:
    - role: validated_patterns_jupyter_validator
      tasks_from: cleanup_operator
```

## Deployment Architecture

```
k8s/operators/jupyter-notebook-validator/
├── base/                           # Base manifests
│   ├── crd/                        # NotebookValidationJob CRD
│   ├── rbac/                       # ClusterRole, ClusterRoleBinding
│   ├── manager/                    # Operator Deployment
│   ├── certmanager/                # Certificates (webhooks)
│   └── webhook/                    # Webhook configuration
└── overlays/
    ├── dev-ocp4.18/                # OCP 4.18 specific
    ├── dev-ocp4.19/                # OCP 4.19 specific
    └── dev-ocp4.20/                # OCP 4.20 specific
```

## Usage

### Via Make Targets (Recommended)

```bash
# Install operator
make install-jupyter-validator

# Verify installation
make validate-jupyter-validator

# Test with sample notebook
make test-jupyter-validator

# Uninstall operator
make uninstall-jupyter-validator
```

### Direct Ansible Execution

```bash
# Install
ansible-playbook ansible/playbooks/install_jupyter_validator_operator.yml

# Uninstall
ansible-playbook ansible/playbooks/uninstall_jupyter_validator_operator.yml
```

## Monitoring Validation

```bash
# List all validation jobs
oc get notebookvalidationjobs -n self-healing-platform

# Watch validation progress
oc get notebookvalidationjobs -n self-healing-platform -w

# Get detailed status
oc describe notebookvalidationjob <job-name> -n self-healing-platform

# View validation pod logs
oc logs -l job-name=<job-name> -n self-healing-platform
```

## License

GNU General Public License v3.0

## Author Information

OpenShift AIOps Platform Team
Based on [Jupyter Notebook Validator Operator](https://github.com/tosin2013/jupyter-notebook-validator-operator)
