# Cleanup Instructions for Junior Developer

## Issue: Extra Namespaces Created During Deployment

You have two extra namespaces that were created by the upstream Validated Patterns framework:
- `self-healing-platform-example` (with `example-gitops` ArgoCD instance)
- `imperative` (with Vault unsealing cronjob)

These are **safe to delete** and do NOT affect your deployment.

## Root Cause

The upstream `clustergroup:0.9.*` chart has default values that create these resources. This was fixed in the main repository by updating the `common/` subtree.

## Instructions for Your Fork: `/home/lab-user/openshift-aiops-platform-deployment-testing`

### Option 1: Quick Cleanup (Immediate Fix)

```bash
cd /home/lab-user/openshift-aiops-platform-deployment-testing

# Delete the extra namespaces
oc delete namespace self-healing-platform-example imperative --ignore-not-found=true

# Verify cleanup
oc get namespaces | grep self-healing
# Should only show:
# self-healing-platform           Active   <time>
# self-healing-platform-hub       Active   <time>
```

### Option 2: Update Your Fork (Permanent Fix)

```bash
cd /home/lab-user/openshift-aiops-platform-deployment-testing

# Update from upstream main repo
git remote add upstream https://github.com/tosin2013/openshift-aiops-platform.git
git fetch upstream
git merge upstream/main

# This brings in:
# - Updated common/ subtree from validatedpatterns/common
# - Documentation explaining the issue
# - Post-deployment cleanup instructions

# Push to your fork
git push origin main
```

### Option 3: Add to Your Deployment Script

Add cleanup to your deployment automation:

```bash
# After 'make operator-deploy' completes
make operator-deploy
sleep 30  # Wait for resources to be created
oc delete namespace self-healing-platform-example imperative --ignore-not-found=true
```

## What Changed in Main Repo

The main repository (`/home/lab-user/openshift-aiops-platform`) was updated with:

1. **Updated common/ subtree**: Merged latest from `validatedpatterns/common`
2. **Documentation**: Added explanation in:
   - `README.md` - Post-deployment cleanup section
   - `docs/guides/JUNIOR-DEVELOPER-DEPLOYMENT-GUIDE.md` - Issue #5 with full explanation
3. **Reference link**: https://github.com/validatedpatterns/common

## Why This Happens

The upstream Validated Patterns `clustergroup` chart (v0.9.38) has these defaults in `values.yaml`:

```yaml
clusterGroup:
  name: example  # <-- Default value
```

When the Pattern CR is rendered, it creates ArgoCD instances for:
- **Your configured value** (`hub`) → `self-healing-platform-hub` ✅
- **Upstream default** (`example`) → `self-healing-platform-example` ⚠️ (extra)

The `imperative` namespace contains Vault-related jobs and is also from upstream defaults.

## Verification

After cleanup, verify only correct namespaces remain:

```bash
oc get namespaces | grep -E "self-healing|imperative"
# Expected output (no imperative or example):
# self-healing-platform           Active   <time>
# self-healing-platform-hub       Active   <time>

oc get argocd -A
# Expected output (no example-gitops):
# NAMESPACE                   NAME        AGE
# common-hub                  hub-gitops  <time>
# openshift-gitops            openshift-gitops  <time>
```

## Questions?

See the updated documentation in the main repo:
- [README.md](README.md) - Quick Start section
- [docs/guides/JUNIOR-DEVELOPER-DEPLOYMENT-GUIDE.md](docs/guides/JUNIOR-DEVELOPER-DEPLOYMENT-GUIDE.md) - Issue #5

The main repo has been updated and pushed to: https://github.com/tosin2013/openshift-aiops-platform
