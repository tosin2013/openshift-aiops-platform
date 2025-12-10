#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================="
echo "OpenShift AI Ops Platform Deployment"
echo "With Full Prerequisites (Hybrid Management Model)"
echo "=========================================="
echo ""
echo "This script implements the deployment sequence from ADR-030:"
echo "  1. Prerequisites validation"
echo "  2. Common infrastructure (ESO, Helm, GitOps)"
echo "  3. Secrets management"
echo "  4. Notebook validation setup"
echo "  5. Cluster-scoped RBAC resources"
echo "  6. Pattern deployment (Pattern CR)"
echo "  7. Post-deployment validation"
echo ""
echo "Reference: docs/adrs/030-hybrid-management-model-namespaced-argocd.md"
echo "=========================================="
echo ""

# Configuration
CONTAINER_ENGINE="${CONTAINER_ENGINE:-podman}"
EE_IMAGE="${EE_IMAGE:-openshift-aiops-platform-ee:latest}"
PLAYBOOK="${PROJECT_ROOT}/ansible/playbooks/deploy_complete_pattern.yml"
ANSIBLE_MODE="${ANSIBLE_MODE:-stdout}"

# Check if execution environment image exists
echo "Checking execution environment..."
if ! ${CONTAINER_ENGINE} images | grep -q "openshift-aiops-platform-ee"; then
    echo "⚠️  Warning: Execution environment image not found"
    echo "   Building it now with: make build"
    echo ""
    cd "${PROJECT_ROOT}"
    make build
    if [ $? -ne 0 ]; then
        echo "❌ Failed to build execution environment"
        exit 1
    fi
fi

# Step 1-5: Run Ansible prerequisites
echo ""
echo "=========================================="
echo "Step 1-5: Deploying Prerequisites"
echo "=========================================="
echo ""
echo "Running Ansible playbook with tags:"
echo "  - prerequisites: Cluster validation"
echo "  - common: External Secrets Operator, Helm, GitOps"
echo "  - secrets: SecretStore, credentials management"
echo "  - notebooks: GitHub PAT, Tekton RBAC, build PVCs"
echo "  - cluster-resources: ClusterRole/ClusterRoleBinding (Hybrid Management Model)"
echo ""

ansible-navigator run "${PLAYBOOK}" \
  --container-engine "${CONTAINER_ENGINE}" \
  --execution-environment-image "${EE_IMAGE}" \
  --mode "${ANSIBLE_MODE}" \
  --tags "prerequisites,common,secrets,notebooks,cluster-resources" \
  --extra-vars "enable_operator=false enable_validation=false" \
  --eev "${HOME}/.kube:/runner/.kube:Z" \
  --set-env KUBECONFIG=/runner/.kube/config \
  --eev "${PROJECT_ROOT}:/runner/project:Z" \
  --set-env ANSIBLE_ROLES_PATH=/runner/project/ansible/roles

if [ $? -ne 0 ]; then
  echo ""
  echo "❌ Ansible prerequisite deployment failed"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check cluster connectivity: oc cluster-info"
  echo "  2. Verify operators installed: oc get csv -n openshift-operators"
  echo "  3. Check logs above for specific error"
  echo "  4. Review ADR-030 for architecture details"
  echo ""
  exit 1
fi

echo ""
echo "✅ Prerequisites deployed successfully"
echo ""

# Verify cluster-scoped resources deployed
echo "Verifying cluster-scoped resources..."
CLUSTER_ROLES=$(oc get clusterrole 2>/dev/null | grep -c "self-healing" || echo "0")
if [ "${CLUSTER_ROLES}" -gt 0 ]; then
    echo "✅ Found ${CLUSTER_ROLES} self-healing ClusterRoles"
else
    echo "⚠️  Warning: No self-healing ClusterRoles found"
fi

CLUSTER_ROLE_BINDINGS=$(oc get clusterrolebinding 2>/dev/null | grep -c "self-healing" || echo "0")
if [ "${CLUSTER_ROLE_BINDINGS}" -gt 0 ]; then
    echo "✅ Found ${CLUSTER_ROLE_BINDINGS} self-healing ClusterRoleBindings"
else
    echo "⚠️  Warning: No self-healing ClusterRoleBindings found"
fi

echo ""

# Step 6: Deploy Pattern CR
echo "=========================================="
echo "Step 6: Deploying Pattern CR"
echo "=========================================="
echo ""
echo "This will create the Pattern CR which triggers:"
echo "  - Pattern Operator reconciliation"
echo "  - ArgoCD Application creation"
echo "  - Namespaced resource deployment (rbac.clusterScoped.enabled=false)"
echo ""

cd "${PROJECT_ROOT}"
make -f common/Makefile operator-deploy

if [ $? -ne 0 ]; then
  echo ""
  echo "❌ Pattern deployment failed"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check Pattern CR: oc get pattern -A"
  echo "  2. Check operator logs: oc logs -n openshift-operators -l control-plane=controller-manager"
  echo "  3. Verify values files: values-global.yaml, values-hub.yaml"
  echo ""
  exit 1
fi

echo ""
echo "✅ Pattern CR deployed"
echo ""

# Wait for ArgoCD sync
echo "Waiting for ArgoCD to sync (30 seconds)..."
sleep 30

# Check ArgoCD application status
echo ""
echo "Checking ArgoCD application status..."
ARGOCD_APPS=$(oc get applications.argoproj.io -A 2>/dev/null | grep -c "self-healing" || echo "0")
if [ "${ARGOCD_APPS}" -gt 0 ]; then
    echo "✅ Found ${ARGOCD_APPS} ArgoCD applications"
    oc get applications.argoproj.io -A | grep self-healing
else
    echo "⚠️  Warning: No ArgoCD applications found yet"
fi

echo ""

# Step 7: Validation
echo "=========================================="
echo "Step 7: Post-Deployment Validation"
echo "=========================================="
echo ""
echo "Running validation checks..."
echo ""

ansible-navigator run "${PLAYBOOK}" \
  --container-engine "${CONTAINER_ENGINE}" \
  --execution-environment-image "${EE_IMAGE}" \
  --mode "${ANSIBLE_MODE}" \
  --tags "validation" \
  --extra-vars "enable_operator=false validate_namespace=self-healing-platform" \
  --eev "${HOME}/.kube:/runner/.kube:Z" \
  --set-env KUBECONFIG=/runner/.kube/config \
  --eev "${PROJECT_ROOT}:/runner/project:Z" \
  --set-env ANSIBLE_ROLES_PATH=/runner/project/ansible/roles

VALIDATION_RESULT=$?

echo ""
echo "=========================================="
echo "Deployment Summary"
echo "=========================================="
echo ""

# Check final status
echo "Cluster Resources:"
oc get clusterrole,clusterrolebinding 2>/dev/null | grep self-healing | head -10 || echo "  ⚠️  No cluster resources found"

echo ""
echo "ArgoCD Applications:"
oc get applications.argoproj.io -A 2>/dev/null || echo "  ⚠️  No applications found"

echo ""
echo "Pattern Status:"
oc get pattern -A 2>/dev/null || echo "  ⚠️  No pattern found"

echo ""
echo "Pods in self-healing-platform namespace:"
oc get pods -n self-healing-platform 2>/dev/null || echo "  ⚠️  No pods found (may be deploying)"

echo ""
echo "=========================================="
if [ ${VALIDATION_RESULT} -eq 0 ]; then
    echo "✅ Deployment Complete!"
else
    echo "⚠️  Deployment Complete with Warnings"
    echo "   Some validation checks failed - review logs above"
fi
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Monitor ArgoCD sync: oc get applications -A --watch"
echo "  2. Check pod status: oc get pods -n self-healing-platform --watch"
echo "  3. View ArgoCD UI: oc get route -n openshift-gitops"
echo "  4. Check cluster resources: oc get clusterrole,clusterrolebinding | grep self-healing"
echo "  5. Review deployment logs: oc logs -n openshift-operators -l control-plane=controller-manager"
echo ""
echo "Troubleshooting:"
echo "  - If ArgoCD shows ComparisonError: cluster resources may not be deployed"
echo "    → Run: oc get clusterrole,clusterrolebinding | grep self-healing"
echo "  - If Pattern CR stuck: check operator logs"
echo "    → Run: oc logs -n openshift-operators -l control-plane=controller-manager --tail=50"
echo "  - For architecture details: docs/adrs/030-hybrid-management-model-namespaced-argocd.md"
echo ""
