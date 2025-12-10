# validated_patterns_cleanup

Cleans up Validated Patterns deployments including Pattern CRs, ArgoCD applications, and application namespaces.

## Purpose

This role performs comprehensive cleanup:

- Delete ArgoCD Applications
- Delete Pattern Custom Resources
- Delete application namespaces
- (Optional) Delete GitOps namespace (removes ArgoCD)
- (Optional) Uninstall Validated Patterns Operator

## Requirements

- Ansible 2.12+
- kubernetes.core collection
- OpenShift cluster access
- kubeconfig configured

## Role Variables

```yaml
# Pattern name to clean up
cleanup_pattern_name: "validated-patterns-ansible-toolkit"

# Namespace where Pattern CR and operator are installed
cleanup_operator_namespace: "openshift-operators"

# GitOps namespace where ArgoCD is installed
cleanup_gitops_namespace: "openshift-gitops"

# Application namespaces to delete
cleanup_app_namespaces:
  - validated-patterns
  - quarkus-app-dev
  - quarkus-app-prod

# Wait timeout for resource deletion (seconds)
cleanup_wait_timeout: 300

# Optional: Delete GitOps namespace (removes ArgoCD completely)
# NOTE: Usually FALSE - GitOps is typically deployed by common/ subtree
cleanup_gitops: false

# Optional: Delete Gitea namespace (removes local git repository)
# NOTE: Usually FALSE - Gitea is used for local development
cleanup_gitea: false
cleanup_gitea_namespace: "gitea"

# Optional: Uninstall Validated Patterns Operator
# NOTE: Usually FALSE - Operator can be reused across deployments
cleanup_operator: false
```

## Usage

### Basic Cleanup (applications and namespaces only - RECOMMENDED)

This is the most common use case for iterative testing and development. It cleans up pattern-specific resources while retaining shared infrastructure (GitOps, Gitea, Operator).

```yaml
- name: Clean up Validated Patterns deployment
  hosts: localhost
  gather_facts: no
  roles:
    - validated_patterns_cleanup
```

### Full Cleanup (including GitOps, Gitea, and Operator)

```yaml
- name: Full cleanup of Validated Patterns
  hosts: localhost
  gather_facts: no
  vars:
    cleanup_gitops: true    # ⚠️  Removes ArgoCD (deployed by common/ subtree)
    cleanup_gitea: true     # ⚠️  Removes local git repository
    cleanup_operator: true  # ⚠️  Removes VP Operator
  roles:
    - validated_patterns_cleanup
```

**⚠️ WARNING**: Full cleanup removes shared infrastructure. Only use when:
- Starting completely fresh (no other patterns active)
- Cleaning up after final testing
- Common subtree changes require GitOps redeployment

### Custom Pattern Name

```yaml
- name: Clean up custom pattern
  hosts: localhost
  gather_facts: no
  vars:
    cleanup_pattern_name: "my-custom-pattern"
    cleanup_app_namespaces:
      - my-app-dev
      - my-app-prod
  roles:
    - validated_patterns_cleanup
```

### E2E Testing Cleanup (RECOMMENDED PATTERN)

For iterative e2e testing, retain shared infrastructure:

```yaml
# Before running E2E tests (default behavior)
- name: Pre-test cleanup
  hosts: localhost
  tasks:
    - include_role:
        name: validated_patterns_cleanup
      # Default vars already set to retain infrastructure:
      # cleanup_gitops: false   # Keep ArgoCD (from common/ subtree)
      # cleanup_gitea: false    # Keep Gitea (for development)
      # cleanup_operator: false # Keep operator (reusable)
```

This ensures:
- ✅ Pattern-specific resources are cleaned (CRs, apps, namespaces)
- ✅ Shared infrastructure is retained (GitOps, Gitea, Operator)
- ✅ Faster test iterations (no reinstallation needed)
- ✅ Consistent with common/ subtree architecture

## Architecture Context

This role is designed to work with the **Validated Patterns common subtree architecture**:

- **common/** is imported from [validatedpatterns/common.git](https://github.com/validatedpatterns/common.git)
- **GitOps (ArgoCD)** is deployed by the common subtree and shared across patterns
- **Gitea** provides local git repositories for development and is reusable
- **VP Operator** can manage multiple pattern deployments

**Design Philosophy**:
- Pattern-specific resources (CRs, apps, namespaces) should be cleaned between tests
- Shared infrastructure (GitOps, Gitea, Operator) should be retained for efficiency
- Full cleanup only when starting completely fresh or after final testing

## Task Files (Reusable)

Individual cleanup tasks can be reused:

- `cleanup_argocd_applications.yml` - Delete all ArgoCD applications
- `cleanup_pattern_cr.yml` - Delete Pattern Custom Resource
- `cleanup_namespaces.yml` - Delete application namespaces
- `cleanup_gitops.yml` - Delete GitOps namespace (⚠️ optional, rarely used)
- `cleanup_gitea.yml` - Delete Gitea namespace (⚠️ optional, rarely used)
- `cleanup_operator.yml` - Uninstall VP Operator (⚠️ optional, rarely used)

Example:
```yaml
- name: Only cleanup Pattern CR
  include_tasks: ../../ansible/roles/validated_patterns_cleanup/tasks/cleanup_pattern_cr.yml
```

## Verification

After cleanup, verify with:

```bash
# Check Pattern CRs
oc get pattern -A

# Check ArgoCD applications
oc get applications -n openshift-gitops

# Check namespaces
oc get namespaces | grep -E 'validated-patterns|quarkus-app'

# Check operator
oc get csv -n openshift-operators | grep patterns-operator
```

## License

Apache 2.0
