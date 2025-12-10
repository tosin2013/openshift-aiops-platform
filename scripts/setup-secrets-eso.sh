#!/usr/bin/env bash
# Setup secrets for External Secrets Operator
# This script creates the necessary secrets in the self-healing-platform namespace
# for use with External Secrets Operator (ESO)

set -e

NAMESPACE="${1:-self-healing-platform}"
GITEA_USERNAME="${GITEA_USERNAME:-user1}"
GITEA_PASSWORD="${GITEA_PASSWORD:-r3dh@t123}"
S3_ENDPOINT="${S3_ENDPOINT:-https://s3.openshift-storage.svc:443}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-admin}"
S3_SECRET_KEY="${S3_SECRET_KEY:-changeme}"
S3_BUCKET="${S3_BUCKET:-model-storage}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "Setting up secrets for External Secrets Operator in namespace: $NAMESPACE"

# Ensure namespace exists
oc get namespace "$NAMESPACE" > /dev/null 2>&1 || oc create namespace "$NAMESPACE"

# Create gitea-credentials-source secret (source for ESO to sync from)
echo "Creating gitea-credentials-source secret..."
oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitea-credentials-source
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: gitea-credentials
    app.kubernetes.io/component: credentials-source
type: Opaque
stringData:
  username: "$GITEA_USERNAME"
  password: "$GITEA_PASSWORD"
EOF

# Create gitea-credentials secret (for BuildConfig)
echo "Creating gitea-credentials secret..."
oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitea-credentials
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: gitea-credentials
    app.kubernetes.io/component: buildconfig-credentials
type: kubernetes.io/basic-auth
stringData:
  username: "$GITEA_USERNAME"
  password: "$GITEA_PASSWORD"
EOF

# Create model-storage-config secret
echo "Creating model-storage-config secret..."
oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: model-storage-config
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/component: model-storage
    app.kubernetes.io/name: self-healing-platform
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: "$S3_ACCESS_KEY"
  AWS_SECRET_ACCESS_KEY: "$S3_SECRET_KEY"
  AWS_S3_ENDPOINT: "$S3_ENDPOINT"
  AWS_S3_BUCKET: "$S3_BUCKET"
  AWS_DEFAULT_REGION: "$AWS_REGION"
EOF

# Create SecretStore for Kubernetes backend
echo "Creating SecretStore for External Secrets Operator..."
oc apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: kubernetes-secret-store
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: external-secrets
    app.kubernetes.io/component: secretstore
spec:
  provider:
    kubernetes:
      auth:
        serviceAccount:
          name: external-secrets-sa
      remoteNamespace: $NAMESPACE
      server:
        caProvider:
          type: ConfigMap
          name: kube-root-ca.crt
          key: ca.crt
EOF

# Create ServiceAccount for ESO
echo "Creating ServiceAccount for External Secrets Operator..."
oc apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: external-secrets
    app.kubernetes.io/component: service-account
EOF

# Create ClusterRole for ESO
echo "Creating ClusterRole for External Secrets Operator..."
oc apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-secrets-$NAMESPACE
  labels:
    app.kubernetes.io/name: external-secrets
    app.kubernetes.io/component: rbac
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
EOF

# Create ClusterRoleBinding for ESO
echo "Creating ClusterRoleBinding for External Secrets Operator..."
oc apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: external-secrets-$NAMESPACE
  labels:
    app.kubernetes.io/name: external-secrets
    app.kubernetes.io/component: rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-secrets-$NAMESPACE
subjects:
- kind: ServiceAccount
  name: external-secrets-sa
  namespace: $NAMESPACE
EOF

echo ""
echo "✅ Secrets setup complete!"
echo ""
echo "Secrets created in namespace: $NAMESPACE"
echo "  - gitea-credentials-source (source secret)"
echo "  - gitea-credentials (for BuildConfig)"
echo "  - model-storage-config (S3 configuration)"
echo ""
echo "ESO resources created:"
echo "  - SecretStore: kubernetes-secret-store"
echo "  - ServiceAccount: external-secrets-sa"
echo "  - ClusterRole: external-secrets-$NAMESPACE"
echo "  - ClusterRoleBinding: external-secrets-$NAMESPACE"
echo ""
echo "Verify secrets:"
echo "  oc get secrets -n $NAMESPACE"
echo "  oc get secretstore -n $NAMESPACE"
