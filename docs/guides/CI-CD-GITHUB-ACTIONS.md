# CI/CD with GitHub Actions for Helm Validation

## Overview

This guide explains how to set up GitHub Actions for automated Helm chart validation and pre-commit hook execution on every push and pull request.

## Prerequisites

- GitHub repository with the OpenShift AI Ops Platform code
- GitHub Actions enabled in repository settings

## Workflow Files

### 1. Helm Validation Workflow

**Location**: `.github/workflows/helm-validation.yml`

**Triggers**:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Only when `charts/**` or `values-*.yaml` files change

**Jobs**:

#### Job 1: helm-lint
- Runs `helm lint` on all charts
- Executes `helm template` to validate rendering
- (Optional) Validates Kubernetes manifests with `kubeconform`
- (Optional) Checks for deprecated APIs with `pluto`
- Uploads rendered manifests as artifacts
- **Auto-creates GitHub issue on failure** 🚨

#### Job 2: pre-commit
- Runs all pre-commit hooks
- Validates YAML syntax
- Checks for secrets with Gitleaks
- Runs yamllint
- **Auto-creates GitHub issue on failure** 🚨

### Automatic Issue Creation

When validation fails, the workflow automatically:
1. **Creates a GitHub issue** with detailed failure information
2. **Avoids duplicates** - Adds comments to existing open issues instead
3. **Labels appropriately** - `helm-validation`, `pre-commit`, `ci-failure`, `bug`
4. **Includes context** - Workflow run URL, commit details, error guidance
5. **Provides fix instructions** - Commands to reproduce and fix locally

**Example Issue Title**: `🚨 Helm Validation Failed - Helm Chart Validation`

**Issue Contents**:
- Link to failed workflow run
- Branch and commit information
- Action required (step-by-step fix instructions)
- Related files to check
- Useful commands for local debugging

## Setup Instructions

### Step 1: Copy Workflow to GitHub Repository

```bash
# If using GitHub as primary repository
git remote add github https://github.com/<your-org>/openshift-aiops-platform.git
git push github main

# Or create via GitHub UI
# Navigate to: Repository → Actions → New workflow
# Copy contents from .github/workflows/helm-validation.yml
```

### Step 2: Configure GitHub Secrets (if needed)

For private Helm repositories or registries:

```bash
# Navigate to: Repository → Settings → Secrets and variables → Actions
# Add secrets:
# - HELM_REPO_USERNAME
# - HELM_REPO_PASSWORD
# - CONTAINER_REGISTRY_TOKEN (for image pulls)
```

### Step 3: Test Workflow

```bash
# Make a test commit
git checkout -b test/github-actions
echo "# Test" >> README.md
git add README.md
git commit -m "test: trigger GitHub Actions workflow"
git push origin test/github-actions

# Create pull request on GitHub
# Workflow will run automatically
```

### Step 4: Monitor Workflow Execution

1. Navigate to: **Repository → Actions**
2. Click on workflow run
3. View logs for each job
4. Download rendered manifests artifact (if needed)

## Workflow Results

### Success ✅
- All Helm lint checks pass
- Templates render without errors
- Pre-commit hooks pass
- Pull request can be merged

### Failure ❌
- Helm lint errors → Check chart syntax
- Template rendering errors → Fix values files or templates
- Pre-commit failures → Run `pre-commit run --all-files` locally

## Local Testing Before Push

**Always test locally first:**

```bash
# Run Helm validation
helm lint charts/hub -f values-global.yaml -f values-hub.yaml
helm template test charts/hub -f values-global.yaml -f values-hub.yaml

# Run pre-commit hooks
pre-commit run --all-files

# If all pass, commit and push
git add .
git commit -m "fix: your changes"
git push
```

## Integration with Gitea

For Gitea repositories, you can use:

1. **Gitea Actions** (similar to GitHub Actions)
   ```yaml
   # .gitea/workflows/helm-validation.yml
   # Same syntax as GitHub Actions
   ```

2. **Gitea Webhooks** + Jenkins/Tekton
   ```bash
   # Configure in Gitea UI:
   # Repository → Settings → Webhooks → Add Webhook
   # URL: https://jenkins.example.com/generic-webhook-trigger/invoke
   # Events: Push, Pull Request
   ```

3. **OpenShift Pipelines (Tekton)** - Already configured!
   ```bash
   # Existing validation pipeline
   tkn pipeline start deployment-validation-pipeline --showlog
   ```

## Advanced Configuration

### Add Kubeconform Validation

```yaml
- name: Validate with Kubeconform
  run: |
    helm template charts/hub | kubeconform -strict -kubernetes-version 1.31.0
```

### Add Polaris Best Practices Check

```yaml
- name: Check Best Practices
  run: |
    helm template charts/hub | polaris audit --format=yaml
```

### Add Datree Policy Enforcement

```yaml
- name: Datree Policy Check
  run: |
    helm datree test charts/hub/
  env:
    DATREE_TOKEN: ${{ secrets.DATREE_TOKEN }}
```

## Status Badges

Add to README.md:

```markdown
![Helm Validation](https://github.com/<your-org>/openshift-aiops-platform/actions/workflows/helm-validation.yml/badge.svg)
```

## Troubleshooting

### Workflow Not Triggering

**Check**:
- Workflow file syntax (use `yamllint .github/workflows/*.yml`)
- Path filters (`paths:` in workflow)
- Branch protection rules

### Helm Lint Failures

**Common Issues**:
- Missing values in `values-*.yaml`
- Incorrect template syntax
- Schema validation errors

**Fix**:
```bash
# Test locally first
helm lint charts/hub -f values-global.yaml -f values-hub.yaml --debug
```

### Pre-commit Failures in CI but Not Locally

**Cause**: Different pre-commit versions or Python versions

**Fix**:
```yaml
# Pin versions in workflow
- uses: actions/setup-python@v5
  with:
    python-version: '3.11'  # Match local version
```

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Pre-commit Documentation](https://pre-commit.com/)
- [Kubeconform](https://github.com/yannh/kubeconform)
- [Pluto (Deprecation Checker)](https://github.com/FairwindsOps/pluto)
- [Polaris (Best Practices)](https://github.com/FairwindsOps/polaris)
- [Datree (Policy Enforcement)](https://github.com/datreeio/datree)

## Next Steps

1. ✅ **Workflow created** - `.github/workflows/helm-validation.yml`
2. ⬜ **Push to GitHub** (optional, for GitHub Actions)
3. ⬜ **Configure Gitea Actions** (if using Gitea as primary)
4. ⬜ **Add status badges** to README.md
5. ⬜ **Configure branch protection** to require checks
6. ✅ **Pre-commit hooks working locally** - Already set up!

**Current Setup**: Using **local pre-commit hooks** + **Tekton pipelines** (already configured in ADR-021)
