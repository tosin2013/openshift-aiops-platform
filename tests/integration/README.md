# Integration Tests

End-to-end integration tests for the OpenShift AI Ops Self-Healing Platform.

## Overview

This directory contains integration tests following the Validated Patterns framework guidelines from `AGENTS.md`. Tests use Ansible roles for consistent, reusable deployment and cleanup procedures.

## Test Structure

```
tests/integration/
├── playbooks/              # Ansible playbooks for E2E tests
│   └── test_deploy_complete_pattern.yml
├── scripts/                # Shell script wrappers
│   └── test-deploy-complete-pattern.sh
└── README.md              # This file
```

## Available Tests

### 1. Complete Pattern Deployment Test (Development Workflow)

**Purpose**: Test the complete pattern deployment using the development workflow (`ansible/playbooks/deploy_complete_pattern.yml`)

**Playbook**: `playbooks/test_deploy_complete_pattern.yml`

**Script**: `scripts/test-deploy-complete-pattern.sh`

**What It Tests**:
- ✅ Pre-test cleanup (retains shared infrastructure)
- ✅ Complete pattern deployment (development workflow)
- ✅ Prerequisites validation
- ✅ Common infrastructure deployment (Helm, ArgoCD, ESO)
- ✅ Secrets management configuration
- ✅ Cluster-scoped resources deployment (Hybrid Management Model)
- ✅ ArgoCD Application creation
- ✅ Post-deployment validation
- ✅ Health checks
- ✅ Optional post-test cleanup

## Running Tests

### Option 1: Using Shell Script (Recommended)

```bash
# Run with default settings
./tests/integration/scripts/test-deploy-complete-pattern.sh

# Run with cleanup after test
./tests/integration/scripts/test-deploy-complete-pattern.sh --cleanup-after

# Run in interactive mode with debug
./tests/integration/scripts/test-deploy-complete-pattern.sh --mode interactive --debug

# Run with Docker instead of Podman
./tests/integration/scripts/test-deploy-complete-pattern.sh --container-engine docker
```

### Option 2: Using Ansible Playbook Directly

```bash
# Using ansible-navigator (with execution environment)
ansible-navigator run tests/integration/playbooks/test_deploy_complete_pattern.yml \
  --container-engine podman \
  --execution-environment-image openshift-aiops-platform-ee:latest \
  --mode stdout

# Using ansible-playbook (direct execution)
ANSIBLE_ROLES_PATH=ansible/roles \
ansible-playbook tests/integration/playbooks/test_deploy_complete_pattern.yml

# With cleanup after test
ANSIBLE_ROLES_PATH=ansible/roles \
ansible-playbook tests/integration/playbooks/test_deploy_complete_pattern.yml \
  -e "cleanup_after_test=true"
```

### Option 3: Using Make Target

```bash
# From project root
make test-deploy-complete-pattern

# With cleanup after test
make test-deploy-complete-pattern CLEANUP_AFTER_TEST=true
```

## Test Workflow

The test follows this sequence:

1. **Pre-Test Cleanup** (MANDATORY)
   - Removes old Pattern CRs
   - Removes ArgoCD Applications
   - Removes application namespaces
   - Retains shared infrastructure (GitOps, Gitea, Operator)

2. **Deployment** (Development Workflow)
   - Validates cluster prerequisites
   - Deploys common infrastructure (Helm, ArgoCD, ESO)
   - Configures secrets management
   - Deploys cluster-scoped resources (Hybrid Management Model)
   - Creates ArgoCD Application
   - Validates deployment

3. **Validation**
   - Checks namespace existence
   - Verifies ArgoCD Application status
   - Validates pod status
   - Confirms cluster-scoped resources
   - Executes health checks

4. **Post-Test Cleanup** (Optional)
   - Removes test resources
   - Retains shared infrastructure (unless specified)

## Test Configuration

### Environment Variables

```bash
# Container engine
export CONTAINER_ENGINE=podman  # or docker

# Ansible navigator mode
export MODE=stdout  # or interactive

# Enable cleanup after test
export CLEANUP_AFTER_TEST=true  # default: false

# Enable debug mode
export DEBUG=true  # default: false

# Kubeconfig path
export KUBECONFIG=/path/to/kubeconfig
```

### Playbook Variables

Override these in the test playbook or via `-e` flag:

```yaml
# Pattern configuration
pattern_name: "self-healing-platform"
pattern_namespace: "self-healing-platform"
test_timeout: 1800  # 30 minutes

# Cleanup configuration
cleanup_gitops: false      # Keep ArgoCD (default)
cleanup_gitea: false        # Keep Gitea (default)
cleanup_operator: false     # Keep VP Operator (default)
cleanup_after_test: false   # Skip post-test cleanup (default)

# Deployment configuration
enable_operator: false      # Use development workflow (default)
enable_gitea: false
enable_secrets_mgmt: true
enable_validation: true
```

## Prerequisites

### Required Tools

- `oc` CLI (OpenShift)
- `ansible-playbook` OR `ansible-navigator`
- `kubectl` (optional)
- `podman` or `docker` (for ansible-navigator)

### Required Access

- Cluster-admin permissions on OpenShift cluster
- Active connection to OpenShift cluster (`oc login`)
- KUBECONFIG properly configured

### Cluster Requirements

- OpenShift 4.18+ cluster
- OpenShift GitOps operator installed
- OpenShift Pipelines operator installed (optional)
- Red Hat OpenShift AI operator installed
- Sufficient resources (6+ nodes, 24+ CPU, 96+ GB RAM)

## Test Output

### Success Indicators

- ✅ All tasks completed without errors
- ✅ Namespace created and healthy
- ✅ ArgoCD Application exists and syncing
- ✅ Pods running in pattern namespace
- ✅ Cluster-scoped resources deployed
- ✅ Validation checks passed

### Logs

Test logs are saved to `/tmp/e2e-test-YYYYMMDD_HHMMSS.log`

```bash
# View latest test log
tail -f /tmp/e2e-test-*.log | sort | tail -1

# Search for errors
grep -i "error\|failed" /tmp/e2e-test-*.log
```

## Cleanup

### Manual Cleanup (if needed)

```bash
# Standard cleanup (retains GitOps/Gitea/Operator)
ansible-playbook ansible/playbooks/cleanup_pattern.yml

# Full cleanup (removes everything)
ansible-playbook ansible/playbooks/cleanup_pattern.yml \
  -e "cleanup_gitops=true" \
  -e "cleanup_gitea=true" \
  -e "cleanup_operator=true"

# Or use the cleanup role directly
ansible-playbook -e "cleanup_pattern_name=self-healing-platform" -e "cleanup_pattern_namespace=self-healing-platform" -e "cleanup_gitops=false" -e "cleanup_gitea=false" -e "cleanup_operator=false" -c local -i localhost, ansible/roles/validated_patterns_cleanup/tasks/main.yml
```

### Using Cleanup Script

```bash
# Standard cleanup
./tests/integration/scripts/cleanup.sh

# Full cleanup
./tests/integration/scripts/cleanup.sh --full
```

## Troubleshooting

### Test Hangs During Deployment

**Cause**: ArgoCD Application waiting for sync or health check

**Solution**: Check ArgoCD Application status
```bash
oc get application self-healing-platform -n self-healing-platform-hub -o yaml
oc logs -n self-healing-platform-hub deployment/hub-gitops-repo-server
```

### Namespace Already Exists

**Cause**: Previous test cleanup incomplete

**Solution**: Run cleanup manually
```bash
ansible-playbook ansible/playbooks/cleanup_pattern.yml
```

### Recursive Variable Error

**Cause**: Variable passed to role that's already defined at playbook level

**Solution**: Remove redundant variable pass-through in playbook

### External Secrets Operator Fails

**Cause**: CRDs already exist from previous installation

**Solution**: ESO deployment will skip Helm install if CRDs exist (expected behavior)

## Best Practices

### From AGENTS.md

1. **Always clean up before testing** - Ensures fresh state and avoids conflicts
2. **Retain shared infrastructure** - Keep GitOps, Gitea, and Operator for efficiency
3. **Use Ansible roles** - Reuse `validated_patterns_cleanup` and deployment roles
4. **Reuse specific task files** - Don't re-run entire roles unnecessarily
5. **Test in isolation** - Each e2e test should be independently runnable

### Test Development Guidelines

1. **Follow role-based pattern** - Use existing roles, don't write custom deployment logic
2. **Include cleanup steps** - Always cleanup before and optionally after tests
3. **Add validation checks** - Verify deployment health and correctness
4. **Document test purpose** - Clear description of what is being tested
5. **Use tags** - Allow running specific test sections

## References

- **AGENTS.md**: Testing Strategy → End-to-End Tests (Ansible-based)
- **ADR-019**: Validated Patterns Framework Adoption
- **docs/E2E-DEPLOYMENT-CLEANUP-GUIDE.md**: Complete deployment and cleanup guide
- **my-pattern/AGENTS.md**: Validated Patterns Ansible Toolkit (reference only)

## Contributing

When adding new tests:

1. Follow the existing test pattern structure
2. Use `validated_patterns_cleanup` role for pre/post cleanup
3. Reuse existing Ansible roles for deployment
4. Include validation checks
5. Add documentation to this README
6. Test with both `ansible-playbook` and `ansible-navigator`

## Support

For issues or questions:
- Review AGENTS.md testing guidelines
- Check ADR-019 for framework details
- Review test logs in `/tmp/e2e-test-*.log`
- Check ArgoCD UI for application status
