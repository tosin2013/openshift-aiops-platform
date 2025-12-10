# Pattern CR Best Practices for Self-Healing Platform

## Overview

This guide documents best practices for working with Pattern Custom Resources (CRs) when deploying the OpenShift AI Ops Self-Healing Platform using the Validated Patterns framework.

## Table of Contents

- [Pattern CR Anatomy](#pattern-cr-anatomy)
- [Git Repository Configuration](#git-repository-configuration)
- [Values File Hierarchy](#values-file-hierarchy)
- [Sync Policies](#sync-policies)
- [Deployment Strategies](#deployment-strategies)
- [Multi-Cluster Considerations](#multi-cluster-considerations)
- [Troubleshooting](#troubleshooting)

---

## Pattern CR Anatomy

### What is a Pattern CR?

A Pattern Custom Resource (`kind: Pattern`) is the declarative specification that tells the Validated Patterns Operator how to deploy your platform. It's created from your `values-*.yaml` files using Helm templating.

### Key Components

```yaml
apiVersion: gitops.hybrid-cloud-patterns.io/v1alpha1
kind: Pattern
metadata:
  name: self-healing-platform
  namespace: openshift-operators
spec:
  # Git configuration
  gitConfig:
    targetRepo: https://github.com/org/repo.git
    targetRevision: main

  # Cluster configuration
  clusterGroupName: hub

  # GitOps operator configuration
  gitOpsSpec:
    operatorChannel: stable
    operatorSource: redhat-operators
```

### Pattern CR Lifecycle

1. **Creation**: Operator creates the Pattern CR
2. **Processing**: Operator installs OpenShift GitOps (ArgoCD)
3. **Deployment**: Operator creates clustergroup ArgoCD Application
4. **Sync**: ArgoCD syncs all pattern applications
5. **Health**: Operator monitors application health

---

## Git Repository Configuration

### Gitea vs. GitHub

**Gitea (Development/Air-gapped)**:
```yaml
git:
  repoURL: "https://gitea-with-admin-gitea.apps.cluster-abc123.example.com/my-org/repo.git"
```

**Advantages**:
- ✅ Local to cluster - no internet dependency
- ✅ Fast deployment
- ✅ Air-gapped environment support
- ✅ Development iteration speed

**GitHub (Production/Cloud)**:
```yaml
git:
  repoURL: "https://github.com/openshift-aiops/openshift-aiops-platform.git"
```

**Advantages**:
- ✅ Production-ready
- ✅ CI/CD integration
- ✅ Version control best practices
- ✅ Team collaboration

### Git Credentials Management

**Best Practice**: Use External Secrets Operator to inject Git credentials

```yaml
# values-secret.yaml (NOT committed to git)
git:
  credentials:
    username: "my-user"
    password: "ghp_..." # GitHub PAT

# External Secret will create: git-credentials secret
```

### Branch Strategy

**Development**:
```yaml
git:
  revision: "feature/new-notebook"
```

**Production**:
```yaml
git:
  revision: "main" # or "v1.0.0" for tagged releases
```

---

## Values File Hierarchy

### Precedence Order

When multiple values files are used, later files override earlier ones:

1. `values-global.yaml` - Global configuration (lowest priority)
2. `values-hub.yaml` - Hub cluster specific
3. `values-secret.yaml` - Secrets (highest priority, not committed)

### What Goes Where?

**values-global.yaml**:
- Pattern name and version
- Git repository configuration
- Global feature flags
- Shared storage configuration
- Common resource limits

**values-hub.yaml**:
- Cluster-specific applications
- ArgoCD application definitions
- Operator subscriptions
- Namespace configurations
- Cluster-specific resource requirements

**values-secret.yaml**:
- Git credentials
- S3 access keys
- API tokens
- Passwords
- **⚠️ NEVER commit this to git!**

### Template vs. Example Files

**Pattern Repository Structure**:
```
/
├── values-global.yaml.template    # Template with placeholders
├── values-global.yaml.example     # Example with sample values
├── values-global.yaml             # Active (gitignored if cluster-specific)
├── values-hub.yaml.template
├── values-hub.yaml.example
├── values-hub.yaml
├── values-secret.yaml.template
└── values-secret.yaml             # ⚠️ NEVER commit (in .gitignore)
```

---

## Sync Policies

### Automated vs. Manual Sync

**Automated Sync (Recommended for Production)**:
```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources not in git
    selfHeal: true   # Revert manual changes
```

**Advantages**:
- ✅ GitOps compliant
- ✅ Self-healing
- ✅ Consistent state
- ✅ No drift

**Manual Sync (Development)**:
```yaml
syncPolicy:
  automated: {}  # Empty = manual sync required
```

**Use Cases**:
- Development/testing
- Debugging deployment issues
- Staged rollouts

### Sync Options

**CreateNamespace**:
```yaml
syncOptions:
  - CreateNamespace=true
```
- Automatically create namespaces if they don't exist
- **Caution**: May not include all required labels/annotations

**ServerSideApply**:
```yaml
syncOptions:
  - ServerSideApply=true
```
- Use server-side apply for better conflict resolution
- **Recommended** for CRDs and large resources

**Validate**:
```yaml
syncOptions:
  - Validate=false
```
- Skip kubectl validation
- **Use sparingly** - only for resources with validation issues

### Retry Policy

**Recommended Configuration**:
```yaml
retry:
  limit: 5
  backoff:
    duration: 5s
    factor: 2
    maxDuration: 3m
```

**Explanation**:
- Retry up to 5 times on sync failure
- Exponential backoff: 5s, 10s, 20s, 40s, 80s (capped at 3m)

### Ignore Differences

**Common Ignores**:
```yaml
ignoreDifferences:
  # Ignore kube-controller-manager managed fields
  - group: "*"
    kind: "*"
    managedFieldsManagers:
      - kube-controller-manager

  # Ignore External Secret status (changes frequently)
  - group: external-secrets.io
    kind: ExternalSecret
    jqPathExpressions:
      - .status

  # Ignore PVC status
  - kind: PersistentVolumeClaim
    jqPathExpressions:
      - .status

  # Ignore InferenceService status
  - group: serving.kserve.io
    kind: InferenceService
    jqPathExpressions:
      - .status
```

---

## Deployment Strategies

### Initial Deployment

**Recommended Workflow**:

1. **Configure Values**:
   ```bash
   ./scripts/configure-cluster-values.sh
   ```

2. **Preview Pattern CR**:
   ```bash
   ./scripts/preview-pattern-cr.sh
   ```

3. **Validate Prerequisites**:
   ```bash
   ansible-playbook ansible/playbooks/validate_new_cluster.yml
   ```

4. **Deploy**:
   ```bash
   make -f common/Makefile operator-deploy
   ```

5. **Monitor**:
   ```bash
   make -f common/Makefile argo-healthcheck
   oc get pattern -n openshift-operators --watch
   ```

### Phased Rollout

For large deployments, use ArgoCD Sync Waves:

```yaml
# Tier 1: Infrastructure (Wave 0-10)
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "5"

# Tier 2: Platform Services (Wave 10-20)
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "15"

# Tier 3: Applications (Wave 20-30)
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "25"
```

### Update Strategy

**Git-Based Updates**:
```bash
# Make changes to values files or charts
git commit -m "Update: increase coordination engine replicas"
git push

# ArgoCD automatically syncs (if automated policy enabled)
# Or manually sync:
argocd app sync self-healing-platform
```

**Rollback**:
```bash
# Via Git
git revert <commit-hash>
git push

# Via ArgoCD UI
# Navigate to app → History → Select previous revision → Rollback
```

---

## Multi-Cluster Considerations

### Hub vs. Managed Clusters

**Hub Cluster** (values-hub.yaml):
- OpenShift GitOps (ArgoCD)
- Pattern operator
- Centralized monitoring
- GitOps control plane

**Managed Cluster** (values-managed.yaml):
- Deployed via ACM
- Local applications
- Reports to hub
- Receives policies from hub

### Advanced Cluster Management (ACM) Integration

**Prerequisite**: ACM operator installed on hub

**Pattern Configuration**:
```yaml
# values-global.yaml
main:
  components:
    acm: true

# values-hub.yaml
clusterGroup:
  managedClusterGroups:
    - name: production
      helmOverrides:
        - replicas: 3
        - environment: production
```

---

## Troubleshooting

### Pattern CR Not Syncing

**Check Pattern CR Status**:
```bash
oc get pattern -n openshift-operators
oc describe pattern self-healing-platform -n openshift-operators
```

**Common Issues**:
- Git repository not accessible
- Helm chart errors
- Missing CRDs
- Resource conflicts

**Solution**:
```bash
# Check operator logs
oc logs -n openshift-operators -l control-plane=patterns-operator

# Verify git connectivity
curl -I https://github.com/org/repo.git

# Recreate Pattern CR
oc delete pattern self-healing-platform -n openshift-operators
make -f common/Makefile operator-deploy
```

### ArgoCD Application OutOfSync

**Check Application Status**:
```bash
argocd app get self-healing-platform
argocd app sync self-healing-platform --dry-run
```

**Force Sync**:
```bash
# With prune
argocd app sync self-healing-platform --prune

# Replace resources
argocd app sync self-healing-platform --force
```

### Git Credential Issues

**Check Secret**:
```bash
oc get secret git-credentials -n self-healing-platform -o yaml
```

**Recreate Credentials**:
```bash
# Via External Secrets Operator
oc delete externalsecret git-credentials -n self-healing-platform
# ESO will recreate from backend (Vault, AWS Secrets Manager, etc.)

# Or manually
oc create secret generic git-credentials \
  --from-literal=username=my-user \
  --from-literal=password=ghp_token \
  -n self-healing-platform
```

### Values File Merge Issues

**Verify Merged Values**:
```bash
# Preview final merged values
./scripts/preview-pattern-cr.sh | yq eval '.'

# Check specific value
yq eval '.git.repoURL' values-global.yaml
yq eval '.clusterGroup.applications.self-healing-platform.repoURL' values-hub.yaml
```

**Common Mistakes**:
- Conflicting values between files
- Incorrect YAML indentation
- Missing quotes around URLs

---

## Best Practices Checklist

### Before Deployment

- [ ] Run `./scripts/configure-cluster-values.sh` to generate customized values
- [ ] Review `./scripts/preview-pattern-cr.sh` output
- [ ] Validate cluster with `ansible-playbook ansible/playbooks/validate_new_cluster.yml`
- [ ] Ensure `values-secret.yaml` contains real credentials
- [ ] Verify `values-secret.yaml` is in `.gitignore`
- [ ] Test git repository accessibility
- [ ] Confirm OpenShift version compatibility (4.18+)

### During Deployment

- [ ] Monitor Pattern CR status: `oc get pattern --watch`
- [ ] Watch ArgoCD application sync: `make argo-healthcheck`
- [ ] Check for sync errors in ArgoCD UI
- [ ] Verify all applications reach "Healthy" status
- [ ] Review operator logs for warnings

### After Deployment

- [ ] Run post-deployment validation: `tkn pipeline start deployment-validation-pipeline`
- [ ] Test application endpoints
- [ ] Verify notebook validation jobs complete
- [ ] Check model serving endpoints
- [ ] Validate coordination engine health
- [ ] Set up monitoring alerts

---

## Additional Resources

- [ADR-019: Validated Patterns Framework Adoption](../adrs/019-validated-patterns-framework-adoption.md)
- [ADR-030: Hybrid Management Model for Namespaced ArgoCD](../adrs/030-hybrid-management-model-namespaced-argocd.md)
- [Validated Patterns Official Documentation](https://validatedpatterns.io/)
- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

---

**Last Updated**: 2025-12-05
**Authors**: Platform Team
**Confidence**: 95%
