# Self-Healing Platform Kubernetes Manifests

This directory contains Kustomize-based Kubernetes manifests for deploying the Self-Healing Platform based on the Architecture Decision Records (ADRs).

## 📁 Directory Structure

```
k8s/
├── base/                           # Base Kustomize configuration
│   ├── kustomization.yaml         # Main Kustomization file
│   ├── namespace.yaml             # Namespace definition
│   ├── rbac.yaml                  # RBAC configuration
│   ├── storage.yaml               # PVC definitions
│   ├── monitoring.yaml            # ServiceMonitor and PrometheusRule
│   ├── coordination-engine.yaml   # Coordination engine deployment
│   ├── ai-ml-workbench.yaml      # Jupyter notebook workbench
│   └── model-serving.yaml         # KServe InferenceServices
├── overlays/
│   ├── development/               # Development environment overlay
│   │   └── kustomization.yaml
│   └── production/                # Production environment overlay
│       └── kustomization.yaml
└── README.md                      # This file
```

## 🎯 ADR Implementation Mapping

### ADR-001: OpenShift Platform Selection
- **Implementation**: All manifests target OpenShift 4.18+ features
- **Files**: All YAML files use OpenShift-compatible resources

### ADR-002: Hybrid Self-Healing Approach
- **Implementation**: Coordination engine deployment with conflict resolution
- **Files**: `coordination-engine.yaml`

### ADR-003: OpenShift AI ML Platform
- **Implementation**: Jupyter notebook workbench with GPU support
- **Files**: `ai-ml-workbench.yaml`

### ADR-004: KServe Model Serving
- **Implementation**: InferenceServices for anomaly detection and predictive analytics
- **Files**: `model-serving.yaml`

### ADR-005: Machine Config Operator
- **Implementation**: RBAC permissions for MCO resource access
- **Files**: `rbac.yaml`

### ADR-006: NVIDIA GPU Management
- **Implementation**: GPU resource requests in workbench and model serving
- **Files**: `ai-ml-workbench.yaml`, `model-serving.yaml`

### ADR-007: Prometheus Monitoring
- **Implementation**: ServiceMonitor and PrometheusRule for comprehensive monitoring
- **Files**: `monitoring.yaml`

### ADR-008: Kubeflow Pipelines MLOps
- **Implementation**: Notebook environment with MLOps libraries
- **Files**: `ai-ml-workbench.yaml`

## 🚀 Deployment Options

### Option 1: Using Bootstrap Script (Recommended)
```bash
# Development environment
./bootstrap.sh --environment development

# Production environment
./bootstrap.sh --environment production
```

### Option 2: Direct Kustomize Commands
```bash
# Development deployment
kustomize build k8s/overlays/development | oc apply -f -

# Production deployment
kustomize build k8s/overlays/production | oc apply -f -

# Using oc kustomize (if kustomize CLI not available)
oc apply -k k8s/overlays/development
oc apply -k k8s/overlays/production
```

### Option 3: GitOps with ArgoCD
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: self-healing-platform
spec:
  source:
    repoURL: https://github.com/your-org/openshift-aiops-platform
    path: k8s/overlays/production
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: self-healing-platform
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 🔧 Environment Configurations

### Development Environment
- **Namespace**: `self-healing-platform-dev`
- **Resources**: Reduced CPU/memory requests
- **Storage**: Smaller PVC sizes, standard storage classes
- **GPU**: Disabled (CPU-only for development)
- **Replicas**: Single instance deployments
- **Logging**: DEBUG level enabled

### Production Environment
- **Namespace**: `self-healing-platform`
- **Resources**: Production-grade CPU/memory limits
- **Storage**: High-performance storage classes (OCS)
- **GPU**: Full GPU support enabled
- **Replicas**: High availability (3 replicas for coordination engine)
- **Logging**: INFO level, structured logging
- **Security**: Enhanced RBAC, network policies

## 📊 Resource Requirements

### Development Environment
| Component | CPU Request | Memory Request | Storage |
|-----------|-------------|----------------|---------|
| Coordination Engine | 100m | 128Mi | - |
| Jupyter Workbench | 1 CPU | 4Gi | 5Gi |
| Model Serving | 500m | 1Gi | 10Gi |

### Production Environment
| Component | CPU Request | Memory Request | Storage | GPU |
|-----------|-------------|----------------|---------|-----|
| Coordination Engine | 500m | 512Mi | - | - |
| Jupyter Workbench | 2 CPU | 8Gi | 50Gi | 1 |
| Model Serving | 1-2 CPU | 2-4Gi | 200Gi | 1 |

## 🔒 Security Considerations

### RBAC Configuration
- Service account: `self-healing-operator`
- Minimal required permissions for each component
- Separate roles for different functions

### Secrets Management
- Model storage credentials in Kubernetes secrets
- Environment-specific secret overrides
- Production secrets should use external secret management (Vault, etc.)

### Network Security
- Service mesh integration (Istio)
- Network policies (production environment)
- Secure communication between components

## 📈 Monitoring and Observability

### Prometheus Integration
- ServiceMonitor for automatic metrics discovery
- PrometheusRule for platform-specific alerts
- Custom metrics from coordination engine

### Alert Categories
- **Critical**: Platform down, coordination engine failures
- **Warning**: High resource usage, configuration drift
- **Info**: Model performance, routine operations

### Grafana Dashboards
- Platform health overview
- AI/ML model performance
- Resource utilization trends

## 🔄 Customization Guide

### Adding New Components
1. Create YAML manifest in `base/` directory
2. Add to `resources` list in `base/kustomization.yaml`
3. Add environment-specific patches in overlays

### Modifying Resource Limits
1. Edit overlay-specific `kustomization.yaml`
2. Add patches for resource modifications
3. Test with `kustomize build` before applying

### Adding New Environments
1. Create new overlay directory: `k8s/overlays/staging`
2. Copy and modify existing overlay configuration
3. Update bootstrap script to support new environment

## 🧪 Testing and Validation

### Pre-deployment Testing
```bash
# Validate Kustomize configuration
kustomize build k8s/overlays/development

# Dry-run deployment
kustomize build k8s/overlays/development | oc apply --dry-run=client -f -
```

### Post-deployment Validation
```bash
# Run validation script
./validate_bootstrap.sh

# Check resource status
oc get all -n self-healing-platform-dev
oc get pvc,secrets,configmaps -n self-healing-platform-dev
```

## 📚 References

- [Kustomize Documentation](https://kustomize.io/)
- [OpenShift Kustomize Guide](https://docs.openshift.com/container-platform/4.18/applications/working_with_kustomize.html)
- [Self-Healing Platform ADRs](../docs/adrs/)
- [Implementation Tasks](../IMPLEMENTATION_TASKS.md)

## 🆘 Troubleshooting

### Common Issues

1. **Kustomize build fails**
   - Check YAML syntax in base and overlay files
   - Verify all referenced files exist
   - Validate patch syntax

2. **Deployment fails**
   - Check cluster permissions
   - Verify required operators are installed
   - Review resource quotas and limits

3. **Pods not starting**
   - Check image pull policies and registry access
   - Verify PVC availability and storage classes
   - Review resource requests vs. cluster capacity

### Debug Commands
```bash
# Check Kustomize output
kustomize build k8s/overlays/development

# Describe failed resources
oc describe pod <pod-name> -n <namespace>
oc describe pvc <pvc-name> -n <namespace>

# Check events
oc get events -n <namespace> --sort-by='.lastTimestamp'
```
