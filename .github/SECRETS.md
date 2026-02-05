# GitHub Secrets Configuration

This document describes the GitHub secrets required for the automated execution environment build workflow.

## Required Secrets

Configure these in your GitHub repository settings: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

### 1. ANSIBLE_HUB_TOKEN (Required)

**Purpose:** Authenticate with Red Hat Automation Hub to download certified Ansible collections during the build process.

**Required for:** Build stage

**How to get it:**
1. Visit https://console.redhat.com/ansible/automation-hub/token
2. Log in with your Red Hat account
3. Click "Load token" or "Copy to clipboard"
4. Add as GitHub secret

**Example:**
```
Name: ANSIBLE_HUB_TOKEN
Secret: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 2. QUAY_USERNAME (Required for publishing)

**Purpose:** Username for authenticating to Quay.io container registry.

**Required for:** Publish stage

**How to get it:**
- Use your Quay.io username
- Or create a robot account at https://quay.io/organization/YOUR_ORG?tab=robots

**Example:**
```
Name: QUAY_USERNAME
Secret: takinosh
```

Or for robot accounts:
```
Name: QUAY_USERNAME
Secret: takinosh+robot_name
```

### 3. QUAY_PASSWORD (Required for publishing)

**Purpose:** Password or token for authenticating to Quay.io.

**Required for:** Publish stage

**How to get it:**
- Use your Quay.io password
- Or use robot account token from https://quay.io/organization/YOUR_ORG?tab=robots

**Example:**
```
Name: QUAY_PASSWORD
Secret: your-quay-password-or-robot-token
```

### 4. REDHAT_REGISTRY_USER (Optional)

**Purpose:** Username for authenticating to registry.redhat.io to pull base images.

**Required for:** Build stage (optional, workflow continues if missing)

**Note:** Often not needed as base images may be cached or publicly accessible.

**How to get it:**
- Use your Red Hat account username

**Example:**
```
Name: REDHAT_REGISTRY_USER
Secret: your-redhat-username
```

### 5. REDHAT_REGISTRY_PASSWORD (Optional)

**Purpose:** Password for authenticating to registry.redhat.io.

**Required for:** Build stage (optional, workflow continues if missing)

**How to get it:**
- Use your Red Hat account password

**Example:**
```
Name: REDHAT_REGISTRY_PASSWORD
Secret: your-redhat-password
```

## Verification

After adding secrets, verify they're configured correctly:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. You should see the secret names listed (values are hidden)
3. Test the workflow by triggering it manually:
   - Go to **Actions** tab
   - Select "Build and Publish Execution Environment"
   - Click **Run workflow**

## Security Best Practices

1. **Never commit secrets to the repository**
2. **Use robot accounts** for Quay.io instead of personal credentials when possible
3. **Rotate secrets periodically** (especially if a team member leaves)
4. **Limit scope** - use robot accounts with minimal required permissions
5. **Monitor usage** - review GitHub Actions logs for unexpected access

## Troubleshooting

### Build fails with "ANSIBLE_HUB_TOKEN not set"
- Ensure the secret is named exactly `ANSIBLE_HUB_TOKEN` (case-sensitive)
- Verify the token is valid by testing it locally:
  ```bash
  export ANSIBLE_HUB_TOKEN='your-token'
  make build-ee
  ```

### Publish fails with authentication error
- Check `QUAY_USERNAME` and `QUAY_PASSWORD` are set correctly
- Verify credentials work locally:
  ```bash
  echo "$QUAY_PASSWORD" | podman login quay.io --username "$QUAY_USERNAME" --password-stdin
  ```

### "registry.redhat.io" login fails
- This is optional and the workflow will continue
- Add `REDHAT_REGISTRY_USER` and `REDHAT_REGISTRY_PASSWORD` if needed
- Or ignore if the base image is already cached

## Robot Account Setup (Recommended for Quay.io)

Using robot accounts is more secure than personal credentials:

1. Go to https://quay.io/organization/YOUR_ORG?tab=robots
2. Click "Create Robot Account"
3. Name it (e.g., `github_actions_ee_builder`)
4. Grant permissions:
   - **Repository:** `openshift-aiops-platform-ee`
   - **Permission:** Write (to push images)
5. Copy the robot account name and token
6. Add to GitHub secrets:
   - `QUAY_USERNAME`: `YOUR_ORG+robot_name`
   - `QUAY_PASSWORD`: `<robot-token>`

## References

- [GitHub Encrypted Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Red Hat Automation Hub Token](https://console.redhat.com/ansible/automation-hub/token)
- [Quay.io Robot Accounts](https://docs.quay.io/glossary/robot-accounts.html)
