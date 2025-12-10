#!/bin/bash
# Fix CSI Plugin on GPU Node
# This script adds GPU node toleration to CSI DaemonSets so they can run on GPU nodes
# Date: 2025-10-20

set -e

echo "=========================================="
echo "Fixing CSI Plugin on GPU Node"
echo "=========================================="
echo ""

NAMESPACE="openshift-storage"

# Check if GPU node exists
echo "1. Checking for GPU nodes..."
GPU_NODES=$(oc get nodes -l node-role.kubernetes.io/worker-gpu --no-headers 2>/dev/null | wc -l)

if [[ $GPU_NODES -lt 1 ]]; then
  echo "   ❌ No GPU nodes found. Exiting."
  exit 1
fi

echo "   ✅ Found $GPU_NODES GPU node(s)"
echo ""

# Check current CSI DaemonSet tolerations
echo "2. Checking current CSI DaemonSet tolerations..."
oc get daemonset csi-cephfsplugin -n $NAMESPACE -o yaml | grep -A 5 "tolerations:" || echo "   No tolerations found"
echo ""

# Add GPU node toleration to CephFS CSI DaemonSet
echo "3. Adding GPU node toleration to csi-cephfsplugin DaemonSet..."
oc patch daemonset csi-cephfsplugin -n $NAMESPACE --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/tolerations/-",
    "value": {
      "key": "nvidia.com/gpu",
      "operator": "Equal",
      "value": "True",
      "effect": "NoSchedule"
    }
  }
]' 2>/dev/null || echo "   ⚠️  Toleration may already exist"

echo "   ✅ GPU node toleration added to csi-cephfsplugin"
echo ""

# Add GPU node toleration to RBD CSI DaemonSet
echo "4. Adding GPU node toleration to csi-rbdplugin DaemonSet..."
oc patch daemonset csi-rbdplugin -n $NAMESPACE --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/tolerations/-",
    "value": {
      "key": "nvidia.com/gpu",
      "operator": "Equal",
      "value": "True",
      "effect": "NoSchedule"
    }
  }
]' 2>/dev/null || echo "   ⚠️  Toleration may already exist"

echo "   ✅ GPU node toleration added to csi-rbdplugin"
echo ""

# Wait for DaemonSet to roll out
echo "5. Waiting for CSI DaemonSets to roll out..."
oc rollout status daemonset/csi-cephfsplugin -n $NAMESPACE --timeout=5m
oc rollout status daemonset/csi-rbdplugin -n $NAMESPACE --timeout=5m
echo "   ✅ DaemonSets rolled out successfully"
echo ""

# Verify CSI plugins on GPU node
echo "6. Verifying CSI plugins on GPU node..."
GPU_NODE=$(oc get nodes -l node-role.kubernetes.io/worker-gpu -o name 2>/dev/null | head -1 | cut -d'/' -f2)
echo "   GPU Node: $GPU_NODE"

CEPHFS_PODS=$(oc get pods -n $NAMESPACE -o wide 2>/dev/null | grep "$GPU_NODE" | grep csi-cephfsplugin | wc -l)
RBD_PODS=$(oc get pods -n $NAMESPACE -o wide 2>/dev/null | grep "$GPU_NODE" | grep csi-rbdplugin | wc -l)

echo "   CephFS CSI Pods on GPU Node: $CEPHFS_PODS"
echo "   RBD CSI Pods on GPU Node: $RBD_PODS"

if [[ $CEPHFS_PODS -gt 0 ]] && [[ $RBD_PODS -gt 0 ]]; then
  echo "   ✅ CSI plugins successfully running on GPU node"
else
  echo "   ⚠️  CSI plugins not yet running on GPU node (may take a moment)"
fi
echo ""

echo "=========================================="
echo "CSI GPU Node Fix Complete"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Wait for workbench pod to restart"
echo "2. Check workbench pod status: oc get pods -n self-healing-platform"
echo "3. Verify workbench pod is Running: oc describe pod self-healing-workbench-dev-0 -n self-healing-platform"
echo ""
