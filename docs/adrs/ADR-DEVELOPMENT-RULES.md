# ADR-DEVELOPMENT-RULES: Development Rules for OpenShift AIOps Platform

**Status:** ACCEPTED
**Date:** 2025-10-31
**Decision Makers:** Architecture Team
**Consulted:** Validated Patterns Community
**Informed:** Development Team

## Purpose

This document establishes development rules and guidelines for the OpenShift AIOps Platform project, ensuring alignment with the Validated Patterns framework and best practices from the validated-patterns-ansible-toolkit reference implementation.

## Core Principles

### 1. Validated Patterns Framework Compliance

All development follows the Validated Patterns OpenShift Framework:
- **GitOps-First**: Use ArgoCD for declarative deployments
- **Helm + Kustomize**: Combine Helm for templating with Kustomize for customization
- **Idempotency**: All operations must be safely repeatable
- **Multi-Cluster Ready**: Support hub-spoke topology via Advanced Cluster Management

### 2. Ansible Role Architecture

The project uses 8 production-ready Ansible roles (from validated-patterns-ansible-toolkit):

1. **validated_patterns_prerequisites** - Cluster validation (OpenShift version, operators, resources, RBAC, storage, network)
2. **validated_patterns_common** - Helm/GitOps infrastructure (Helm install, ArgoCD, clustergroup chart)
3. **validated_patterns_operator** - Simplified end-user deployment via VP Operator
4. **validated_patterns_deploy** - Application deployment via ArgoCD and BuildConfigs
5. **validated_patterns_gitea** - Local git repository for development environments
6. **validated_patterns_secrets** - Secrets management (sealed secrets, credentials, validation)
7. **validated_patterns_validate** - Comprehensive pre/post-deployment validation and health checks
8. **validated_patterns_cleanup** - Resource cleanup (Pattern CRs, ArgoCD apps, namespaces)

### 3. Role Task Modularity

Each role uses `include_tasks` for modular, reusable task files:

```yaml
# Good: Reuse specific validation task in E2E tests
- include_tasks: ../../ansible/roles/validated_patterns_prerequisites/tasks/check_openshift_version.yml

# Avoid: Re-running entire role when only one check needed
- include_role:
    name: validated_patterns_prerequisites  # Runs ALL checks unnecessarily
```

## E2E Testing Best Practices

### Mandatory Cleanup Before Testing

**CRITICAL**: Always clean up before running e2e tests to ensure fresh state and avoid conflicts.

```yaml
# E2E Test Template
- name: E2E Test with Role-Based Approach
  hosts: localhost
  tasks:
    # 1. Pre-test cleanup using role (MANDATORY)
    - include_role:
        name: validated_patterns_cleanup
      # Default behavior retains shared infrastructure:
      # cleanup_gitops: false   # Keep ArgoCD (from common/ subtree)
      # cleanup_gitea: false    # Keep Gitea (for development)
      # cleanup_operator: false # Keep operator (reusable)

    # 2. Deploy using role
    - include_role:
        name: validated_patterns_operator

    # 3. Validate using specific task files (not entire roles)
    - include_tasks: ../../ansible/roles/validated_patterns_validate/tasks/validate_health.yml

    # 4. Post-test cleanup using role
    - include_role:
        name: validated_patterns_cleanup
```

### Why Retain Infrastructure?

- **GitOps/ArgoCD**: Deployed by `common/` subtree and shared across patterns
- **Gitea**: Provides local git repositories for development
- **VP Operator**: Can manage multiple pattern deployments
- **Efficiency**: Faster test iterations without reinstallation

### Resources to Clean (Checklist)

- ✅ Pattern Custom Resources (`oc get pattern -A`) — **ALWAYS**
- ✅ ArgoCD Applications (`oc get applications -n openshift-gitops`) — **ALWAYS**
- ✅ Application namespaces (self-healing-platform, etc.) — **ALWAYS**
- ✅ ConfigMaps and Secrets created by patterns — **ALWAYS**
- ✅ BuildConfigs and ImageStreams (if testing builds) — **ALWAYS**
- ✅ Routes and Services (application-specific) — **ALWAYS**
- ⚠️ OpenShift GitOps namespace — **RARELY** (only if common/ subtree requires redeployment)
- ⚠️ Gitea namespace — **RARELY** (only if starting completely fresh)
- ⚠️ Subscriptions and CSVs — **RARELY** (only if testing operator installation itself)

## Common Subtree Management (CRITICAL)

The `common/` directory is a **git subtree** imported from [validatedpatterns/common.git](https://github.com/validatedpatterns/common.git).

**⚠️ IMPORTANT**: This repository updates frequently. Keep in sync before major development work.

### Update Procedure

```bash
# Option 1: Using utilities script (recommended)
curl -s https://raw.githubusercontent.com/validatedpatterns/utilities/main/scripts/update-common-everywhere.sh | bash

# Option 2: Manual update
git remote add -f common-upstream https://github.com/validatedpatterns/common.git
git merge -s subtree -Xtheirs -Xsubtree=common common-upstream/main
```

### When to Update

- ✅ Before starting new feature development
- ✅ Before running comprehensive e2e tests
- ✅ When pattern deployment fails with unknown errors
- ✅ When upstream releases new features/fixes
- ✅ Monthly or before major releases

## Deployment Workflows

### Development Workflow (Granular Control)

**Audience**: Pattern developers, maintainers, advanced users

Uses roles 1-2, 4-7 for step-by-step deployment with full control:

```bash
ansible-playbook ansible/playbooks/deploy_complete_pattern.yml
```

**Best for**:
- Pattern development and customization
- Debugging deployment issues
- Learning the framework
- Advanced infrastructure modifications

### End-User Workflow (Simplified) - **RECOMMENDED FOR END USERS**

**Audience**: End users, production deployments, operations teams

Uses role 3 (VP Operator) for simplified, one-command deployment:

```bash
make -f common/Makefile operator-deploy
```

**Key Benefits for End Users**:
- ✅ Single command deployment
- ✅ Automatic prerequisite validation
- ✅ Built-in error handling and recovery
- ✅ No need to understand Ansible roles
- ✅ Consistent, repeatable deployments
- ✅ Production-ready with health checks

**End-User Deployment Steps**:
1. Clone the repository
2. Configure `values-hub.yaml` with environment-specific settings
3. Create `values-secret.yaml` from template with credentials
4. Run: `make -f common/Makefile operator-deploy`
5. Validate: `make -f common/Makefile argo-healthcheck`
6. Run post-deployment validation: Tekton pipeline (see ADR-021)

## Commit & Pull Request Guidelines

- **Commits**: Short, imperative subject; include scope. Examples: `feat(ansible): add validation role`, `docs: clarify deployment steps`
- **PRs**: Include description, rationale, sample commands, and `make test` output
- **Before PR**: Ensure `common/` is up-to-date, run cleanup, then `make lint build test`
- **Role changes**: Update role `README.md` and relevant documentation

## Security Requirements

- **Never commit secrets**: Use environment variables and external secret management
- **Use validated_patterns_secrets role**: Supports Vault and Kubernetes backends
- **Secrets management**: Use External Secrets Operator for production deployments
- **Container security**: Use minimal base images, scan for vulnerabilities, run as non-root

## References

- [Validated Patterns OpenShift Framework](https://validatedpatterns.io/learn/vp_openshift_framework/)
- [validated-patterns-ansible-toolkit](https://github.com/tosin2013/validated-patterns-ansible-toolkit)
- [Validated Patterns Common Repository](https://github.com/validatedpatterns/common)
- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/index.html)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

## Related ADRs

- **ADR-019**: Validated Patterns Framework Adoption
- **ADR-020**: Bootstrap Deployment and Deletion Lifecycle
- **ADR-014**: OpenShift AIOps Platform MCP Server Integration

## Approval

- **Architecture Team**: Approved
- **Date**: 2025-10-31
