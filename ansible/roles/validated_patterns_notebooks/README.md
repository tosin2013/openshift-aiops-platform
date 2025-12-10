# Ansible Role: validated_patterns_notebooks

> **⚠️ DEPRECATED - DO NOT USE**
>
> This role attempts OLM-based installation which is **NOT SUPPORTED** because the `jupyter-notebook-validator-operator` is **NOT published to OperatorHub.io**.
>
> **USE INSTEAD:** [`validated_patterns_jupyter_validator`](../validated_patterns_jupyter_validator/) role
> - **Method:** Kustomize-based installation
> - **Location:** `ansible/roles/validated_patterns_jupyter_validator/`
> - **Manifests:** `k8s/operators/jupyter-notebook-validator/overlays/dev-ocp4.18/`
>
> This role is kept for reference only and will display deprecation warnings if used.

---

## Description (DEPRECATED)

This role deploys the [Jupyter Notebook Validator Operator](https://github.com/tosin2013/jupyter-notebook-validator-operator) via OperatorHub/OLM and manages NotebookValidationJob CRDs for the OpenShift AIOps Self-Healing Platform.

**Key Features:**
- **OperatorHub Installation**: Installs operator via OLM (OperatorHub)
- **RHOAI Images**: Uses pre-built images from `redhat-ods-applications` ImageStreams
- **ArgoCD Sync Waves**: Sequential execution based on data/model dependencies
- **Tiered Resource Management**: Notebooks organized by complexity (tier1/tier2/tier3)
- **Automatic Pod Orchestration**: Operator creates validation pods directly using Papermill
- **Full Pipeline Validation**: Validates all 32 notebooks in dependency order

**Documentation References:**
- [Operator OperatorHub](https://operatorhub.io/operator/jupyter-notebook-validator-operator)
- [Operator Documentation](https://github.com/tosin2013/jupyter-notebook-validator-operator/blob/main/docs/)
- [Webhook Configuration](https://github.com/tosin2013/jupyter-notebook-validator-operator/blob/main/docs/WEBHOOK_CONFIGURATION.md)

**Related ADRs:**
- [ADR-029: Jupyter Notebook Validator Operator](../../docs/adrs/029-jupyter-notebook-validator-operator.md)
- [ADR-021: Tekton Pipeline Validation](../../docs/adrs/021-tekton-pipeline-deployment-validation.md)

## How It Works

1. **Operator Installation**: Installs via OperatorHub (OLM)
2. **CRD Creation**: Creates `NotebookValidationJob` CRs with sync wave annotations
3. **ArgoCD Sync**: Processes notebooks in wave order (0→1→2→...→10)
4. **Automatic Execution**: Operator creates validation pods using Papermill with RHOAI images
5. **Results**: Status stored in CRD, ArgoCD waits for completion before next wave

## Sync Wave Architecture

Notebooks are organized into 11 sync waves based on data/model dependencies:

| Wave | Phase | Notebooks | Dependencies |
|------|-------|-----------|--------------|
| 0 | Setup | platform-readiness, environment-setup | None (MUST run first) |
| 1 | Data Collection | prometheus-metrics, events, logs | Wave 0 |
| 2 | Feature Engineering | feature-store, synthetic-data | Wave 1 |
| 3 | Model Training | isolation-forest, timeseries, LSTM | Wave 2 |
| 4 | Ensemble | ensemble-anomaly-methods | Wave 3 (all models) |
| 5 | Healing Logic | rule-based, coordination-engine, AI | Wave 4 |
| 6 | Model Serving | kserve, versioning, inference | Wave 4 |
| 7 | E2E Scenarios | crash-loop, network, exhaustion | Waves 5-6 |
| 8 | Integrations | MCP, Lightspeed, LlamaStack | Wave 7 |
| 9 | Monitoring | prometheus, model-perf, healing | All previous |
| 10 | Advanced | multi-cluster, scaling, security, cost | All previous |

**Execution Flow:**
- ArgoCD syncs Wave 0 first
- Waits for all Wave 0 jobs to reach `Succeeded` status
- Proceeds to Wave 1, waits, then Wave 2, etc.
- Jobs within the same wave run in parallel

## Requirements

- OpenShift 4.18+ or Kubernetes 1.31+
- ArgoCD/OpenShift GitOps (for sync wave support)
- cert-manager v1.13+ (optional, for webhook mode)
- Ansible 2.9+
- `kubernetes.core` Ansible collection

## Role Variables

### Operator Installation

```yaml
notebooks_operator_enabled: true
notebooks_install_method: "olm"  # OLM only (OperatorHub)
notebooks_operator_namespace: "jupyter-notebook-validator-system"
notebooks_operator_channel: "alpha"
notebooks_operator_catalog_source: "community-operators"
```

### Sync Wave Configuration

```yaml
# Enable sync waves for ArgoCD (required for full pipeline validation)
notebooks_enable_sync_waves: true

# Filter by tier (optional)
notebooks_validation_tiers: "all"  # 'all', 'tier1', 'tier2', 'tier3', or list
```

### Webhook Configuration

Per [WEBHOOK_CONFIGURATION.md](https://github.com/tosin2013/jupyter-notebook-validator-operator/blob/main/docs/WEBHOOK_CONFIGURATION.md):

```yaml
# Webhooks disabled by default on OperatorHub installations
notebooks_enable_webhooks: false

# When webhooks disabled, these are REQUIRED:
notebooks_service_account: "default"  # serviceAccountName in podConfig
# timeout is auto-set per tier
# envFrom used instead of credentials shorthand
```

### Resource Configuration by Tier

```yaml
# Tier 1: Simple validation (<2 min)
notebooks_tier1_memory_request: "512Mi"
notebooks_tier1_cpu_request: "500m"
notebooks_tier1_timeout: "5m"

# Tier 2: Standard (2-10 min)
notebooks_tier2_memory_request: "2Gi"
notebooks_tier2_cpu_request: "1000m"
notebooks_tier2_timeout: "15m"

# Tier 3: Complex (10-30+ min)
notebooks_tier3_memory_request: "4Gi"
notebooks_tier3_cpu_request: "2000m"
notebooks_tier3_timeout: "45m"
```

### Container Images

```yaml
# RHOAI images from redhat-ods-applications ImageStreams (Papermill pre-installed)
notebooks_image_tier1: "image-registry.openshift-image-registry.svc:5000/redhat-ods-applications/s2i-minimal-notebook:2025.1"
notebooks_image_tier2: "image-registry.openshift-image-registry.svc:5000/redhat-ods-applications/s2i-generic-data-science-notebook:2025.1"
notebooks_image_tier3: "image-registry.openshift-image-registry.svc:5000/redhat-ods-applications/pytorch:2025.1"
```

## Example Playbooks

### Deploy Operator Only

```yaml
- name: Deploy Jupyter Notebook Validator Operator
  hosts: localhost
  roles:
    - role: validated_patterns_notebooks
      vars:
        notebooks_operator_enabled: true
        notebooks_create_validation_jobs: false
```

### Full Pipeline Validation (All Waves)

```yaml
- name: Deploy with Full Pipeline Validation
  hosts: localhost
  roles:
    - role: validated_patterns_notebooks
      vars:
        notebooks_operator_enabled: true
        notebooks_create_validation_jobs: true
        notebooks_enable_sync_waves: true
        notebooks_validation_tiers: "all"
```

### Quick Validation (Tier 1 Only)

```yaml
- name: Deploy with Quick Validation
  hosts: localhost
  roles:
    - role: validated_patterns_notebooks
      vars:
        notebooks_operator_enabled: true
        notebooks_create_validation_jobs: true
        notebooks_validation_tiers: "tier1"
```

### Custom Wave Selection

```yaml
- name: Deploy Specific Waves
  hosts: localhost
  roles:
    - role: validated_patterns_notebooks
      vars:
        notebooks_operator_enabled: true
        notebooks_create_validation_jobs: true
        notebooks_validation_tiers: ['tier1', 'tier2']
```

## Monitoring Validation

```bash
# List all validation jobs with wave and status
oc get notebookvalidationjobs -n self-healing-platform \
  -o custom-columns='NAME:.metadata.name,WAVE:.metadata.labels.sync-wave,TIER:.metadata.labels.tier,STATUS:.status.phase'

# Watch validation progress
oc get notebookvalidationjobs -n self-healing-platform -w

# Get detailed status for a specific job
oc describe notebookvalidationjob platform-readiness-validation -n self-healing-platform

# View validation pod logs
oc logs -l app.kubernetes.io/managed-by=jupyter-notebook-validator-operator -n self-healing-platform
```

## ArgoCD Integration

The role adds ArgoCD annotations to NotebookValidationJob CRDs:

```yaml
annotations:
  argocd.argoproj.io/sync-wave: "0"  # Wave number
  argocd.argoproj.io/hook: "Sync"
  argocd.argoproj.io/hook-delete-policy: "HookSucceeded"
```

**Custom Health Check** (add to ArgoCD ConfigMap):

```lua
hs = {}
if obj.status ~= nil then
  if obj.status.phase == "Succeeded" then
    hs.status = "Healthy"
  elseif obj.status.phase == "Failed" then
    hs.status = "Degraded"
  elseif obj.status.phase == "Running" then
    hs.status = "Progressing"
  else
    hs.status = "Progressing"
  end
else
  hs.status = "Progressing"
end
return hs
```

## Notebook Summary

| Tier | Count | Execution Time | Characteristics |
|------|-------|----------------|-----------------|
| Tier 1 | 5 | <2 min | Basic validation, no ML, no external services |
| Tier 2 | 12 | 2-10 min | Data collection, Prometheus/K8s deps, basic ML |
| Tier 3 | 15 | 10-30+ min | Complex ML, GPU recommended, external integrations |

**Total: 32 notebooks across 11 sync waves**

## Dependencies

- `validated_patterns_prerequisites` - Cluster validation
- `validated_patterns_common` - Helm CLI
- `validated_patterns_secrets` (Optional) - External Secrets Operator

## License

GNU General Public License v3.0

## Author Information

OpenShift AIOps Platform Team
Based on [Jupyter Notebook Validator Operator](https://github.com/tosin2013/jupyter-notebook-validator-operator)
