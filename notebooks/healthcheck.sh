#!/bin/bash
# Health check script for notebook validator image
# Validates that all required tools are installed

set -e

echo "🔍 Notebook Validator Health Check"
echo "===================================="

# Check Python
python3 --version || exit 1
echo "✅ Python installed"

# Check OpenShift CLI
oc version --client || exit 1
echo "✅ OpenShift CLI installed"

# Check kubectl
kubectl version --client || exit 1
echo "✅ kubectl installed"

# Check required Python packages
python3 -c "import kubernetes, openshift, prometheus_api_client, papermill" || exit 1
echo "✅ Python packages installed"

# Check Jupyter
jupyter --version || exit 1
echo "✅ Jupyter installed"

echo ""
echo "✅ All health checks passed"
exit 0
