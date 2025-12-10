# How-To: Using OpenShift Lightspeed Interactions to Improve Notebooks

## Overview

This guide explains how to use your interactions with OpenShift Lightspeed (via the MCP server) as feedback to continuously improve your Jupyter notebooks. This creates a virtuous cycle where real-world usage directly enhances your AI/ML models and self-healing logic.

## The Feedback Loop

```
OpenShift Lightspeed Query
         ↓
    MCP Server Response
         ↓
    Identify Gaps/Issues
         ↓
    Update Relevant Notebooks
         ↓
    Retrain/Redeploy Models
         ↓
    Improved Lightspeed Responses
         ↓
    (Repeat)
```

## MCP Tools → Notebook Mapping

### Quick Reference Table

| MCP Tool/Resource | Purpose | Related Notebooks | Update Trigger |
|-------------------|---------|-------------------|----------------|
| `get-cluster-health` | Cluster status overview | `00-setup/00-platform-readiness-validation.ipynb` | Health checks fail |
| `query-incidents` | List anomalies/incidents | `02-anomaly-detection/*.ipynb` | False positives/negatives |
| `analyze-anomalies` | Run anomaly analysis | `02-anomaly-detection/*.ipynb`<br>`05-end-to-end-scenarios/*.ipynb` | Poor accuracy, new patterns |
| `trigger-remediation` | Execute healing actions | `03-self-healing-logic/*.ipynb` | Remediation fails |
| `cluster://health` | Health metrics resource | `00-setup/*.ipynb`<br>`07-monitoring-operations/*.ipynb` | Missing metrics |
| `cluster://incidents` | Incident data resource | `02-anomaly-detection/*.ipynb` | Incomplete incident data |
| `cluster://nodes` | Node status resource | `00-setup/*.ipynb` | Node health issues |
| `cluster://anomalies` | Anomaly data resource | `02-anomaly-detection/*.ipynb`<br>`04-model-serving/*.ipynb` | Model performance issues |

## Detailed Workflow

### Step 1: Interact with OpenShift Lightspeed

**Access Lightspeed**:
- OpenShift Console → Help → OpenShift Lightspeed
- Or use CLI: `oc lightspeed query "your question"`

**Example Queries**:
```
"What is the current cluster health?"
"Show me anomalies from the last 24 hours"
"Why is the predictive-analytics pod failing?"
"Trigger remediation for high CPU usage on worker-2"
"How are my InferenceServices performing?"
```

### Step 2: Monitor MCP Server Logs

**Real-time Monitoring**:
```bash
# Stream logs
oc logs -f deployment/cluster-health-mcp-server -n self-healing-platform

# Watch for tool invocations
oc logs deployment/cluster-health-mcp-server -n self-healing-platform \
  --since=1h | grep "Tool invoked"

# Check response times
oc logs deployment/cluster-health-mcp-server -n self-healing-platform \
  --since=1h | grep "Response time"
```

**Key Log Patterns**:
```json
// Tool invocation
{"level":"info","message":"Tool invoked: query-incidents","params":{"time_range":"1h"},"timestamp":"..."}

// Successful response
{"level":"info","message":"Tool response","tool":"query-incidents","duration":"234ms","success":true}

// Error (needs attention!)
{"level":"error","message":"Tool execution failed","tool":"analyze-anomalies","error":"Model inference timeout"}
```

### Step 3: Identify Issues and Gaps

**Common Issues to Watch For**:

| Issue | Symptom | Impact |
|-------|---------|--------|
| **Inaccurate Responses** | Wrong cluster status, incorrect metrics | Low trust, wrong decisions |
| **Missing Data** | "No data available" responses | Limited usefulness |
| **Slow Responses** | >5 second response times | Poor user experience |
| **Failed Tool Invocations** | Errors in logs, incomplete actions | Broken functionality |
| **False Positives** | Anomalies that aren't real issues | Alert fatigue |
| **False Negatives** | Real issues not detected | Unaddressed problems |
| **Failed Remediation** | Healing actions don't complete | Persistent issues |

**Example: Identifying a Gap**
```
User Query: "Are there any memory leaks in my cluster?"
Lightspeed Response: "No anomalies detected"

[Reality: predictive-analytics pod has been slowly leaking memory for 3 days]

GAP IDENTIFIED:
- Time-series anomaly detection not catching gradual memory leaks
- Need to update LSTM model with long-term trend detection
```

### Step 4: Update Relevant Notebooks

#### A. Anomaly Detection Improvements

**Notebook**: `notebooks/02-anomaly-detection/01-isolation-forest-implementation.ipynb`

**When to Update**:
- False positives (normal behavior flagged as anomaly)
- False negatives (real issues missed)
- New anomaly patterns discovered

**What to Update**:
```python
# Adjust contamination parameter based on false positive rate
isolation_forest = IsolationForest(
    contamination=0.02,  # Reduce if too many false positives
    random_state=42
)

# Add new features based on missed anomalies
features = [
    'cpu_usage',
    'memory_usage',
    'memory_growth_rate',  # NEW: catch memory leaks
    'network_throughput',
    'api_latency_p95'      # NEW: detect performance degradation
]
```

**Retrain**:
```bash
# Run via NotebookValidationJob
oc get notebookvalidationjob -n self-healing-platform \
  -l notebook=01-isolation-forest-implementation

# Or manually in workbench
oc port-forward self-healing-workbench-0 8888:8888 -n self-healing-platform
# Execute notebook cells to retrain with new features
```

---

#### B. Time-Series Analysis Updates

**Notebook**: `notebooks/02-anomaly-detection/02-time-series-anomaly-detection.ipynb`

**When to Update**:
- Gradual trends not detected (e.g., memory leaks)
- Seasonal patterns missed
- Model accuracy below 90%

**What to Update**:
```python
# Add longer time window for trend detection
prophet_model = Prophet(
    changepoint_prior_scale=0.05,
    seasonality_prior_scale=10.0,
    seasonality_mode='multiplicative',
    # NEW: longer interval for detecting slow leaks
    interval_width=0.95,
    daily_seasonality=True,
    weekly_seasonality=True
)

# Add custom seasonality
prophet_model.add_seasonality(
    name='business_hours',
    period=1,
    fourier_order=5,
    mode='additive'
)
```

---

#### C. Self-Healing Logic Enhancements

**Notebook**: `notebooks/03-self-healing-logic/coordination-engine-integration.ipynb`

**When to Update**:
- Remediation actions fail
- Wrong action chosen for incident
- Conflicts between remediation strategies

**What to Update**:
```python
# Update remediation action priority scoring
def calculate_action_priority(anomaly):
    priority_score = 0

    # Severity weight
    severity_weights = {
        'critical': 100,
        'high': 75,
        'medium': 50,
        'low': 25
    }
    priority_score += severity_weights.get(anomaly['severity'], 0)

    # NEW: Add success rate weight based on past performance
    action_success_rate = get_historical_success_rate(anomaly['type'])
    priority_score *= action_success_rate

    # NEW: Add impact assessment
    if anomaly['affects_user_traffic']:
        priority_score *= 1.5

    return priority_score

# Update coordination engine API call
response = coordination_engine_client.submit_anomaly({
    'timestamp': anomaly['timestamp'],
    'type': anomaly['type'],
    'severity': anomaly['severity'],
    'recommended_action': 'scale_up',  # Updated based on failure analysis
    'confidence_score': 0.95,
    'priority_score': calculate_action_priority(anomaly)
})
```

---

#### D. Model Serving Optimization

**Notebook**: `notebooks/04-model-serving/kserve-model-deployment.ipynb`

**When to Update**:
- Inference timeouts
- High error rates
- Insufficient throughput

**What to Update**:
```python
# Update InferenceService configuration
inference_service = V1beta1InferenceService(
    api_version="serving.kserve.io/v1beta1",
    kind="InferenceService",
    metadata=client.V1ObjectMeta(
        name="predictive-analytics",
        namespace="self-healing-platform"
    ),
    spec=V1beta1InferenceServiceSpec(
        predictor=V1beta1PredictorSpec(
            sklearn=V1beta1SKLearnSpec(
                storage_uri="pvc://model-storage-pvc/predictive-analytics",
                # NEW: Increased resources based on observed usage
                resources=client.V1ResourceRequirements(
                    requests={'cpu': '500m', 'memory': '2Gi'},  # Was 1Gi
                    limits={'cpu': '2', 'memory': '4Gi'}        # Was 2Gi
                )
            ),
            # NEW: Add autoscaling based on CPU/memory
            min_replicas=2,  # Was 1
            max_replicas=5,  # Was 3
            scale_target=80,  # CPU utilization target
            scale_metric="cpu"
        )
    )
)
```

---

#### E. Creating New Notebooks for New Use Cases

**When to Create**:
- Lightspeed query reveals gap in coverage
- New anomaly pattern discovered
- New remediation strategy needed

**Example**: Creating a memory leak detection notebook

```bash
# Create new notebook
touch notebooks/05-end-to-end-scenarios/memory-leak-detection-and-remediation.ipynb
```

**Notebook Structure**:
```python
# ============================================================
# HEADER: Memory Leak Detection and Remediation
# ============================================================
# Purpose: Detect gradual memory leaks using trend analysis
# Trigger: Lightspeed query "memory leak" returned no results
# Related MCP Tools: analyze-anomalies, trigger-remediation
# ============================================================

# 1. DATA COLLECTION
# Collect memory metrics with fine-grained timestamps
memory_metrics = query_prometheus(
    query='container_memory_usage_bytes{pod=~".*predictor.*"}',
    start_time='7d',
    step='1m'
)

# 2. TREND ANALYSIS
# Use linear regression to detect gradual increases
from sklearn.linear_regression import LinearRegression
model = LinearRegression()
# ... trend detection logic ...

# 3. LEAK DETECTION
# Flag as leak if:
# - Consistent upward trend (p < 0.05)
# - Growth rate > 5MB/hour
# - No corresponding decrease (GC not working)

# 4. REMEDIATION
# Submit to coordination engine with specific action
coordination_engine_client.submit_anomaly({
    'type': 'memory_leak',
    'severity': 'high',
    'recommended_action': 'rolling_restart',
    'details': {
        'leak_rate_mb_per_hour': 8.5,
        'projected_oom_time': '4 hours'
    }
})

# 5. VALIDATION
# Track if remediation resolves leak
# Update model if needed
```

### Step 5: Deploy and Validate Updates

**Option 1: NotebookValidationJob (Automated)**
```bash
# Check existing validation jobs
oc get notebookvalidationjob -n self-healing-platform

# Trigger re-validation (ArgoCD will detect changes)
git add notebooks/
git commit -m "feat: improve memory leak detection based on Lightspeed feedback"
git push

# Wait for NotebookValidationJobs to complete
oc get notebookvalidationjob -n self-healing-platform -w
```

**Option 2: Manual Execution in Workbench**
```bash
# Port-forward to workbench
oc port-forward self-healing-workbench-0 8888:8888 -n self-healing-platform

# Open browser: http://localhost:8888
# Navigate to updated notebook
# Execute all cells
# Verify models saved to /mnt/models/
```

**Validation Checklist**:
- [ ] Models trained successfully without errors
- [ ] Models saved to correct PVC path (`/mnt/models/{model-name}/`)
- [ ] InferenceService pods restarted and ready
- [ ] Coordination engine accepts new anomaly submissions
- [ ] Metrics exported to Prometheus

### Step 6: Re-test with OpenShift Lightspeed

**Verification Queries**:
```
"Are there any memory leaks now?"
[Expected: Lightspeed now detects the gradual memory leak]

"What is the confidence score for the memory leak detection?"
[Expected: Shows improved confidence with new model]

"Trigger remediation for the memory leak"
[Expected: Successfully initiates rolling restart]
```

**Check MCP Server Logs**:
```bash
# Verify improved performance
oc logs deployment/cluster-health-mcp-server -n self-healing-platform \
  --since=1h | grep "analyze-anomalies"

# Should show:
# - Faster response times
# - Higher confidence scores
# - Fewer "No data" responses
```

## Real-World Examples

### Example 1: Improving False Positive Rate

**Initial Situation**:
```
Lightspeed Query: "Show me anomalies from last hour"
Response: "47 anomalies detected, 32 critical"

[Reality: Only 3 were real issues - 91% false positive rate!]
```

**Actions Taken**:
1. Updated `02-anomaly-detection/01-isolation-forest-implementation.ipynb`
   - Reduced contamination from 0.1 to 0.03
   - Added feature normalization
   - Increased min_samples_split to reduce noise

2. Updated `03-self-healing-logic/coordination-engine-integration.ipynb`
   - Added confidence score threshold (>0.85)
   - Implemented anomaly correlation logic
   - Added historical validation

3. Retrained models via NotebookValidationJob

**Result**:
```
Lightspeed Query: "Show me anomalies from last hour"
Response: "4 anomalies detected, 2 critical"

[Reality: All 4 were real issues - 0% false positive rate!]
```

---

### Example 2: Adding Proactive Scaling

**Initial Situation**:
```
Lightspeed Query: "Why did the predictive-analytics pod crash?"
Response: "OOMKilled due to memory limit. Occurred at 14:32 UTC."

[Reactive response - pod already crashed]
```

**Actions Taken**:
1. Created `05-end-to-end-scenarios/proactive-resource-scaling.ipynb`
   - Predict memory exhaustion 15 minutes in advance
   - Train LSTM model on memory growth patterns
   - Integrate with coordination engine for proactive scaling

2. Updated `04-model-serving/kserve-model-deployment.ipynb`
   - Added HPA (Horizontal Pod Autoscaler) configuration
   - Increased memory limits based on observed peaks

3. Updated MCP server to expose `predict-resource-exhaustion` tool

**Result**:
```
Lightspeed Query: "Are there any resource issues?"
Response: "Proactive scaling recommendation: predictive-analytics pod
will reach memory limit in 12 minutes. Scaling action scheduled for 14:20 UTC."

[Proactive response - prevents crash]
```

## Best Practices

### 1. Version Your Notebooks
```bash
git add notebooks/
git commit -m "feat: improve anomaly detection based on user query feedback"
git tag v1.2.0-anomaly-detection
git push --tags
```

### 2. Document Changes
Add metadata to notebooks:
```python
# ============================================================
# CHANGELOG
# ============================================================
# v1.2.0 (2025-12-09)
# - Reduced false positives by 85%
# - Added memory leak trend detection
# - Improved coordination engine integration
# - Trigger: OpenShift Lightspeed user feedback
# ============================================================
```

### 3. Track Metrics
Monitor improvement over time:
```python
# Add to monitoring notebook
metrics = {
    'false_positive_rate': 0.09,  # Was 0.91
    'false_negative_rate': 0.05,  # Was 0.15
    'avg_response_time_ms': 234,  # Was 1200
    'user_satisfaction': 4.2,     # Was 2.8
    'remediation_success_rate': 0.92  # Was 0.67
}
```

### 4. Automate the Loop
```yaml
# Add to tekton/pipelines/
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: lightspeed-feedback-pipeline
spec:
  tasks:
    - name: analyze-mcp-logs
    - name: identify-gaps
    - name: update-notebooks
    - name: retrain-models
    - name: validate-improvements
```

## Troubleshooting

### Issue: Notebook changes not reflected in MCP responses

**Check**:
```bash
# 1. Verify models saved correctly
oc exec -it self-healing-workbench-0 -- ls -la /mnt/models/predictive-analytics/

# 2. Restart InferenceService predictor
oc delete pod -n self-healing-platform -l serving.kserve.io/inferenceservice=predictive-analytics

# 3. Check MCP server is using new models
oc logs deployment/cluster-health-mcp-server -n self-healing-platform | grep "Model loaded"
```

### Issue: NotebookValidationJob fails after notebook update

**Check**:
```bash
# View validation job logs
oc logs -n self-healing-platform -l job-name=01-isolation-forest-implementation-validation

# Common issues:
# - Missing dependencies: Add to notebook-validator image
# - Path issues: Verify /mnt/models/ mount
# - Memory limits: Increase in values-hub.yaml
```

## Related Documentation

- [Deploy MCP Server and Configure OpenShift Lightspeed](deploy-mcp-server-lightspeed.md)
- [ADR-014: Cluster Health MCP Server](../adrs/014-openshift-aiops-platform-mcp-server.md)
- [ADR-012: Notebook Architecture](../adrs/012-notebook-architecture-for-end-to-end-workflows.md)
- [Notebook: MCP Server Integration](../../notebooks/06-mcp-lightspeed-integration/mcp-server-integration.ipynb)

## Next Steps

1. **Start Simple**: Pick one query, identify one gap, update one notebook
2. **Measure Impact**: Track metrics before and after updates
3. **Iterate**: Repeat the cycle weekly or after major incidents
4. **Share Learning**: Document patterns in ADRs and notebooks
5. **Automate**: Build pipelines to streamline the feedback loop
