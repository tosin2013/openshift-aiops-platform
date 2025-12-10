# ADR-022: Multi-Cluster Support via Red Hat Advanced Cluster Management

**Status:** ACCEPTED
**Date:** 2025-10-31
**Decision Makers:** Architecture Team
**Consulted:** DevOps Team, ML Engineering, Platform Operations
**Informed:** Development Team, Operations Team

## Context

The OpenShift AIOps Self-Healing Platform is currently deployed on a single hub cluster using the Validated Patterns framework (ADR-019). To support enterprise-scale deployments and edge computing scenarios, we need to extend the platform to:

1. **Multi-Cluster Deployments**: Deploy the platform across multiple OpenShift clusters
2. **Hub-Spoke Topology**: Central hub cluster managing multiple spoke (edge) clusters
3. **Centralized Management**: Single pane of glass for monitoring and control
4. **GitOps Propagation**: Automatic application deployment to edge clusters via ArgoCD
5. **Edge Computing**: Support for edge clusters with limited resources and connectivity

### Current Limitations

- Single cluster deployment only
- No support for edge computing scenarios
- Manual cluster registration and configuration
- No centralized policy management
- Limited scalability for enterprise deployments

### Multi-Cluster Requirements

1. **Cluster Registration**: Automated process to register edge clusters with hub
2. **Policy Management**: Centralized policies for security, compliance, and configuration
3. **Application Propagation**: Deploy applications to multiple clusters via GitOps
4. **Monitoring & Observability**: Centralized metrics and logs from all clusters
5. **Resource Management**: Efficient resource allocation across clusters
6. **Disaster Recovery**: Failover and recovery across clusters

## Decision

We will **implement multi-cluster support using Red Hat Advanced Cluster Management (ACM)** integrated with the Validated Patterns framework, enabling hub-spoke topology for the Self-Healing Platform.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Hub Cluster (OpenShift)                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Red Hat Advanced Cluster Management (ACM)           │   │
│  │  ├─ MultiClusterHub                                  │   │
│  │  ├─ ClusterManager                                   │   │
│  │  └─ Policy Engine                                    │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  OpenShift GitOps (ArgoCD)                           │   │
│  │  ├─ Hub ApplicationSet                               │   │
│  │  └─ Spoke ApplicationSets (per cluster)              │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Self-Healing Platform (Hub Instance)                │   │
│  │  ├─ Coordination Engine                              │   │
│  │  ├─ Model Serving (KServe)                           │   │
│  │  └─ Monitoring Stack (Prometheus/Grafana)            │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
    │ Spoke Cluster 1  │ Spoke Cluster 2  │ Spoke Cluster N
    │ (Edge/Regional)  │ (Edge/Regional)  │ (Edge/Regional)
    │                  │                  │
    │ Self-Healing     │ Self-Healing     │ Self-Healing
    │ Platform (Spoke) │ Platform (Spoke) │ Platform (Spoke)
    │                  │                  │
    │ Klusterlet Agent │ Klusterlet Agent │ Klusterlet Agent
    └─────────────────┘ └─────────────────┘ └─────────────────┘
```

### Hub-Spoke Topology

**Hub Cluster Responsibilities:**
- Central management and orchestration
- Policy enforcement and compliance
- Centralized monitoring and observability
- Application deployment coordination
- Cluster lifecycle management

**Spoke Cluster Responsibilities:**
- Run Self-Healing Platform workloads
- Execute model serving and inference
- Collect local metrics and logs
- Report status to hub
- Execute hub-defined policies

### Implementation Strategy

#### Phase 1: ACM Installation & Configuration (Week 1)
- [ ] Install Red Hat Advanced Cluster Management operator
- [ ] Configure MultiClusterHub resource
- [ ] Set up hub cluster as local-cluster
- [ ] Configure ACM networking and webhooks
- [ ] Validate hub cluster readiness

#### Phase 2: Cluster Registration (Week 2)
- [ ] Create cluster registration process
- [ ] Generate klusterlet manifests for spoke clusters
- [ ] Implement automated cluster onboarding
- [ ] Configure cluster labels and taints
- [ ] Validate cluster connectivity

#### Phase 3: GitOps Integration (Week 2-3)
- [ ] Create ApplicationSet for hub deployment
- [ ] Create ApplicationSets for spoke deployments
- [ ] Configure cluster-specific values
- [ ] Implement policy-based deployment
- [ ] Test GitOps propagation to spokes

#### Phase 4: Monitoring & Observability (Week 3)
- [ ] Configure metrics collection from spokes
- [ ] Set up centralized Prometheus scraping
- [ ] Create cross-cluster Grafana dashboards
- [ ] Implement alerting for multi-cluster scenarios
- [ ] Test log aggregation

#### Phase 5: Testing & Validation (Week 4)
- [ ] Create E2E tests for cluster registration
- [ ] Test application propagation
- [ ] Validate failover scenarios
- [ ] Performance testing with multiple clusters
- [ ] Documentation and runbooks

### Configuration Files

#### Hub Cluster Configuration

**File:** `values-hub-acm.yaml`
```yaml
acm:
  enabled: true
  multiClusterHub:
    namespace: open-cluster-management
    replicas: 3

  policies:
    - name: self-healing-platform-policy
      namespace: open-cluster-management-policies
      clusters: "all"

  applicationSets:
    - name: self-healing-hub
      namespace: openshift-gitops
      clusters: ["local-cluster"]

    - name: self-healing-spokes
      namespace: openshift-gitops
      clusters: "all-except-hub"
```

#### Spoke Cluster Configuration

**File:** `values-spoke-acm.yaml`
```yaml
acm:
  klusterlet:
    namespace: open-cluster-management-agent
    mode: hosted  # or default

  labels:
    cluster-type: spoke
    region: edge
    workload: self-healing

  taints:
    - key: workload
      value: self-healing
      effect: NoSchedule
```

### Deployment Workflow

```bash
# 1. Deploy hub cluster with ACM
make -f common/Makefile operator-deploy VALUES_FILE=values-hub-acm.yaml

# 2. Validate hub readiness
make -f common/Makefile argo-healthcheck

# 3. Register spoke clusters
ansible-playbook ansible/playbooks/register_spoke_clusters.yml

# 4. Validate spoke connectivity
make -f common/Makefile validate-multi-cluster

# 5. Deploy applications to spokes
make -f common/Makefile deploy-to-spokes

# 6. Validate end-to-end
make -f common/Makefile validate-e2e-multi-cluster
```

## Consequences

### Positive

1. **Scalability**: Support for enterprise-scale deployments across multiple clusters
2. **Edge Computing**: Enable edge computing scenarios with spoke clusters
3. **High Availability**: Distributed architecture improves resilience
4. **Centralized Management**: Single pane of glass for all clusters
5. **Policy Enforcement**: Consistent policies across all clusters
6. **GitOps Native**: Leverages ArgoCD for declarative multi-cluster deployments

### Negative

1. **Complexity**: Additional operational complexity with ACM
2. **Resource Overhead**: Hub cluster requires more resources
3. **Network Requirements**: Requires stable network between hub and spokes
4. **Learning Curve**: Team needs to learn ACM concepts and operations
5. **Maintenance**: Additional components to monitor and maintain

### Mitigations

1. **Documentation**: Comprehensive runbooks and troubleshooting guides
2. **Automation**: Ansible playbooks for common operations
3. **Monitoring**: Dedicated monitoring for ACM components
4. **Testing**: Comprehensive E2E tests for multi-cluster scenarios
5. **Training**: Team training on ACM operations

## Related ADRs

- **ADR-019**: Validated Patterns Framework Adoption
- **ADR-020**: Bootstrap Deployment and Deletion Lifecycle
- **ADR-021**: Tekton Pipeline for Post-Deployment Validation

## References

- [Red Hat Advanced Cluster Management Documentation](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/)
- [Validated Patterns Multi-Cluster Guide](https://validatedpatterns.io/learn/vp_openshift_framework/)
- [OpenShift GitOps ApplicationSet Documentation](https://argocd-applicationset.readthedocs.io/)
- [Hub-Spoke Architecture Patterns](https://en.wikipedia.org/wiki/Spoke%E2%80%93hub_distribution_paradigm)

## Approval

- **Architecture Team**: Approved
- **Date**: 2025-10-31
