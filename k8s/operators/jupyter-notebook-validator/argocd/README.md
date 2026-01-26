# ArgoCD Integration for Jupyter Notebook Validator Operator

This directory contains ArgoCD integration resources for the Jupyter Notebook Validator Operator v1.0.5+.

## Features

- **Health Assessment**: NotebookValidationJob status visible in ArgoCD UI
- **Post-Success Resource Hooks**: Auto-restart InferenceServices when notebooks succeed
- **Sync Wave Awareness**: Coordinate notebook execution with ArgoCD deployment waves
- **Application Status Integration**: Aggregated notebook status in ArgoCD Applications
- **Notification Events**: Kubernetes Events for ArgoCD notifications

## Installation

### Option 1: Automated via Ansible (Recommended)

The ArgoCD health check ConfigMap is **automatically applied** when deploying the operator via Ansible:

```bash
ansible-playbook ansible/playbooks/install_jupyter_validator_operator.yml
```

The Ansible role will:
1. Deploy the jupyter-notebook-validator operator
2. Verify the operator is running
3. **Automatically configure ArgoCD** with NotebookValidationJob health checks
4. Restart ArgoCD services to reload the configuration

**Configuration Variables** (in `ansible/roles/validated_patterns_jupyter_validator/defaults/main.yml`):
- `jupyter_validator_configure_argocd: true` - Enable/disable ArgoCD configuration
- `jupyter_validator_argocd_namespace: "openshift-gitops"` - ArgoCD namespace
- `jupyter_validator_argocd_configmap_path: "k8s/operators/jupyter-notebook-validator/argocd/health-check-configmap.yaml"`

### Option 2: Manual Installation

If deploying the operator manually or if ArgoCD is installed after the operator:

```bash
kubectl apply -f health-check-configmap.yaml

# Restart ArgoCD repo-server to reload health checks
kubectl rollout restart deployment openshift-gitops-repo-server -n openshift-gitops
kubectl rollout restart deployment openshift-gitops-server -n openshift-gitops
```

### Verify Installation

```bash
# Check ConfigMap applied
oc get cm argocd-cm -n openshift-gitops -o yaml | grep NotebookValidationJob

# Verify ArgoCD services are ready
oc rollout status deployment openshift-gitops-repo-server -n openshift-gitops
oc rollout status deployment openshift-gitops-server -n openshift-gitops
```

## Usage

### Auto-Restart InferenceServices

Add annotation to NotebookValidationJob to automatically restart InferenceServices when notebook validation succeeds:

```yaml
apiVersion: mlops.mlops.dev/v1alpha1
kind: NotebookValidationJob
metadata:
  name: predictive-analytics-kserve-validation
  namespace: self-healing-platform
  annotations:
    # ArgoCD sync wave - run notebook before InferenceService
    argocd.argoproj.io/sync-wave: "3"

    # CRITICAL: Auto-restart InferenceService when notebook succeeds
    mlops.dev/on-success-trigger: |
      - apiVersion: serving.kserve.io/v1beta1
        kind: InferenceService
        name: predictive-analytics
        namespace: self-healing-platform
        action: restart

    # Optional: Block next wave until this completes
    mlops.dev/block-wave: "4"
spec:
  # ... notebook validation spec
```

### Health Status in ArgoCD UI

Once installed, NotebookValidationJob resources will show health status in ArgoCD:

- **Healthy**: Validation succeeded
- **Degraded**: Validation failed
- **Progressing**: Validation in progress

## References

- Operator ADR-049: ArgoCD Integration Strategy
- Operator docs: `/home/lab-user/jupyter-notebook-validator-operator/docs/ARGOCD_INTEGRATION.md`
- Platform ADR-029: Jupyter Notebook Validator Operator
