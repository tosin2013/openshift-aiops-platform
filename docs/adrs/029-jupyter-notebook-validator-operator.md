# ADR-029: Jupyter Notebook Validator Operator for Notebook Validation

**Status:** IMPLEMENTED
**Date:** 2025-11-18
**Updated:** 2025-12-01 (Added volume support for model storage)
**Decision Makers:** Architecture Team, ML Engineering
**Consulted:** DevOps Team, Platform Engineering
**Informed:** Operations Team, Data Science Team

## Context

The OpenShift AIOps Self-Healing Platform includes 30+ Jupyter notebooks across 8 directories that require automated validation and execution tracking. The notebooks implement critical ML workflows including data collection, anomaly detection, model training, and deployment to KServe.

### Current State (ADR-021 Implementation)

The current implementation uses **Tekton pipelines** for notebook validation:
- Notebooks executed directly in Tekton tasks via `jupyter nbconvert --execute`
- Validation mixed with infrastructure health checks
- No declarative notebook job management
- Limited resource isolation per notebook
- Difficult to track individual notebook execution history

### Problems with Current Approach

1. **Tight Coupling**: Notebook execution tightly coupled to Tekton pipeline infrastructure
2. **Resource Management**: No per-notebook resource requests/limits configuration
3. **Execution Tracking**: Difficult to track individual notebook runs and artifacts
4. **Git Integration**: Manual git clone in Tekton tasks, no credential management
5. **Validation Reporting**: No standardized notebook validation results format
6. **Scalability**: All notebooks share same pipeline execution context
7. **Model Storage**: No persistent storage for trained models across validation runs

### New Requirements

Based on [Jupyter Notebook Validator Operator](https://raw.githubusercontent.com/tosin2013/jupyter-notebook-validator-operator/refs/heads/release-4.18/helm/jupyter-notebook-validator-operator/INSTALLATION.md) capabilities:

1. **CRD-Based Validation**: Declarative NotebookValidationJob resources
2. **Git Integration**: Native support for public and private Git repositories
3. **Resource Isolation**: Per-notebook resource requests and limits
4. **Artifact Collection**: Automatic validation pod log collection
5. **Credential Management**: Kubernetes secret integration for private repos
6. **Webhook Support**: Validation via cert-manager webhooks
7. **Volume Support**: PVC mounting for persistent model storage (NEW - 2025-12-01)

## Decision

**Adopt the Jupyter Notebook Validator Operator** as the primary notebook validation mechanism, superseding Tekton-based notebook execution from ADR-021.

### Architecture

```
Notebook Validation Architecture:
┌─────────────────────────────────────────────────────────────┐
│              Jupyter Notebook Validator Operator            │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  NotebookValidationJob CRDs                         │    │
│  │  (mlops.mlops.dev/v1alpha1)                         │    │
│  └─────────────────────────────────────────────────────┘    │
│           │                                                  │
│           ▼                                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Validation Controller                              │    │
│  │  - Watches NotebookValidationJob CRDs               │    │
│  │  - Creates validation pods                          │    │
│  │  - Collects execution logs                          │    │
│  │  - Updates CRD status                               │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Validation Pods (per notebook)                 │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  1. Git Clone (from spec.notebook.git.url)          │    │
│  │  2. Install Dependencies (requirements.txt)         │    │
│  │  3. Execute Notebook (jupyter nbconvert --execute)  │    │
│  │  4. Collect Artifacts (logs, outputs)               │    │
│  │  5. Update CRD Status (Success/Failed)              │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Git Repository Integration                     │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Public Repos: Direct HTTPS clone                   │    │
│  │  Private Repos: Kubernetes secret credentials       │    │
│  │    - username/password (PAT tokens)                 │    │
│  │    - SSH keys                                       │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### NotebookValidationJob CRD Example

#### Basic Notebook Validation (Without Volumes)

```yaml
apiVersion: mlops.mlops.dev/v1alpha1
kind: NotebookValidationJob
metadata:
  name: anomaly-detection-isolation-forest
  namespace: self-healing-platform
spec:
  notebook:
    git:
      url: "https://github.com/openshift-aiops/openshift-aiops-platform.git"
      ref: "main"
      credentialsSecret: "github-credentials"  # For private repos
    path: "notebooks/02-anomaly-detection/01-isolation-forest-implementation.ipynb"

  podConfig:
    containerImage: "quay.io/jupyter/minimal-notebook:latest"
    resources:
      requests:
        memory: "2Gi"
        cpu: "1000m"
      limits:
        memory: "4Gi"
        cpu: "2000m"

  timeout: "30m"
```

#### Advanced Notebook Validation (With Model Storage Volumes)

**NEW (2025-12-01)**: The Jupyter Notebook Validator Operator now supports volume mounting, enabling persistent model storage across validation runs.

```yaml
apiVersion: mlops.mlops.dev/v1alpha1
kind: NotebookValidationJob
metadata:
  name: model-training-with-storage
  namespace: self-healing-platform
spec:
  notebook:
    git:
      url: "https://github.com/openshift-aiops/openshift-aiops-platform.git"
      ref: "main"
      credentialsSecret: "github-credentials"
    path: "notebooks/03-model-training/ensemble-model-training.ipynb"

  podConfig:
    containerImage: "quay.io/modh/runtime-images:jupyter-datascience-ubi9-python-3.11-2025.1"
    resources:
      requests:
        memory: "4Gi"
        cpu: "2000m"
        nvidia.com/gpu: "1"  # GPU support for model training
      limits:
        memory: "8Gi"
        cpu: "4000m"
        nvidia.com/gpu: "1"

    # Volume mounts for persistent model storage
    volumes:
      - name: model-storage
        persistentVolumeClaim:
          claimName: model-storage-pvc
      - name: data-storage
        persistentVolumeClaim:
          claimName: data-storage-pvc

    volumeMounts:
      - name: model-storage
        mountPath: /opt/app-root/src/models
      - name: data-storage
        mountPath: /opt/app-root/src/data

  timeout: "60m"
```

**Use Cases for Volume Support**:
1. **Model Training Notebooks**: Store trained models in PVCs for later deployment
2. **Data Preprocessing**: Cache preprocessed datasets across validation runs
3. **Artifact Persistence**: Maintain validation artifacts and logs
4. **Model Versioning**: Track model versions across multiple training runs
5. **Shared Storage**: Enable multiple notebooks to access common model repository

### Operator Deployment

The operator requires:

1. **cert-manager v1.13+**: For webhook certificate management
2. **Helm 3.8+**: Operator deployment via Helm chart
3. **Kubernetes 1.31+ / OpenShift 4.18+**: Platform requirements

**Helm Installation**:
```bash
helm install jupyter-validator \
  https://github.com/tosin2013/jupyter-notebook-validator-operator/releases/download/release-4.18/jupyter-notebook-validator-operator-0.1.0.tgz \
  --namespace jupyter-validator-system \
  --create-namespace \
  --set openshift.enabled=true \
  --set prometheus.enabled=true
```

### Deployment via Validated Patterns (2025-12-04 Update)

**Status**: Operator NOT yet in OperatorHub/marketplace (submission in progress)

**Deployment Method**: Self-contained kustomize deployment following ADR-030 Hybrid Management Pattern

**Architecture**:
```
k8s/operators/jupyter-notebook-validator/
├── base/                           # Base manifests
│   ├── crd/                        # NotebookValidationJob CRD
│   ├── rbac/                       # ClusterRole, ClusterRoleBinding, ServiceAccount
│   ├── manager/                    # Operator Deployment
│   ├── certmanager/                # Certificates (optional - webhooks)
│   └── webhook/                    # Webhook configuration (optional)
└── overlays/
    ├── dev-ocp4.18/                # OCP 4.18 (image: 1.0.7-ocp4.18)
    ├── dev-ocp4.19/                # OCP 4.19 (image: 1.0.8-ocp4.19)
    └── dev-ocp4.20/                # OCP 4.20 (image: 1.0.9-ocp4.20)
```

**Installation**:
```bash
# Build execution environment (first time)
make build-ee

# Install operator
make install-jupyter-validator

# Verify installation
make validate-jupyter-validator

# Test with sample notebook
make test-jupyter-validator
```

**Uninstallation**:
```bash
make uninstall-jupyter-validator
```

**Deployment Flow**:
1. Kustomize builds overlay: `k8s/operators/jupyter-notebook-validator/overlays/dev-ocp4.18`
2. Ansible applies manifests: `kubernetes.core.k8s` with kustomize lookup
3. Operator deployed to: `jupyter-notebook-validator-operator` namespace
4. CRD registered: `notebookvalidationjobs.mlops.mlops.dev`
5. Validation jobs created in: `self-healing-platform` namespace

**Key Features**:
- ✅ **Self-contained**: All manifests in project (no external dependencies)
- ✅ **Version controlled**: Operator manifests tracked in git
- ✅ **ADR-030 compliant**: Cluster-scoped resources via Ansible
- ✅ **Multi-version support**: Overlays for OCP 4.18, 4.19, 4.20
- ✅ **Optional webhooks**: Auto-enabled if cert-manager present

**Comparison with OLM Deployment** (when available):
| Aspect | Current (Kustomize) | Future (OLM) |
|--------|---------------------|--------------|
| Method | Direct manifest deployment | OperatorHub subscription |
| Namespace | `jupyter-notebook-validator-operator` | `openshift-operators` |
| Updates | Manual (update manifests) | Automatic (OLM) |
| Dependencies | None | OLM, CatalogSource |
| Flexibility | Full control | Limited to operator package |

**Ansible Role**: `validated_patterns_jupyter_validator`

**Role Tasks**:
- `tasks/main.yml` - Orchestration and cert-manager detection
- `tasks/deploy_operator.yml` - Kustomize deployment
- `tasks/verify_operator.yml` - Health checks and validation
- `tasks/cleanup_operator.yml` - Uninstallation and cleanup

**Playbooks**:
- `ansible/playbooks/install_jupyter_validator_operator.yml` - Installation playbook
- `ansible/playbooks/uninstall_jupyter_validator_operator.yml` - Cleanup playbook

### Integration with Existing Infrastructure

**Storage Integration** (Updated 2025-12-01):
- Validation pods use same storage classes as workbenches (gp3-csi)
- **NEW**: PVC mounting enables persistent model storage across validation runs
- **NEW**: Models can be stored in PVCs and accessed by multiple notebooks
- **NEW**: Integration with ADR-024 (External Secrets for Model Storage) and ADR-025 (Object Store)
- Notebook artifacts stored in persistent volumes
- Integration with existing ODF/NooBaa for model artifacts
- **Workflow**: Train models in notebooks → Store in PVCs → Deploy to KServe from PVCs

**RBAC Integration**:
- NotebookValidationJob CRDs use existing service accounts
- Validation pods inherit workbench security context
- Integration with OpenShift RBAC policies
- **NEW**: PVC access requires appropriate RBAC permissions for validation pods

**Monitoring Integration**:
- Operator exposes Prometheus metrics
- Validation job status tracked via CRD conditions
- Integration with existing Grafana dashboards
- **NEW**: Volume usage metrics tracked for model storage PVCs

## Consequences

### Positive Consequences

- ✅ **Declarative Management**: NotebookValidationJob CRDs provide declarative notebook validation
- ✅ **Resource Isolation**: Per-notebook resource requests/limits prevent resource contention
- ✅ **Git Integration**: Native support for public and private Git repositories
- ✅ **Credential Management**: Kubernetes secret integration for secure credential handling
- ✅ **Execution Tracking**: CRD status provides clear notebook execution history
- ✅ **Scalability**: Independent validation pods scale horizontally
- ✅ **Artifact Collection**: Automatic log collection and status reporting
- ✅ **Webhook Validation**: cert-manager integration for secure webhooks
- ✅ **NEW (2025-12-01) - Persistent Model Storage**: PVC mounting enables models to persist across validation runs
- ✅ **NEW (2025-12-01) - Model Sharing**: Multiple notebooks can access shared model repository via PVCs
- ✅ **NEW (2025-12-01) - Training-to-Deployment Pipeline**: Seamless workflow from training to KServe deployment
- ✅ **NEW (2025-12-01) - GPU Support**: Full GPU support for model training notebooks with persistent storage

### Negative Consequences

- ⚠️ **New Operator Dependency**: Additional operator to manage and maintain
- ⚠️ **cert-manager Requirement**: Requires cert-manager v1.13+ installation
- ⚠️ **Migration Effort**: Migrate 30+ notebooks from Tekton to CRDs
- ⚠️ **Learning Curve**: Team needs to learn NotebookValidationJob CRD spec
- ⚠️ **Operator Maintenance**: Custom operator requires version upgrades
- ⚠️ **NEW (2025-12-01) - Storage Management**: Additional PVC management and capacity planning required
- ⚠️ **NEW (2025-12-01) - RBAC Complexity**: Volume access requires additional RBAC configuration

### Migration Strategy

**Phase 1: Operator Deployment (Week 1)**
1. Install cert-manager (if not present)
2. Deploy Jupyter Notebook Validator Operator via Helm
3. Verify operator installation and CRD registration
4. Create test NotebookValidationJob for tier1-simple notebooks

**Phase 2: Tier Migration (Week 2-3)**
1. Migrate tier1-simple notebooks (hello-world, basic operations)
2. Migrate tier2-intermediate notebooks (data collection, preprocessing)
3. Migrate tier3-advanced notebooks (anomaly detection, model training)
4. Keep Tekton infrastructure validation tasks (prerequisites, operators, storage)

**Phase 3: Full Integration (Week 4)**
1. Update Ansible roles (create `validated_patterns_notebooks`)
2. Update documentation (notebooks/README.md, migration guide)
3. Remove Tekton notebook execution tasks (retain infrastructure validation)
4. Deploy production NotebookValidationJobs for all 30 notebooks

## Implementation Tasks

1. ✅ Create ADR-029 (this document)
2. [ ] Update ADR-021 to mark notebook validation as superseded
3. [ ] Create `validated_patterns_notebooks` Ansible role
   - Tasks: Install operator, verify cert-manager, create CRDs
4. [ ] Update `validated_patterns_validate` role
   - Add NotebookValidationJob status checks
   - Remove Tekton notebook execution tasks
5. [ ] Create migration guide (docs/NOTEBOOK-VALIDATION-MIGRATION.md)
6. [ ] Update notebooks/README.md with CRD workflow
7. [ ] Update tekton/README.md to clarify infrastructure-only scope
8. [ ] Create NotebookValidationJob manifests for all 30 notebooks
9. [ ] Test operator deployment on development cluster
10. [ ] Migrate tier1-simple notebooks first (hello-world)
11. [ ] Document rollback procedures

## Related ADRs

### Direct Dependencies
- **ADR-021**: Tekton Pipeline for Post-Deployment Validation (SUPERSEDED for notebook validation)
  - Tekton retains infrastructure validation responsibilities
  - Notebook execution moved to operator-based approach
  - **Relationship**: ADR-029 supersedes notebook validation from ADR-021
- **ADR-019**: Validated Patterns Framework Adoption
  - Operator deployment via Helm and ArgoCD
  - Integration with existing deployment workflows
  - **Relationship**: Operator deployed as part of Validated Patterns framework
- **ADR-026**: Secrets Management Automation
  - Integration with External Secrets Operator for Git credentials
  - **Relationship**: Git credentials managed via External Secrets
- **ADR-011**: Self-Healing Workbench Base Image
  - Validation pods use same container images as workbenches
  - **Relationship**: Shared container image strategy

### Storage and Model Management (NEW - 2025-12-01)
- **ADR-024**: External Secrets for Model Storage
  - **Relationship**: PVC-based model storage complements S3-based storage
  - **Integration**: Models can be stored in PVCs during training, then uploaded to S3 for serving
- **ADR-025**: OpenShift Object Store for Model Serving
  - **Relationship**: PVCs provide local storage, S3 provides serving storage
  - **Workflow**: Train in PVC → Upload to S3 → Serve via KServe
- **ADR-035**: Storage Strategy for Self-Healing Platform
  - **Relationship**: Uses gp3-csi storage class for model PVCs
  - **Integration**: Consistent storage strategy across platform
- **ADR-004**: KServe for Model Serving Infrastructure
  - **Relationship**: Models trained in notebooks with PVCs deployed to KServe
  - **Workflow**: Notebook validation → Model storage → KServe deployment

### Validation and Testing
- **ADR-032**: Infrastructure Validation Notebook for User Readiness
  - **Relationship**: Tier 1 validation notebook executed via this operator
  - **Integration**: Platform readiness validation before notebook execution

## References

- [Jupyter Notebook Validator Operator - Installation Guide](https://raw.githubusercontent.com/tosin2013/jupyter-notebook-validator-operator/refs/heads/release-4.18/helm/jupyter-notebook-validator-operator/INSTALLATION.md)
- [Jupyter Notebook Validator Operator - GitHub Repository](https://github.com/tosin2013/jupyter-notebook-validator-operator)
- [OpenShift cert-manager Documentation](https://docs.openshift.com/container-platform/latest/security/cert_manager_operator/index.html)
- [Validated Patterns Framework](https://validatedpatterns.io/)

## Approval

- **Architecture Team**: Proposed
- **ML Engineering**: Pending Review
- **DevOps Team**: Pending Review
- **Date**: 2025-11-18
