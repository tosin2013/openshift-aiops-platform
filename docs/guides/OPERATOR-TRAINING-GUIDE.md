# Operator Training Guide - OpenShift AI Ops Self-Healing Platform

## Overview

This guide provides a comprehensive training roadmap for operators managing the OpenShift AI Ops Self-Healing Platform. It covers the essential skills, tools, and technologies needed to effectively operate, monitor, and troubleshoot the platform.

**Target Audience:**
- Site Reliability Engineers (SREs)
- Platform Engineers
- DevOps Engineers
- Operations Team Members

**Prerequisites:**
- Basic Linux administration
- Basic networking concepts
- Familiarity with containers and Kubernetes

## Required Skills Matrix

| Skill Area | Priority | Estimated Time | Resources |
|------------|----------|----------------|-----------|
| **OpenShift Fundamentals** | 🔴 Critical | 40 hours | Red Hat DO180, ADR-001 |
| **Machine Config Operator (MCO)** | 🟡 High | 16 hours | Red Hat Docs, ADR-005 |
| **NVIDIA GPU Operator** | 🟡 High | 8 hours | NVIDIA Docs, ADR-006 |
| **OpenShift AI (RHODS)** | 🔴 Critical | 40 hours | Red Hat DO374, ADR-003 |
| **KServe Model Serving** | 🟡 High | 16 hours | KServe Docs, ADR-004 |
| **Prometheus & PromQL** | 🔴 Critical | 24 hours | prometheus.io, ADR-007 |
| **Tekton Pipelines** | 🟢 Medium | 16 hours | tekton.dev, ADR-021 |
| **ArgoCD GitOps** | 🟢 Medium | 12 hours | argoproj.io, ADR-027 |
| **Jupyter Notebooks** | 🟡 High | 16 hours | jupyter.org, ADR-012 |
| **Coordination Engine** | 🟡 High | 8 hours | src/coordination-engine/README.md |

**Total Estimated Training Time**: ~196 hours (~5 weeks full-time)

---

## Training Path by Week

### Week 1: OpenShift & Kubernetes Fundamentals

#### Day 1-2: OpenShift Basics
**Learning Objectives:**
- Understand OpenShift architecture (control plane, workers, etcd)
- Navigate OpenShift Console
- Use `oc` CLI for basic operations
- Understand pods, deployments, services

**Hands-On Labs:**
```bash
# Lab 1.1: Explore cluster topology
oc get nodes
oc describe node <node-name>
oc get clusterversion

# Lab 1.2: Navigate namespaces
oc projects
oc get all -n self-healing-platform
oc get pods -A

# Lab 1.3: View logs and events
oc logs <pod-name> -f
oc describe pod <pod-name>
oc get events -n self-healing-platform --sort-by='.lastTimestamp'
```

**Resources:**
- **Red Hat DO180**: Introduction to Containers, Kubernetes, and Red Hat OpenShift
- **OpenShift Documentation**: https://docs.openshift.com/container-platform/4.18/

#### Day 3-4: Operators & Custom Resources
**Learning Objectives:**
- Understand Operator pattern
- Work with Custom Resource Definitions (CRDs)
- Manage operator subscriptions
- Troubleshoot operator issues

**Hands-On Labs:**
```bash
# Lab 1.4: List installed operators
oc get csv -n openshift-operators
oc get operators

# Lab 1.5: Explore CRDs
oc get crd | grep -E 'kserve|mlops|machineconfig'
oc describe crd inferenceservices.serving.kserve.io

# Lab 1.6: Check operator health
oc get pods -n openshift-operators
oc logs deployment/rhods-operator -n openshift-operators
```

**Key Operators in Platform:**
- Red Hat OpenShift AI Operator
- NVIDIA GPU Operator
- OpenShift GitOps Operator
- OpenShift Pipelines Operator
- KServe Controller

#### Day 5: RBAC & Security
**Learning Objectives:**
- Understand ServiceAccounts, Roles, RoleBindings
- Manage ClusterRoles and ClusterRoleBindings
- Troubleshoot permission issues

**Hands-On Labs:**
```bash
# Lab 1.7: Explore RBAC
oc get serviceaccounts -n self-healing-platform
oc describe rolebinding coordination-engine-binding -n self-healing-platform

# Lab 1.8: Check permissions
oc auth can-i list pods --as=system:serviceaccount:self-healing-platform:coordination-engine-sa
oc auth can-i create inferenceservices -n self-healing-platform

# Lab 1.9: Troubleshoot permission denied
oc get events -n self-healing-platform | grep "forbidden"
```

**Resources:**
- [ADR-033: Coordination Engine RBAC Permissions](../adrs/033-coordination-engine-rbac-permissions.md)

---

### Week 2: Prometheus Monitoring & PromQL

#### Day 1-2: Prometheus Fundamentals
**Learning Objectives:**
- Understand time-series data model
- Navigate Prometheus UI
- Write basic PromQL queries
- Understand metrics types (counter, gauge, histogram, summary)

**Hands-On Labs:**
```bash
# Lab 2.1: Access Prometheus UI
oc port-forward -n openshift-monitoring prometheus-k8s-0 9090:9090

# Navigate to http://localhost:9090
```

**Basic PromQL Queries:**
```promql
# Lab 2.2: Node metrics
# CPU usage by node
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage by node
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100
```

#### Day 3: Container & Pod Metrics
**Learning Objectives:**
- Query container resource usage
- Monitor pod health
- Track restarts and errors

**PromQL Practice:**
```promql
# Lab 2.3: Container metrics
# CPU usage by container
rate(container_cpu_usage_seconds_total{namespace="self-healing-platform"}[5m])

# Memory working set
container_memory_working_set_bytes{namespace="self-healing-platform"}

# Network I/O
rate(container_network_receive_bytes_total{namespace="self-healing-platform"}[5m])

# Pod restart rate
increase(kube_pod_container_status_restarts_total{namespace="self-healing-platform"}[1h])
```

#### Day 4: Aggregations & Functions
**Learning Objectives:**
- Use aggregation operators (sum, avg, max, min)
- Apply rate, increase, delta functions
- Calculate percentiles with histogram_quantile

**PromQL Advanced:**
```promql
# Lab 2.4: Aggregations
# Total CPU by namespace
sum by (namespace) (rate(container_cpu_usage_seconds_total[5m]))

# Average memory by pod
avg by (pod) (container_memory_working_set_bytes{namespace="self-healing-platform"})

# 95th percentile latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Top 5 CPU consumers
topk(5, rate(container_cpu_usage_seconds_total[5m]))
```

#### Day 5: Alerting Rules
**Learning Objectives:**
- Write alerting rules
- Understand alert severity levels
- Configure alert annotations

**Hands-On Labs:**
```bash
# Lab 2.5: View existing alerts
oc get prometheusrules -n self-healing-platform

# Lab 2.6: Create custom alert
cat <<EOF | oc apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: custom-alerts
  namespace: self-healing-platform
spec:
  groups:
  - name: self_healing
    rules:
    - alert: HighPodMemoryUsage
      expr: |
        container_memory_working_set_bytes{namespace="self-healing-platform"}
        / container_spec_memory_limit_bytes{namespace="self-healing-platform"} > 0.9
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ \$labels.pod }} high memory usage"
        description: "Memory usage is {{ \$value | humanizePercentage }}"
EOF
```

**Resources:**
- [ADR-007: Prometheus Monitoring Integration](../adrs/007-prometheus-monitoring-integration.md)
- **Prometheus Documentation**: https://prometheus.io/docs/prometheus/latest/querying/basics/
- **PromQL Cheat Sheet**: https://promlabs.com/promql-cheat-sheet/

---

### Week 3: Machine Learning Operations

#### Day 1-2: OpenShift AI (RHODS)
**Learning Objectives:**
- Navigate RHODS dashboard
- Create and manage workbenches
- Understand data science pipelines
- Configure notebook images

**Hands-On Labs:**
```bash
# Lab 3.1: Access RHODS dashboard
oc get route rhods-dashboard -n redhat-ods-applications

# Lab 3.2: List data science projects
oc get datasciencepipelinesapplications -A

# Lab 3.3: Check workbench status
oc get notebook self-healing-workbench -n self-healing-platform -o yaml
```

#### Day 3: KServe Model Serving
**Learning Objectives:**
- Understand InferenceService CRD
- Deploy models via KServe
- Test inference endpoints
- Monitor model performance

**Hands-On Labs:**
```bash
# Lab 3.4: List inference services
oc get inferenceservices -n self-healing-platform

# Lab 3.5: Check InferenceService status
oc describe inferenceservice anomaly-detector -n self-healing-platform

# Lab 3.6: Test inference endpoint
MODEL_URL=$(oc get inferenceservice anomaly-detector -n self-healing-platform \
  -o jsonpath='{.status.url}')

curl -X POST $MODEL_URL/v1/models/anomaly-detector:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[0.5, 0.3, 0.8]]}'
```

**Common Issues:**
```bash
# InferenceService not ready?
# Check predictor pod logs
oc logs -n self-healing-platform -l serving.kserve.io/inferenceservice=anomaly-detector

# Check events
oc get events -n self-healing-platform --field-selector involvedObject.name=anomaly-detector
```

#### Day 4: Jupyter Notebooks
**Learning Objectives:**
- Navigate Jupyter Lab
- Run ML training notebooks
- Understand notebook workflow
- Save models to PVC

**Hands-On Labs:**
```bash
# Lab 3.7: Access Jupyter workbench
oc port-forward self-healing-workbench-0 8888:8888 -n self-healing-platform

# Open http://localhost:8888

# Lab 3.8: Execute training notebook
# Navigate to: notebooks/02-anomaly-detection/01-isolation-forest-implementation.ipynb
# Execute all cells (Shift+Enter)

# Lab 3.9: Verify model saved
oc exec -it self-healing-workbench-0 -n self-healing-platform -- \
  ls -lh /opt/app-root/src/models/anomaly-detector/v1/
```

#### Day 5: GPU Management
**Learning Objectives:**
- Understand GPU Operator
- Monitor GPU utilization
- Troubleshoot GPU issues

**Hands-On Labs:**
```bash
# Lab 3.10: Check GPU availability
oc get nodes -l nvidia.com/gpu.present=true

# Lab 3.11: GPU metrics
# In Prometheus:
DCGM_FI_DEV_GPU_UTIL
DCGM_FI_DEV_MEM_COPY_UTIL
DCGM_FI_DEV_GPU_TEMP

# Lab 3.12: Verify GPU pod allocation
oc describe node <gpu-node> | grep -A 5 "nvidia.com/gpu"
```

**Resources:**
- [ADR-003: Red Hat OpenShift AI for ML Platform](../adrs/003-openshift-ai-ml-platform.md)
- [ADR-004: KServe for Model Serving Infrastructure](../adrs/004-kserve-model-serving.md)
- [ADR-006: NVIDIA GPU Operator](../adrs/006-nvidia-gpu-management.md)

---

### Week 4: CI/CD & Automation

#### Day 1-2: Tekton Pipelines
**Learning Objectives:**
- Understand Tekton architecture (Tasks, Pipelines, PipelineRuns)
- Run validation pipelines
- Monitor pipeline execution
- Debug failed pipeline runs

**Hands-On Labs:**
```bash
# Lab 4.1: List pipelines
tkn pipeline list -n openshift-pipelines

# Lab 4.2: Run deployment validation
tkn pipeline start deployment-validation-pipeline \
  -p namespace=self-healing-platform \
  -p cluster-version=4.18 \
  -n openshift-pipelines \
  --showlog

# Lab 4.3: View pipeline run history
tkn pipelinerun list -n openshift-pipelines

# Lab 4.4: Check task logs
tkn taskrun logs <taskrun-name> -n openshift-pipelines
```

**Common Issues:**
```bash
# Pipeline stuck in pending?
oc get pipelinerun <run-name> -n openshift-pipelines -o yaml | grep -A 10 status

# Check pod logs
oc logs -n openshift-pipelines -l tekton.dev/pipelineRun=<run-name>
```

#### Day 3: ArgoCD GitOps
**Learning Objectives:**
- Understand GitOps principles
- Navigate ArgoCD UI
- Sync applications
- Troubleshoot out-of-sync applications

**Hands-On Labs:**
```bash
# Lab 4.5: Access ArgoCD UI
oc get route openshift-gitops-server -n openshift-gitops

# Lab 4.6: List ArgoCD applications
oc get applications -n openshift-gitops

# Lab 4.7: Check sync status
oc describe application self-healing-platform -n openshift-gitops

# Lab 4.8: Manual sync
argocd app sync self-healing-platform
```

#### Day 4-5: Coordination Engine
**Learning Objectives:**
- Understand hybrid self-healing approach
- Monitor coordination engine
- Submit anomalies via API
- Troubleshoot conflict resolution

**Hands-On Labs:**
```bash
# Lab 4.9: Check coordination engine health
curl http://coordination-engine.self-healing-platform.svc:8080/health

# Lab 4.10: View engine status
curl http://coordination-engine.self-healing-platform.svc:8080/api/v1/status | jq

# Lab 4.11: Submit test anomaly
curl -X POST http://coordination-engine:8080/api/v1/anomalies \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2025-12-10T14:30:00Z",
    "type": "test",
    "severity": "low",
    "confidence_score": 0.95,
    "source": "manual_test"
  }'

# Lab 4.12: Monitor metrics
curl http://coordination-engine:8080/metrics | grep coordination
```

**Resources:**
- [ADR-002: Hybrid Deterministic-AI Self-Healing Approach](../adrs/002-hybrid-self-healing-approach.md)
- [ADR-021: Tekton Pipeline for Post-Deployment Validation](../adrs/021-tekton-pipeline-deployment-validation.md)
- [ADR-027: CI/CD Pipeline Automation](../adrs/027-cicd-pipeline-automation.md)
- [Coordination Engine README](../../src/coordination-engine/README.md)

---

### Week 5: Advanced Topics & Troubleshooting

#### Day 1: Machine Config Operator (MCO)
**Learning Objectives:**
- Understand MachineConfig and MachineConfigPool
- Apply node-level configurations
- Monitor MCO updates
- Troubleshoot MCO issues

**Hands-On Labs:**
```bash
# Lab 5.1: List machine configs
oc get machineconfig

# Lab 5.2: Check machine config pools
oc get machineconfigpool

# Lab 5.3: View rendered config
oc get machineconfig rendered-worker-<hash> -o yaml

# Lab 5.4: Monitor MCO updates
oc get nodes -w
oc get mcp -w
```

**Resources:**
- [ADR-005: Machine Config Operator for Node-Level Automation](../adrs/005-machine-config-operator-automation.md)

#### Day 2: Storage & Data Management
**Learning Objectives:**
- Understand OpenShift Data Foundation (ODF)
- Manage PVCs and storage classes
- Monitor storage utilization
- Troubleshoot storage issues

**Hands-On Labs:**
```bash
# Lab 5.5: Check storage classes
oc get storageclass

# Lab 5.6: List PVCs
oc get pvc -n self-healing-platform

# Lab 5.7: Check ODF health
oc get cephcluster -n openshift-storage

# Lab 5.8: Storage metrics (Prometheus)
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes
```

#### Day 3: Secrets Management
**Learning Objectives:**
- Understand External Secrets Operator
- Manage secrets backends (Vault, AWS)
- Troubleshoot secret sync issues

**Hands-On Labs:**
```bash
# Lab 5.9: Check external secrets
oc get externalsecrets -n self-healing-platform

# Lab 5.10: Check secret stores
oc get secretstore -n self-healing-platform

# Lab 5.11: Verify secret sync
oc describe externalsecret coordination-engine-credentials -n self-healing-platform
```

**Resources:**
- [ADR-026: Secrets Management Automation](../adrs/026-secrets-management-automation.md)

#### Day 4: Incident Response
**Learning Objectives:**
- Respond to platform alerts
- Perform root cause analysis
- Execute remediation procedures
- Document incidents

**Incident Response Checklist:**
```markdown
## Incident Response Procedure

### 1. Alert Triage (5 min)
- [ ] Check Prometheus alerts: `oc get prometheusrule -A`
- [ ] Check AlertManager: `oc get alertmanagers -A`
- [ ] Assess severity (P1-Critical, P2-High, P3-Medium, P4-Low)

### 2. Initial Investigation (10 min)
- [ ] Check affected components: `oc get pods -A | grep -v Running`
- [ ] Review recent events: `oc get events -A --sort-by='.lastTimestamp' | tail -50`
- [ ] Check coordination engine logs: `oc logs deployment/coordination-engine -n self-healing-platform --tail=100`

### 3. Gather Context (10 min)
- [ ] Prometheus metrics around incident time
- [ ] Recent deployments: `oc get events -A | grep -E 'Deploy|Sync'`
- [ ] Resource utilization: CPU/Memory/Storage metrics

### 4. Remediation (varies)
- [ ] Execute automated remediation (if available)
- [ ] Manual intervention (if required)
- [ ] Verify fix: Check metrics, logs, health endpoints

### 5. Post-Incident (30 min)
- [ ] Document root cause
- [ ] Update runbooks
- [ ] Create follow-up tasks
```

#### Day 5: Performance Tuning
**Learning Objectives:**
- Identify performance bottlenecks
- Optimize resource allocation
- Tune operator configurations

**Performance Tuning Labs:**
```bash
# Lab 5.12: Resource utilization analysis
# Top CPU consumers
kubectl top pods -A --sort-by=cpu

# Top memory consumers
kubectl top pods -A --sort-by=memory

# Lab 5.13: Identify slow queries (Prometheus)
topk(10, rate(prometheus_rule_evaluation_duration_seconds_sum[5m]) /
         rate(prometheus_rule_evaluation_duration_seconds_count[5m]))
```

---

## Certification Paths

### Recommended Certifications

| Certification | Relevance | Difficulty | Time Investment |
|---------------|-----------|------------|-----------------|
| **Red Hat Certified Specialist in OpenShift Administration (EX280)** | High | Medium | 80-120 hours |
| **Certified Kubernetes Administrator (CKA)** | High | Medium | 60-80 hours |
| **Red Hat Certified Specialist in AI/ML** | Medium | Medium | 40-60 hours |
| **Prometheus Certified Associate (PCA)** | Medium | Low | 20-30 hours |

### Study Resources

**Red Hat Training:**
- **DO180**: Introduction to Containers, Kubernetes, and Red Hat OpenShift
- **DO280**: OpenShift Administration II
- **DO374**: Developing Applications with Red Hat OpenShift AI

**Online Resources:**
- **Prometheus.io**: Official Prometheus documentation
- **KServe Docs**: https://kserve.github.io/website/
- **Tekton Tutorials**: https://tekton.dev/docs/getting-started/
- **ArgoCD University**: https://argo-cd.readthedocs.io/en/stable/

---

## Internal Training Schedule

### Monthly Workshops

#### "PromQL Office Hours" (2 hours, 2nd Tuesday each month)
- **Format**: Interactive Q&A session
- **Topics**: Real-world PromQL queries, alerting best practices
- **Facilitator**: Senior SRE
- **Location**: Conference Room / Virtual

#### "Platform Deep Dive" (1 hour, Last Friday each month)
- **Format**: Tech talk + demo
- **Topics**: Rotate through platform components
- **Schedule**:
  - January: Coordination Engine internals
  - February: KServe model deployment workflow
  - March: Tekton pipeline debugging
  - April: GPU troubleshooting
  - (Repeat)

### Quarterly Training

#### "Self-Healing Platform Bootcamp" (1 full day, quarterly)
- **Format**: Hands-on workshop
- **Audience**: New team members, refresher for existing
- **Curriculum**:
  - Morning: Platform architecture overview
  - Afternoon: Hands-on labs (Weeks 1-5 condensed)
  - Evening: Incident simulation exercise

### On-Demand Resources

#### Jupyter Notebook Walkthroughs (30+ notebooks)
- **Access**: OpenShift AI workbench
- **Location**: `notebooks/` directory
- **Self-paced**: Execute notebooks, read inline documentation

#### Video Tutorials (Coming Soon)
- [ ] "Your First PromQL Query"
- [ ] "Deploying a Model to KServe"
- [ ] "Debugging Failed Pipelines"
- [ ] "Coordination Engine API Tutorial"

---

## Skills Assessment

### Self-Assessment Checklist

**OpenShift Fundamentals:**
- [ ] I can navigate the OpenShift Console fluently
- [ ] I understand the difference between Projects and Namespaces
- [ ] I can troubleshoot pod failures using `oc describe` and `oc logs`
- [ ] I understand RBAC (ServiceAccounts, Roles, RoleBindings)

**Prometheus & Monitoring:**
- [ ] I can write basic PromQL queries for CPU/memory/network
- [ ] I understand rate(), increase(), and aggregation functions
- [ ] I can create custom alert rules
- [ ] I can interpret Prometheus metrics in Grafana

**Machine Learning Operations:**
- [ ] I understand how to access and use Jupyter notebooks
- [ ] I can deploy a model to KServe
- [ ] I can test inference endpoints
- [ ] I understand GPU allocation and monitoring

**Automation & CI/CD:**
- [ ] I can run Tekton pipelines manually
- [ ] I understand ArgoCD sync and health status
- [ ] I can interact with the Coordination Engine API
- [ ] I understand the hybrid self-healing approach

**Advanced Topics:**
- [ ] I can apply node configurations via MCO
- [ ] I understand External Secrets Operator
- [ ] I can respond to platform incidents effectively
- [ ] I can identify and resolve performance bottlenecks

### Hands-On Assessment (2 hours)

**Scenario-Based Exam:**
1. **Incident Response** (30 min): Respond to simulated platform outage
2. **Troubleshooting** (30 min): Debug failing InferenceService
3. **PromQL Challenge** (30 min): Write queries for specific monitoring requirements
4. **Deployment** (30 min): Deploy and validate a new model version

**Pass Criteria:**
- Successfully complete 3 out of 4 scenarios
- Demonstrate proper troubleshooting methodology
- Use appropriate tools and commands

---

## Continuous Learning

### Stay Updated

**Weekly:**
- [ ] Review platform alerts and incidents
- [ ] Read Kubernetes/OpenShift release notes
- [ ] Check platform metrics dashboards

**Monthly:**
- [ ] Attend internal workshops
- [ ] Review ADR updates
- [ ] Practice PromQL queries

**Quarterly:**
- [ ] Complete hands-on lab refresher
- [ ] Review certification requirements
- [ ] Evaluate new tools and technologies

### Knowledge Sharing

**Best Practices:**
- Document troubleshooting procedures in runbooks
- Share useful PromQL queries in team wiki
- Present "lessons learned" from incidents
- Contribute to ADR creation and updates

---

## Getting Help

### Internal Resources

| Resource | Contact | Response Time |
|----------|---------|---------------|
| **Platform Team Slack** | #aiops-platform | < 1 hour (business hours) |
| **On-Call Escalation** | PagerDuty | Immediate (24/7) |
| **Documentation** | docs/ directory | Self-service |
| **Training Questions** | platform-training@company.com | < 24 hours |

### External Resources

| Resource | URL | Use Case |
|----------|-----|----------|
| **Red Hat Support** | access.redhat.com | OpenShift issues |
| **OpenShift Forums** | discuss.okd.io | Community questions |
| **KServe Slack** | kubeflow.slack.com #kserve | Model serving questions |
| **CNCF Slack** | cloud-native.slack.com | General K8s questions |

---

## Appendix: Quick Reference

### Essential Commands Cheat Sheet

```bash
# Cluster Health
oc get nodes
oc get clusterversion
oc adm top nodes

# Platform Components
oc get pods -n self-healing-platform
oc get inferenceservices -n self-healing-platform
oc get pipelines -n openshift-pipelines
oc get applications -n openshift-gitops

# Troubleshooting
oc logs <pod-name> -f
oc describe pod <pod-name>
oc get events -n <namespace> --sort-by='.lastTimestamp'
oc debug node/<node-name>

# Prometheus Access
oc port-forward -n openshift-monitoring prometheus-k8s-0 9090:9090

# Coordination Engine
curl http://coordination-engine:8080/health
curl http://coordination-engine:8080/api/v1/status

# Model Serving
oc get inferenceservice -n self-healing-platform
tkn pipeline start model-serving-validation-pipeline -n openshift-pipelines
```

### PromQL Quick Reference

```promql
# CPU
rate(container_cpu_usage_seconds_total[5m])

# Memory
container_memory_working_set_bytes

# Network
rate(container_network_receive_bytes_total[5m])

# Disk
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes

# Pod Restarts
increase(kube_pod_container_status_restarts_total[1h])

# GPU Utilization
DCGM_FI_DEV_GPU_UTIL
```

---

## License

This training guide is part of the OpenShift AI Ops Self-Healing Platform.

**License**: GNU General Public License v3.0

**Version**: 1.0
**Last Updated**: 2025-12-10
**Contributors**: Platform Engineering Team
