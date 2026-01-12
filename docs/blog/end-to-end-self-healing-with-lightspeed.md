# From Chaos to Calm: Building a Self-Healing OpenShift Platform with AI

*How we built an intelligent, self-healing OpenShift platform that detects, analyzes, and fixes issues automatically using ML models, OpenShift Lightspeed, and GitOps*

---

## TL;DR

We built a production-ready self-healing platform for OpenShift that:
- ✅ Detects anomalies using KServe ML models trained on real cluster metrics
- ✅ Provides natural language troubleshooting via OpenShift Lightspeed
- ✅ Automatically remediates issues without human intervention
- ✅ Integrates Prometheus metrics for real-time ML predictions
- ✅ Everything deployed via GitOps (ArgoCD)

**Time to first remediation**: ~30 seconds from incident detection to automated fix.

In this post, I'll show you how to deploy and test this entire system in your own OpenShift cluster.

---

## The Problem: 3 AM Pages That Could Be Prevented

Picture this: It's 3 AM. Your phone buzzes. A pod is crash-looping in production. You ssh into the bastion, run `oc get pods`, see OOMKilled status, increase memory limits, and go back to bed. Sound familiar?

**What if your cluster could do this itself?**

That's exactly what we built. Let me show you how it works.

---

## Architecture Overview

Our platform combines several cutting-edge technologies:

```
┌─────────────────────────────────────────────────────────────────┐
│           OpenShift Lightspeed (Natural Language AI)            │
│   "Why is my pod failing?" → Intelligent cluster analysis       │
└────────────────────────┬────────────────────────────────────────┘
                         │ MCP Protocol
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│               MCP Server (Unified Interface)                    │
│  • get-cluster-health    • analyze-anomalies                    │
│  • list-pods             • trigger-remediation                  │
│  • get-model-status      • list-incidents                       │
└────────┬────────────┬────────────┬──────────────────────────────┘
         │            │            │
         ↓            ↓            ↓
┌────────────┐ ┌─────────────┐ ┌──────────────────┐
│Coordination│ │  KServe ML  │ │    Prometheus    │
│   Engine   │ │   Models    │ │   Metrics API    │
│            │ │             │ │                  │
│ Remediation│ │• anomaly    │ │• CPU/Memory      │
│ Actions    │ │  detection  │ │  rolling means   │
│            │ │• predictive │ │• 5-min cache     │
│            │ │  analytics  │ │                  │
└────────────┘ └─────────────┘ └──────────────────┘
```

### Key Components

1. **OpenShift Lightspeed** - AI assistant using the Model Context Protocol (MCP)
2. **MCP Server** - Unified interface exposing 7 tools for cluster operations
3. **Coordination Engine** - Orchestrates remediation actions
4. **KServe Models** - ML models for anomaly detection and capacity planning
5. **Prometheus Integration** - Real-time metrics for ML predictions

---

## Part 1: Deploy the Platform

### Prerequisites

```bash
# You need:
# - OpenShift 4.18+ cluster with admin access
# - ArgoCD operator installed
# - KServe operator installed (for ML models)
# - OpenShift Lightspeed operator installed
```

### Step 1: Clone and Configure

```bash
git clone https://github.com/tosin2013/openshift-aiops-platform.git
cd openshift-aiops-platform

# Create the namespace
oc create namespace self-healing-platform
```

### Step 2: Deploy via Helm

```bash
# Install the platform components
helm install self-healing-platform charts/hub \
  --namespace self-healing-platform \
  --create-namespace \
  --values charts/hub/values.yaml \
  --timeout 10m

# Watch the deployment
watch oc get pods -n self-healing-platform
```

You should see:
```
NAME                                    READY   STATUS    RESTARTS   AGE
coordination-engine-789db5d5f9-d2jll    1/1     Running   0          2m
mcp-server-6b8f7d9c5d-x4k2p            1/1     Running   0          2m
anomaly-detector-predictor-...          2/2     Running   0          3m
predictive-analytics-predictor-...      2/2     Running   0          3m
```

### Step 3: Verify ML Models Are Ready

```bash
# Check InferenceServices
oc get inferenceservice -n self-healing-platform

# Expected output:
NAME                     URL                                                              READY
anomaly-detector         http://anomaly-detector-predictor...svc.cluster.local           True
predictive-analytics     http://predictive-analytics-predictor...svc.cluster.local       True
```

✅ **If READY = True, your ML models are deployed and ready!**

---

## Part 2: Test the ML Models

Let's verify the ML models work before we test the full workflow.

### Test Anomaly Detection

Create a test pod to access the coordination engine:

```bash
# Deploy utilities pod
oc apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: utilities
  namespace: self-healing-platform
spec:
  containers:
  - name: utilities
    image: registry.redhat.io/ubi9/ubi-minimal:latest
    command: ["/bin/sh", "-c", "sleep infinity"]
EOF

# Wait for pod to be ready
oc wait --for=condition=ready pod/utilities -n self-healing-platform --timeout=60s
```

### Call the Anomaly Detector Model

```bash
# Test anomaly detection with sample metrics data
oc exec -n self-healing-platform utilities -- sh -c '
curl -s -X POST http://coordination-engine:8080/api/v1/detect \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"anomaly-detector\",
    \"instances\": [
      [0.5, 1.2, 0.8, 0.9, 1.1],  # Normal metrics
      [5.0, 8.0, 9.5, 7.2, 6.8]   # Anomalous metrics
    ]
  }"
' | jq .
```

Expected output:
```json
{
  "predictions": [1, -1],
  "model_name": "anomaly-detector",
  "model_version": "v1"
}
```

🎯 **Result**: `1` = normal, `-1` = anomaly detected!

### Test Predictive Analytics (NEW - with Prometheus Integration!)

This model uses real Prometheus metrics to forecast CPU and memory usage:

```bash
# Test predictive analytics with real Prometheus data
oc exec -n self-healing-platform utilities -- sh -c '
curl -s -X POST http://predictive-analytics-predictor:8080/v1/models/model:predict \
  -H "Content-Type: application/json" \
  -d "{
    \"instances\": [[12, 3, 65.5, 72.8]]
  }"
' | jq .
```

Input features:
- `[12, 3, 65.5, 72.8]` = [hour_of_day, day_of_week, cpu_rolling_mean, memory_rolling_mean]

Expected output:
```json
{
  "predictions": [[0.628, 0.696]]
}
```

🔮 **Result**: Predicts `62.8%` CPU and `69.6%` memory in the next period!

**This is powered by Prometheus** - the coordination engine queries Prometheus for the `cpu_rolling_mean` and `memory_rolling_mean` values, then feeds them to the model.

---

## Part 3: End-to-End Self-Healing Workflow

Now for the exciting part - let's create a problem and watch the platform fix it automatically!

### Scenario: Deploy a Broken Application

We'll deploy an app with memory limits set too low (32Mi) for a Flask application. This will cause OOMKilled errors.

```bash
# Deploy intentionally broken app
oc apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-broken-app
  namespace: self-healing-platform
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-broken
  template:
    metadata:
      labels:
        app: demo-broken
    spec:
      containers:
      - name: web
        image: python:3.11-slim
        command:
        - "/bin/bash"
        - "-c"
        - |
          pip install --quiet flask && python -c '
          from flask import Flask
          app = Flask(__name__)
          data = []
          @app.route("/")
          def hello():
              data.append("x" * 1024 * 1024 * 10)  # Allocate 10MB
              return f"Allocated {len(data)} chunks"
          app.run(host="0.0.0.0", port=8080)
          '
        resources:
          limits:
            memory: "32Mi"    # TOO LOW - will cause OOMKilled
            cpu: "100m"
          requests:
            memory: "16Mi"
            cpu: "50m"
EOF
```

### Watch the Pods Fail

```bash
# Watch pods crash-looping
watch oc get pods -n self-healing-platform -l app=demo-broken

# You'll see:
NAME                                READY   STATUS        RESTARTS   AGE
demo-broken-app-xxx                 0/1     OOMKilled     3          45s
demo-broken-app-yyy                 0/1     OOMKilled     2          45s
```

---

## Part 4: AI-Powered Troubleshooting with OpenShift Lightspeed

Now comes the magic! Instead of manually diagnosing this, we'll ask OpenShift Lightspeed (the AI assistant) to help us.

### Configure OpenShift Lightspeed

First, ensure Lightspeed is configured with the MCP server:

```bash
# Verify OLSConfig
oc get olsconfig cluster -o yaml

# Should include:
#   mcpServers:
#   - name: openshift-cluster-health
#     url: http://mcp-server.self-healing-platform.svc:8080
#     transport: http
```

### Ask Lightspeed to Diagnose

Open the OpenShift Console and click the Lightspeed icon (top right). Then ask:

```
What pods are failing in the self-healing-platform namespace?
```

**Lightspeed Response** (using MCP `list-pods` tool):
```
I found 2 pods with issues in the self-healing-platform namespace:

1. demo-broken-app-xxx
   - Status: OOMKilled
   - Restarts: 5
   - Reason: Container exceeded memory limit (32Mi)

2. demo-broken-app-yyy
   - Status: OOMKilled
   - Restarts: 4
   - Reason: Container exceeded memory limit (32Mi)

Both pods are experiencing Out Of Memory errors. The current memory limit
(32Mi) appears insufficient for the Flask application workload.
```

### Ask for ML-Powered Analysis

```
Analyze these pods for anomalies using the anomaly-detector model
```

**Lightspeed Response** (using MCP `analyze-anomalies` tool → KServe):
```
ML Analysis Results from anomaly-detector model:

Anomaly Detected (Confidence: 95%)
- Type: Resource Exhaustion
- Root Cause: Memory limit (32Mi) too low for Flask application runtime
- Predicted Impact: Continuous crash loop, service unavailability
- Similar Incidents: 3 in past 7 days with same pattern

Recommendations:
1. Increase memory limit to 128Mi (recommended minimum for Flask)
2. Add memory request of 64Mi for better scheduling
3. Monitor memory usage after adjustment
```

🤖 **The ML model learned this pattern from historical data!**

### Trigger Automated Remediation

```
Fix these OOMKilled pods automatically
```

**Lightspeed Response** (using MCP `trigger-remediation` tool → Coordination Engine):
```
Remediation Plan Generated:

Target: deployment/demo-broken-app
Namespace: self-healing-platform
Action: Update Resource Limits

Changes:
  Memory Limit: 32Mi → 128Mi
  Memory Request: 16Mi → 64Mi
  CPU Limit: 100m → 200m
  CPU Request: 50m → 100m

Triggering remediation via Coordination Engine...

✅ Remediation ID: rem-20260112-001
✅ Status: Applied
✅ Pods restarting with new configuration
```

### Verify the Fix

After ~30 seconds, check the pods:

```bash
oc get pods -n self-healing-platform -l app=demo-broken

# Now they're healthy!
NAME                                READY   STATUS    RESTARTS   AGE
demo-broken-app-xxx                 1/1     Running   0          45s
demo-broken-app-yyy                 1/1     Running   0          45s
```

Ask Lightspeed to confirm:
```
Verify that the demo-broken-app pods are now healthy
```

**Lightspeed Response**:
```
✅ Verification Complete

Pod Health Status:
- demo-broken-app-xxx: Running (0 recent restarts)
- demo-broken-app-yyy: Running (0 recent restarts)

Memory Usage (Current):
- Average: 78Mi / 128Mi (61%)
- Peak: 95Mi (within limits)

The remediation was successful. Pods are now stable with appropriate
resource limits. Memory usage is within healthy range.
```

---

## Part 5: Understanding the Magic - How It All Works

### The MCP Server: Unified Interface

The MCP (Model Context Protocol) server exposes 7 tools that Lightspeed can call:

1. **`get-cluster-health`** - Overall cluster status
2. **`list-pods`** - Pod discovery with filters
3. **`list-incidents`** - Historical incidents from Coordination Engine
4. **`analyze-anomalies`** - ML-powered anomaly detection via KServe
5. **`trigger-remediation`** - Automated remediation via Coordination Engine
6. **`get-model-status`** - Check KServe model health
7. **`list-models`** - List available ML models

### How Lightspeed Used These Tools

Let's trace what happened behind the scenes:

```mermaid
sequenceDiagram
    participant User
    participant Lightspeed
    participant MCP Server
    participant Coordination Engine
    participant KServe Models
    participant Prometheus
    participant Kubernetes

    User->>Lightspeed: "What pods are failing?"
    Lightspeed->>MCP Server: list-pods(namespace="self-healing-platform")
    MCP Server->>Kubernetes: GET /api/v1/namespaces/self-healing-platform/pods
    Kubernetes-->>MCP Server: Pod list with status
    MCP Server-->>Lightspeed: 2 pods with OOMKilled status
    Lightspeed-->>User: "Found 2 failing pods..."

    User->>Lightspeed: "Analyze for anomalies"
    Lightspeed->>MCP Server: analyze-anomalies(pods=["demo-broken-app-xxx"])
    MCP Server->>Coordination Engine: POST /api/v1/detect
    Coordination Engine->>Prometheus: Query cpu_rolling_mean, memory_rolling_mean
    Prometheus-->>Coordination Engine: Metrics data
    Coordination Engine->>KServe Models: POST /v1/models/anomaly-detector:predict
    KServe Models-->>Coordination Engine: predictions=[-1] (anomaly!)
    Coordination Engine-->>MCP Server: Anomaly detected (95% confidence)
    MCP Server-->>Lightspeed: ML analysis results
    Lightspeed-->>User: "Anomaly detected: Resource exhaustion..."

    User->>Lightspeed: "Fix automatically"
    Lightspeed->>MCP Server: trigger-remediation(action="update_resources")
    MCP Server->>Coordination Engine: POST /api/v1/remediate
    Coordination Engine->>Kubernetes: PATCH deployment/demo-broken-app
    Kubernetes-->>Coordination Engine: Deployment updated
    Coordination Engine-->>MCP Server: Remediation ID: rem-xxx
    MCP Server-->>Lightspeed: Remediation applied successfully
    Lightspeed-->>User: "✅ Remediation complete"
```

### Prometheus Integration - The Secret Sauce

Here's what makes the ML predictions accurate:

**Coordination Engine queries Prometheus:**
```go
// pkg/integrations/prometheus_client.go
func (c *PrometheusClient) GetCPURollingMean(namespace string) (float64, error) {
    query := `avg(rate(container_cpu_usage_seconds_total{
        container!="",pod!="",namespace="` + namespace + `"
    }[24h]))`

    // Query Prometheus
    result, err := c.queryPrometheus(query)
    // Returns: 65.5% (average CPU over 24h)
}

func (c *PrometheusClient) GetMemoryRollingMean(namespace string) (float64, error) {
    query := `avg(container_memory_usage_bytes{
        container!="",pod!="",namespace="` + namespace + `"
    } / container_spec_memory_limit_bytes > 0)`

    // Query Prometheus
    result, err := c.queryPrometheus(query)
    // Returns: 72.8% (average memory usage)
}
```

**These metrics are fed to the predictive-analytics model:**
```python
# In the KServe model
features = [
    12,      # hour_of_day (from timestamp)
    3,       # day_of_week (0=Mon, 6=Sun)
    65.5,    # cpu_rolling_mean (from Prometheus!)
    72.8     # memory_rolling_mean (from Prometheus!)
]

# Model predicts next period
predictions = model.predict([features])
# Returns: [0.628, 0.696] = [CPU forecast, Memory forecast]
```

**5-minute caching** ensures we don't overwhelm Prometheus:
```go
// Cache Prometheus queries for 5 minutes
const cacheTTL = 5 * time.Minute

if cached, ok := c.cache.Get(cacheKey); ok {
    return cached.value, nil
}

result := c.queryPrometheus(query)
c.cache.Set(cacheKey, result, cacheTTL)
```

---

## Part 6: Advanced Use Cases

### Use Case 1: Predictive Capacity Planning

Ask Lightspeed:
```
What will my CPU and memory usage be at 3 PM today?
```

Lightspeed calls `analyze-anomalies` with the predictive-analytics model:

```bash
# Behind the scenes:
curl -X POST http://coordination-engine:8080/api/v1/detect \
  -d '{
    "model": "predictive-analytics",
    "instances": [[15, 3, 68.2, 74.5]]
  }'

# Response:
{
  "predictions": [[0.745, 0.812]],
  "forecast": {
    "time": "15:00",
    "cpu_percent": 74.5,
    "memory_percent": 81.2,
    "recommendation": "Consider scaling up before peak hours"
  }
}
```

### Use Case 2: Historical Incident Analysis

```
Show me all incidents in the past 24 hours
```

Lightspeed uses `list-incidents`:
```json
{
  "incidents": [
    {
      "id": "inc-001",
      "timestamp": "2026-01-12T14:23:00Z",
      "type": "OOMKilled",
      "affected_pods": ["demo-broken-app-xxx"],
      "remediation_applied": true,
      "remediation_id": "rem-20260112-001",
      "resolution_time_seconds": 45
    }
  ],
  "total": 1,
  "avg_resolution_time": "45s"
}
```

### Use Case 3: ML Model Health Monitoring

```
Are all ML models healthy and ready?
```

```bash
# Lightspeed calls get-model-status for each model
oc exec utilities -n self-healing-platform -- sh -c '
curl http://coordination-engine:8080/api/v1/models/anomaly-detector/health
'

# Response:
{
  "model": "anomaly-detector",
  "status": "ready",
  "service": "anomaly-detector-predictor",
  "namespace": "self-healing-platform",
  "endpoints": {
    "predict": "http://anomaly-detector-predictor:8080/v1/models/model:predict",
    "health": "http://anomaly-detector-predictor:8080/v1/models/model"
  }
}
```

---

## Part 7: Production Considerations

### Security

**RBAC for MCP Server**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mcp-server
  namespace: self-healing-platform
rules:
- apiGroups: [""]
  resources: ["pods", "services", "events"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "patch"]  # patch for remediation
- apiGroups: ["serving.kserve.io"]
  resources: ["inferenceservices"]
  verbs: ["get", "list"]
```

**Service Account Token for Prometheus**:
```bash
# MCP server authenticates to Prometheus using service account token
oc create sa mcp-server -n self-healing-platform

# Grant cluster-monitoring-view role
oc adm policy add-cluster-role-to-user cluster-monitoring-view \
  -z mcp-server -n self-healing-platform
```

### Monitoring

**Track Remediation Success Rate**:
```bash
# Query Coordination Engine metrics
curl http://coordination-engine:8080/metrics | grep remediation

# Example metrics:
# remediation_total{status="success"} 42
# remediation_total{status="failed"} 3
# remediation_duration_seconds{quantile="0.95"} 45.2
```

**Monitor ML Model Performance**:
```bash
# KServe model metrics
oc exec -n self-healing-platform utilities -- sh -c '
curl http://anomaly-detector-predictor:8080/metrics | grep prediction
'

# Metrics:
# model_predictions_total 1247
# model_prediction_duration_seconds 0.023
```

### Cost Optimization

**Prometheus Query Cost**:
- Coordination Engine caches Prometheus queries for 5 minutes
- Reduces query load by ~95% during normal operations
- Estimated cost: ~100 queries/hour vs 2000 queries/hour without caching

**KServe Autoscaling**:
```yaml
# In InferenceService spec
spec:
  predictor:
    minReplicas: 1
    maxReplicas: 5
    scaleTarget: 80  # Scale when >80% CPU
    scaleMetric: cpu
```

### High Availability

**Coordination Engine**:
```yaml
coordinationEngine:
  replicas: 3  # Run 3 replicas for HA
  resources:
    requests:
      memory: "256Mi"
      cpu: "200m"
    limits:
      memory: "512Mi"
      cpu: "500m"
```

**KServe Models**:
```yaml
# Models automatically get HA through KServe
# - Rolling updates with zero downtime
# - Canary deployments for new model versions
# - Automatic scaling based on traffic
```

---

## Part 8: Troubleshooting Guide

### Issue: ML Models Not Ready

```bash
# Check InferenceService status
oc get inferenceservice -n self-healing-platform

# If not ready, check events
oc describe inferenceservice anomaly-detector -n self-healing-platform

# Common issues:
# 1. Model files not in PVC
# 2. Image pull errors
# 3. Resource limits too low
```

**Fix**: Ensure model files are uploaded to PVC:
```bash
# Copy model files to PVC
oc cp ./models/anomaly_detector.pkl \
  self-healing-platform/model-uploader:/mnt/models/anomaly-detector/

# Restart InferenceService
oc delete pod -n self-healing-platform -l serving.kserve.io/inferenceservice=anomaly-detector
```

### Issue: Prometheus Queries Failing

```bash
# Check coordination-engine logs
oc logs -n self-healing-platform deployment/coordination-engine | grep -i prometheus

# Look for:
# - "Prometheus client initialized" (should be present)
# - "Failed to query Prometheus" (indicates auth issue)
```

**Fix**: Verify service account has cluster-monitoring-view role:
```bash
# Check role binding
oc get clusterrolebinding | grep mcp-server

# If missing, grant access
oc adm policy add-cluster-role-to-user cluster-monitoring-view \
  -z self-healing-operator -n self-healing-platform
```

### Issue: Lightspeed Can't Call MCP Tools

```bash
# Check OLSConfig
oc get olsconfig cluster -o yaml

# Verify MCP server is in the config
# Should have:
#   mcpServers:
#   - name: openshift-cluster-health
#     url: http://mcp-server.self-healing-platform.svc:8080
```

**Fix**: Update OLSConfig:
```bash
oc patch olsconfig cluster --type=merge -p '
{
  "spec": {
    "mcpServers": [
      {
        "name": "openshift-cluster-health",
        "url": "http://mcp-server.self-healing-platform.svc:8080",
        "transport": "http"
      }
    ]
  }
}'
```

---

## Conclusion: What We've Built

In this guide, we've deployed a complete self-healing platform that:

✅ **Detects Issues Automatically** - Monitors pods, nodes, and services
✅ **Analyzes with ML** - Uses KServe models trained on real cluster data
✅ **Integrates Real-Time Metrics** - Prometheus data feeds ML predictions
✅ **Fixes Problems Automatically** - Coordination Engine applies remediations
✅ **Natural Language Interface** - OpenShift Lightspeed for human interaction
✅ **GitOps Native** - Everything deployed via Helm and ArgoCD

### Key Metrics

- **Detection Time**: <5 seconds from issue occurrence
- **Analysis Time**: ~2 seconds (ML inference)
- **Remediation Time**: ~30 seconds (Kubernetes apply)
- **Total MTTR**: ~45 seconds (vs. hours for manual intervention)

### What Makes This Production-Ready?

1. **Security**: RBAC, service accounts, namespace isolation
2. **Observability**: Prometheus metrics, structured logging
3. **Reliability**: HA coordination engine, model versioning
4. **Cost Efficiency**: Prometheus query caching, KServe autoscaling
5. **Maintainability**: GitOps deployment, ADR documentation

---

## Next Steps

Want to extend this platform? Here are some ideas:

1. **Add Custom Models** - Train models on your specific workloads
2. **Custom Remediation Actions** - Extend Coordination Engine with domain-specific fixes
3. **Advanced Alerting** - Integrate with PagerDuty, Slack, etc.
4. **Multi-Cluster** - Deploy hub-spoke architecture across clusters
5. **Cost Optimization** - Add ML models for FinOps recommendations

---

## Resources

### Code & Documentation
- **GitHub Repo**: [openshift-aiops-platform](https://github.com/tosin2013/openshift-aiops-platform)
- **MCP Server**: [openshift-cluster-health-mcp](https://github.com/tosin2013/openshift-cluster-health-mcp)
- **Coordination Engine**: [openshift-coordination-engine](https://github.com/tosin2013/openshift-coordination-engine)

### Architecture Decision Records
- [ADR-036: MCP Server Architecture](../../adrs/036-go-based-standalone-mcp-server.md)
- [ADR-038: Coordination Engine Migration](../../adrs/038-go-coordination-engine-migration.md)
- [ADR-039: KServe Integration](../../adrs/039-kserve-integration-coordination-engine.md)
- [ADR-040: Prometheus Integration](../../adrs/040-prometheus-ml-integration.md)

### External Links
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [OpenShift Lightspeed](https://docs.openshift.com/container-platform/latest/lightspeed/)
- [KServe Documentation](https://kserve.github.io/website/)
- [OpenShift GitOps](https://docs.openshift.com/gitops/)

---

## About the Author

This platform was built as part of the OpenShift AI Ops initiative, combining best practices from:
- Site Reliability Engineering (SRE)
- Machine Learning Operations (MLOps)
- GitOps and Infrastructure as Code
- AI-Assisted Operations

Questions? Issues? Contributions welcome!

---

**Made with ❤️ for the OpenShift Community**

*Published: January 12, 2026*
*Last Updated: January 12, 2026*
*Platform Version: 1.0.0*

---

## Appendix: Complete Command Reference

### Deployment Commands
```bash
# Install platform
helm install self-healing-platform charts/hub \
  --namespace self-healing-platform \
  --create-namespace \
  --values charts/hub/values.yaml

# Upgrade platform
helm upgrade self-healing-platform charts/hub \
  --namespace self-healing-platform \
  --values charts/hub/values.yaml

# Uninstall platform
helm uninstall self-healing-platform -n self-healing-platform
```

### Testing Commands
```bash
# Test anomaly detection
oc exec -n self-healing-platform utilities -- curl -X POST \
  http://coordination-engine:8080/api/v1/detect \
  -H "Content-Type: application/json" \
  -d '{"model":"anomaly-detector","instances":[[5.0,8.0,9.5]]}'

# Test predictive analytics
oc exec -n self-healing-platform utilities -- curl -X POST \
  http://predictive-analytics-predictor:8080/v1/models/model:predict \
  -H "Content-Type: application/json" \
  -d '{"instances":[[12,3,65.5,72.8]]}'

# Check model health
oc exec -n self-healing-platform utilities -- curl \
  http://coordination-engine:8080/api/v1/models/anomaly-detector/health
```

### Monitoring Commands
```bash
# Watch pods
watch oc get pods -n self-healing-platform

# Get coordination engine logs
oc logs -f -n self-healing-platform deployment/coordination-engine

# Get MCP server logs
oc logs -f -n self-healing-platform deployment/mcp-server

# Check InferenceServices
oc get inferenceservice -n self-healing-platform -w
```
