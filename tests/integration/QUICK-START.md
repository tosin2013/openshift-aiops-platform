# E2E Test Quick Start Guide

## TL;DR - Run the Test

```bash
# Quick test (no cleanup after)
make test-deploy-complete-pattern

# Test with cleanup
make test-deploy-complete-pattern CLEANUP_AFTER_TEST=true

# Interactive test (for debugging)
make test-deploy-interactive
```

## What Gets Tested?

✅ **Pre-Test Cleanup**
- Removes old Pattern CRs, ArgoCD Applications, namespaces
- Retains shared infrastructure (GitOps, Gitea, Operator)

✅ **Complete Pattern Deployment** (Development Workflow)
- Prerequisites validation
- Common infrastructure (Helm, ArgoCD, ESO)
- Secrets management
- Cluster-scoped resources (Hybrid Management Model)
- ArgoCD Application creation
- Post-deployment validation

✅ **Health Validation**
- Namespace creation
- ArgoCD Application status
- Pod health
- Cluster-scoped resources
- OpenShift version check

## Quick Commands

```bash
# Run test with script
./tests/integration/scripts/test-deploy-complete-pattern.sh

# Run with options
./tests/integration/scripts/test-deploy-complete-pattern.sh --cleanup-after --debug

# Run with ansible-playbook directly
ANSIBLE_ROLES_PATH=ansible/roles \
ansible-playbook tests/integration/playbooks/test_deploy_complete_pattern.yml

# With cleanup after test
ANSIBLE_ROLES_PATH=ansible/roles \
ansible-playbook tests/integration/playbooks/test_deploy_complete_pattern.yml \
  -e "cleanup_after_test=true"
```

## Prerequisites

- ✅ Connected to OpenShift cluster (`oc login`)
- ✅ Cluster-admin permissions
- ✅ `oc` CLI installed
- ✅ `ansible-playbook` OR `ansible-navigator` installed
- ✅ OpenShift 4.18+ with GitOps operator

## Test Output

Test logs are saved to: `/tmp/e2e-test-YYYYMMDD_HHMMSS.log`

```bash
# View latest log
tail -f $(ls -t /tmp/e2e-test-*.log | head -1)

# Check for errors
grep -i "error\|failed" /tmp/e2e-test-*.log
```

## Expected Results

✅ **Success Indicators**:
- All tasks completed without errors
- Namespace `self-healing-platform` created
- ArgoCD Application exists in `self-healing-platform-hub`
- Pods running in pattern namespace
- Cluster-scoped resources (ClusterRole, ClusterRoleBinding) created

❌ **Common Issues**:
- **Namespace already exists**: Run cleanup first
- **Test hangs**: Check ArgoCD Application sync status
- **Recursive variable error**: Fixed in latest code
- **ESO Helm install fails**: Expected if CRDs already exist (skips automatically)

## Cleanup

```bash
# Standard cleanup (retains GitOps/Gitea/Operator)
ansible-playbook ansible/playbooks/cleanup_pattern.yml

# Full cleanup (removes everything)
ansible-playbook ansible/playbooks/cleanup_pattern.yml \
  -e "cleanup_gitops=true" \
  -e "cleanup_gitea=true" \
  -e "cleanup_operator=true"
```

## Test Standards (per AGENTS.md)

1. ✅ **Always clean up before testing** - Ensures fresh state
2. ✅ **Retain shared infrastructure** - Keep GitOps, Gitea, Operator
3. ✅ **Use Ansible roles** - Reuse validated_patterns_* roles
4. ✅ **Reuse specific task files** - Don't re-run entire roles
5. ✅ **Test in isolation** - Each test independently runnable

## Architecture

The test follows the Validated Patterns framework:

```
Test Flow:
1. Pre-Test Cleanup (validated_patterns_cleanup role)
   └─> Removes Pattern CR, ArgoCD apps, namespaces
   └─> Retains GitOps, Gitea, Operator

2. Deployment (ansible/playbooks/deploy_complete_pattern.yml)
   ├─> validated_patterns_prerequisites
   ├─> validated_patterns_common
   ├─> validated_patterns_secrets
   ├─> validated_patterns_deploy_cluster_resources (Hybrid Model)
   └─> ArgoCD Application creation

3. Validation
   ├─> Namespace check
   ├─> ArgoCD Application status
   ├─> Pod status
   ├─> Cluster resources check
   └─> Health checks (reuse role tasks)

4. Post-Test Cleanup (optional)
   └─> validated_patterns_cleanup role
```

## Files

```
tests/integration/
├── playbooks/
│   └── test_deploy_complete_pattern.yml  # Main test playbook
├── scripts/
│   └── test-deploy-complete-pattern.sh   # Shell wrapper
├── README.md                              # Full documentation
└── QUICK-START.md                         # This file
```

## Reference

- **AGENTS.md**: Testing Strategy → End-to-End Tests
- **ADR-019**: Validated Patterns Framework Adoption
- **.cursorrules**: E2E Testing Best Practices
- **tests/integration/README.md**: Full documentation

## Support

Issues? Check:
1. Test logs: `/tmp/e2e-test-*.log`
2. ArgoCD UI: `oc get route openshift-gitops-server -n openshift-gitops`
3. Application status: `oc get application self-healing-platform -n self-healing-platform-hub -o yaml`
4. Pod status: `oc get pods -n self-healing-platform`

---

**Made with ❤️ following Validated Patterns standards**
