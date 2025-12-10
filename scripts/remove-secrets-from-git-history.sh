#!/bin/bash
# Remove secrets from git history using git-filter-repo
# WARNING: This rewrites git history and requires force push

set -e

echo "=================================================="
echo "Git History Secrets Removal Script"
echo "=================================================="
echo ""
echo "⚠️  WARNING: This will rewrite git history!"
echo "⚠️  All contributors will need to re-clone the repository."
echo ""
read -p "Do you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Check if git-filter-repo is installed
if ! command -v git-filter-repo &> /dev/null; then
    echo "❌ git-filter-repo not found. Installing..."
    pip3 install --user git-filter-repo
    export PATH="$PATH:$HOME/.local/bin"
fi

# Backup the repository
echo "📦 Creating backup..."
cd /home/lab-user
tar -czf openshift-aiops-platform-backup-$(date +%Y%m%d-%H%M%S).tar.gz openshift-aiops-platform/
echo "✅ Backup created"

cd /home/lab-user/openshift-aiops-platform

# Create expressions file for secrets to remove
cat > /tmp/secrets-to-remove.txt <<'EOF'
# Red Hat OAuth tokens (JWT format)
regex:eyJhbGciOiJIUzUxMiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICI0NzQzYTkzMC03YmJiLTRkZGQtOTgzMS00ODcxNGRlZDc0YjUifQ\..*===>***REMOVED***

# S3 access keys
literal:j4aXKdsrqAzKhyxu84Jc===>***REMOVED***
literal:7BFR+5e8zC8gSaTTY/v4MfPD0A4UQNTB8OGxwJnT===>***REMOVED***

# Webhook secrets
literal:abdf580d9f49afad1109015b4d9c7d9cd8700e5c===>***REMOVED***

# Example passwords (though not real, should remove)
literal:pQF1QnP8pf3AzkoXY5wlm0C5XhzoHxaw===>***REMOVED***
EOF

echo "🔍 Scanning git history for secrets..."
git-filter-repo \
  --replace-text /tmp/secrets-to-remove.txt \
  --force

echo "✅ Secrets removed from git history"
echo ""
echo "📝 Next steps:"
echo "1. Verify the changes: git log --all --full-history --source -- ansible.cfg"
echo "2. Force push to remote: git push --force --all"
echo "3. Force push tags: git push --force --tags"
echo "4. Notify all contributors to re-clone the repository"
echo ""
echo "⚠️  WARNING: After force push, all contributors MUST re-clone!"
