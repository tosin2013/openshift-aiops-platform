# Validated Patterns - Deploy Cluster Resources Role

## Purpose

This Ansible role deploys cluster-scoped resources (ClusterRole, ClusterRoleBinding, ClusterServingRuntime) separately from namespaced resources. This supports **Pattern 3: Hybrid Management Model** for namespaced ArgoCD deployments.

## Architecture

**Hybrid Management Model**:
- **Cluster-scoped resources**: Deployed via this Ansible role (outside ArgoCD)
- **Namespaced resources**: Deployed via ArgoCD with `rbac.clusterScoped.enabled=false`

This separation allows:
- Namespaced ArgoCD to manage application resources
- Cluster-scoped resources to be deployed independently
- Proper security boundaries and GitOps principles

## Usage

### Basic Usage

```yaml
- name: Deploy cluster-scoped resources
  include_role:
    name: validated_patterns_deploy_cluster_resources
  vars:
    pattern_namespace: self-healing-platform
    deploy_cluster_resources: true
```

### With Custom Configuration

```yaml
- name: Deploy cluster-scoped resources
  include_role:
    name: validated_patterns_deploy_cluster_resources
  vars:
    pattern_namespace: self-healing-platform
    deploy_cluster_resources: true
    cluster_rbac:
      enabled: true
      external_secrets:
        enabled: true
      operator:
        enabled: true
      workbench:
        enabled: true
    kserve:
      enabled: true
```

## Variables

See `defaults/main.yml` for complete variable documentation.

### Key Variables

- `deploy_cluster_resources`: Enable/disable cluster resource deployment (default: `true`)
- `pattern_namespace`: Target namespace for resources (default: `self-healing-platform`)
- `cluster_rbac.enabled`: Enable RBAC cluster resources (default: `true`)
- `kserve.enabled`: Enable KServe ClusterServingRuntime resources (default: `true`)

## Resources Deployed

### RBAC Resources

1. **External Secrets Operator**:
   - ClusterRole: `external-secrets-{{ pattern_namespace }}`
   - ClusterRoleBinding: `external-secrets-{{ pattern_namespace }}`

2. **Self-Healing Operator**:
   - ClusterRole: `self-healing-operator-cluster`
   - ClusterRoleBinding: `self-healing-operator-cluster`

3. **Workbench**:
   - ClusterRole: `self-healing-workbench-cluster`
   - ClusterRoleBinding: `self-healing-workbench-cluster`
   - ClusterRoleBinding: `self-healing-workbench-prometheus`

4. **ArgoCD**:
   - ClusterRole: `self-healing-platform-argocd-hub`
   - ClusterRoleBinding: `self-healing-platform-argocd-hub`

### KServe Resources

- ClusterServingRuntime resources (if defined in Helm chart)

## Dependencies

- `kubernetes.core` Ansible collection
- Helm CLI (for extracting resources from charts)
- Valid KUBECONFIG or cluster access

## Example Playbook

```yaml
---
- name: Deploy Self-Healing Platform Cluster Resources
  hosts: localhost
  tasks:
    - name: Deploy cluster-scoped resources
      include_role:
        name: validated_patterns_deploy_cluster_resources
      vars:
        pattern_namespace: self-healing-platform
        deploy_cluster_resources: true
```

## Related Roles

- `validated_patterns_deploy`: Deploys namespaced resources via ArgoCD
- `validated_patterns_prerequisites`: Validates cluster readiness

## References

- [ADR-002: Hybrid Deterministic-AI Self-Healing Approach](docs/adrs/002-hybrid-self-healing-approach.md)
- [Research: ArgoCD Namespace Management Validation](docs/research/argocd-namespace-management-validation-research.md)
