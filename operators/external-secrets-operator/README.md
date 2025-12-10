# External Secrets Operator Installation

This directory contains reference manifests for the External Secrets Operator (ESO) v0.11.0, following the official Red Hat OpenShift documentation.

## Overview

The External Secrets Operator synchronizes secrets from external secret management systems (like HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, etc.) into Kubernetes/OpenShift secrets.

**Version:** 0.11.0
**Source:** Community Operators (OperatorHub)
**Namespace:** `external-secrets-operator`
**ADR Reference:** [ADR-026: Secrets Management Automation](../../docs/adrs/026-secrets-management-automation.md)

## Documentation

- **Upstream Documentation:** https://external-secrets.io
- **Red Hat Documentation:** https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html/security_and_compliance/external-secrets-operator-for-red-hat-openshift
- **GitHub:** https://github.com/external-secrets/external-secrets
- **Helm Operator:** https://github.com/external-secrets/external-secrets-helm-operator

## Prerequisites

- OpenShift 4.18+ (tested on 4.18.21)
- Cluster admin privileges
- `oc` CLI installed and configured
- Validated Patterns framework deployed (OpenShift GitOps)

## Installation

### Validated Patterns Integration (Recommended)

The External Secrets Operator is integrated into the Validated Patterns framework and deployed automatically via GitOps.

**Configuration:** `values-hub.yaml`

```yaml
operators:
  external-secrets:
    enabled: true
    namespace: external-secrets-operator
    channel: alpha
    version: v0.11.0
    source: community-operators
    config:
      prometheus:
        enabled: true
      resources:
        requests:
          cpu: 10m
          memory: 96Mi
        limits:
          cpu: 100m
          memory: 256Mi
```

**Deployment:**

```bash
# Deploy the entire pattern (includes ESO)
make install

# Or update existing deployment
make upgrade
```

The operator will be deployed via ArgoCD as part of the hub cluster configuration. The Helm template at `charts/hub/templates/operators/external-secrets-operator.yaml` manages the operator lifecycle.

**Estimated Time:** 2-3 minutes (as part of pattern deployment)

### Standalone Install (For Testing Only)

For testing or manual installation outside of the Validated Patterns framework:

```bash
# Step 1: Apply namespace, OperatorGroup, and Subscription
oc apply -k .

# Step 2: Wait for operator to be installed (2-3 minutes)
oc wait --for=jsonpath='{.status.phase}'=Succeeded \
    csv/external-secrets-operator.v0.11.0 \
    -n external-secrets-operator \
    --timeout=300s

# Step 3: Apply OperatorConfig
oc apply -f operatorconfig.yaml

# Step 4: Verify installation
oc get pods -n external-secrets-operator
oc get operatorconfig -n external-secrets-operator
```

**Note:** This approach is NOT recommended for production. Use the Validated Patterns integration instead.

## Files

- **`namespace.yaml`** - Creates the `external-secrets-operator` namespace with monitoring enabled
- **`operatorgroup.yaml`** - Defines the OperatorGroup for the namespace
- **`subscription.yaml`** - Subscribes to ESO v0.11.0 from Community Operators
- **`operatorconfig.yaml`** - Configures the operator (Helm chart values)
- **`kustomization.yaml`** - Kustomize configuration for deployment
- **`install.sh`** - Automated installation script
- **`README.md`** - This file

## Configuration

The `operatorconfig.yaml` file configures the operator with:

- **Prometheus Monitoring:** Enabled on port 8080
- **Resource Limits:**
  - Requests: 10m CPU, 96Mi memory
  - Limits: 100m CPU, 256Mi memory
- **Cluster-Wide Resources:** Enabled (ClusterSecretStore, ClusterExternalSecret)
- **Leader Election:** Enabled for HA
- **Webhook:** Enabled with certificate management
- **Certificate Controller:** Enabled with 5-minute requeue interval

### Customization

To customize the configuration, edit `operatorconfig.yaml` before installation. Common customizations:

```yaml
spec:
  # Increase resources for production
  resources:
    requests:
      cpu: 50m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Increase concurrent reconciliations
  concurrent: 5

  # Scope to specific namespace (instead of cluster-wide)
  scopedNamespace: "my-namespace"
  scopedRBAC: true
```

## Verification

After installation, verify the operator is running:

```bash
# Check operator status
oc get csv -n external-secrets-operator

# Check operator pods
oc get pods -n external-secrets-operator

# Expected pods:
# - cluster-external-secrets (main controller)
# - cluster-external-secrets-cert-controller
# - cluster-external-secrets-webhook

# Check OperatorConfig
oc get operatorconfig -n external-secrets-operator

# Check available CRDs
oc get crd | grep external-secrets
```

Expected CRDs:
- `acraccesstokens.generators.external-secrets.io`
- `clusterexternalsecrets.external-secrets.io`
- `clustergenerators.generators.external-secrets.io`
- `clustersecretstores.external-secrets.io`
- `ecrauthorizationtokens.generators.external-secrets.io`
- `externalsecrets.external-secrets.io`
- `fakes.generators.external-secrets.io`
- `gcraccesstokens.generators.external-secrets.io`
- `githubaccesstokens.generators.external-secrets.io`
- `operatorconfigs.operator.external-secrets.io`
- `passwords.generators.external-secrets.io`
- `pushsecrets.external-secrets.io`
- `secretstores.external-secrets.io`
- `stssessiontokens.generators.external-secrets.io`
- `uuids.generators.external-secrets.io`
- `vaultdynamicsecrets.generators.external-secrets.io`
- `webhooks.generators.external-secrets.io`

## Next Steps

After installing the operator, follow ADR-026 to:

1. **Deploy a Secret Backend** (e.g., HashiCorp Vault)
2. **Create a SecretStore or ClusterSecretStore**
3. **Create ExternalSecret resources**
4. **Configure secret rotation**
5. **Set up monitoring and alerts**

### Example: Create a ClusterSecretStore for Vault

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
          serviceAccountRef:
            name: "external-secrets-sa"
            namespace: "external-secrets-operator"
```

### Example: Create an ExternalSecret

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: self-healing-platform
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: database/credentials
        property: username
    - secretKey: password
      remoteRef:
        key: database/credentials
        property: password
```

## Troubleshooting

### Operator not installing

```bash
# Check subscription status
oc get subscription -n external-secrets-operator

# Check install plan
oc get installplan -n external-secrets-operator

# Check operator logs
oc logs -n external-secrets-operator -l app.kubernetes.io/name=external-secrets
```

### Pods not starting

```bash
# Check pod status
oc get pods -n external-secrets-operator

# Check pod logs
oc logs -n external-secrets-operator <pod-name>

# Check events
oc get events -n external-secrets-operator --sort-by='.lastTimestamp'
```

### CRDs not available

```bash
# List all CRDs
oc get crd | grep external-secrets

# Check CRD details
oc describe crd externalsecrets.external-secrets.io
```

### OperatorConfig not applying

```bash
# Check OperatorConfig status
oc get operatorconfig -n external-secrets-operator -o yaml

# Check operator logs
oc logs -n external-secrets-operator -l app.kubernetes.io/name=external-secrets-helm-operator
```

## Uninstallation

To uninstall the operator:

```bash
# Delete OperatorConfig first
oc delete -f operatorconfig.yaml

# Delete all ExternalSecrets and SecretStores
oc delete externalsecrets --all -A
oc delete secretstores --all -A
oc delete clustersecretstores --all

# Delete the operator
oc delete subscription external-secrets-operator -n external-secrets-operator
oc delete csv -n external-secrets-operator -l operators.coreos.com/external-secrets-operator.external-secrets-operator

# Delete the namespace (this will clean up everything)
oc delete namespace external-secrets-operator
```

## Support

- **Issues:** https://github.com/external-secrets/external-secrets/issues
- **Slack:** https://kubernetes.slack.com/messages/external-secrets
- **Email:** contact@external-secrets.io

## License

External Secrets Operator is under Apache 2.0 license.

## Related Documentation

- [ADR-026: Secrets Management Automation](../../docs/adrs/026-secrets-management-automation.md)
- [Implementation Plan](../../docs/IMPLEMENTATION-PLAN.md)
- [Cluster Readiness Report](../../docs/CLUSTER-READINESS-REPORT.md)
