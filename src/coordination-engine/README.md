# Coordination Engine - Hybrid Self-Healing Orchestrator

## Overview

The **Coordination Engine** is the core orchestration component of the Self-Healing Platform. It implements the hybrid deterministic-AI approach defined in [ADR-002](../../docs/adrs/002-hybrid-self-healing-approach.md), managing the interaction between rule-based automation and AI-driven analysis.

**Key Responsibilities:**
- 🔀 **Conflict Resolution**: Prevent simultaneous contradictory actions
- 📊 **Priority Management**: Route actions to appropriate layer (deterministic vs. AI)
- ⚙️ **Action Orchestration**: Execute remediation actions safely
- 📈 **Metrics Export**: Prometheus metrics for observability

## Architecture

### Core Components

```
┌──────────────────────────────────────────────────────────────┐
│                   Coordination Engine                         │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────┐         ┌─────────────────┐           │
│  │ ConflictResolver│         │ Action Queue    │           │
│  │                 │         │                 │           │
│  │ • Detect        │────────▶│ • Priority      │           │
│  │ • Resolve       │         │ • Deduplication │           │
│  │ • Rules Engine  │         │ • Rate Limiting │           │
│  └─────────────────┘         └─────────────────┘           │
│           │                           │                      │
│           ▼                           ▼                      │
│  ┌─────────────────────────────────────────────┐           │
│  │      Remediation Executor                    │           │
│  │  • Node Remediation    • Alert Correlation  │           │
│  │  • Resource Scaling    • Model Inference    │           │
│  └─────────────────────────────────────────────┘           │
│                                                               │
├──────────────────────────────────────────────────────────────┤
│  Interfaces                                                   │
│  ├─ REST API (Flask)                                         │
│  ├─ Prometheus Metrics (/metrics)                           │
│  └─ Kubernetes API Client                                   │
└──────────────────────────────────────────────────────────────┘
```

### Data Model

**Action** (dataclass):
```python
@dataclass
class Action:
    id: str
    type: ActionType          # NODE_REMEDIATION, RESOURCE_SCALING, etc.
    source: ActionSource      # DETERMINISTIC or AI_DRIVEN
    target: str               # Resource identifier
    priority: int             # 1 (highest) to 5 (lowest)
    confidence: float         # AI confidence score (0.0-1.0)
    status: ActionStatus      # PENDING, RUNNING, COMPLETED, FAILED
    created_at: datetime
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
```

**ActionType** (enum):
- `NODE_REMEDIATION` - Node-level fixes (MCO-based)
- `RESOURCE_SCALING` - Scale deployments up/down
- `MODEL_INFERENCE` - Run ML model prediction
- `ALERT_CORRELATION` - Correlate related alerts

**ActionSource** (enum):
- `DETERMINISTIC` - Rule-based automation
- `AI_DRIVEN` - ML model recommendations

## Conflict Resolution

### Conflict Detection Algorithm

```python
def _actions_conflict(self, action1: Action, action2: Action) -> bool:
    """Check if two actions conflict"""

    # 1. Same target resource → conflict
    if action1.target == action2.target:
        return True

    # 2. Mutually exclusive action types → conflict
    conflicting_types = {
        (ActionType.NODE_REMEDIATION, ActionType.RESOURCE_SCALING),
        (ActionType.MODEL_INFERENCE, ActionType.ALERT_CORRELATION)
    }

    action_pair = (action1.type, action2.type)
    return action_pair in conflicting_types or action_pair[::-1] in conflicting_types
```

### Resolution Rules (Priority Order)

#### Rule 1: Same Target Resource
**Priority**: Deterministic > AI-driven

```python
def _resolve_same_target(self, action1: Action, action2: Action) -> Optional[Action]:
    """Deterministic actions take precedence over AI actions"""
    if action1.source == ActionSource.DETERMINISTIC and action2.source == ActionSource.AI_DRIVEN:
        return action1
    elif action2.source == ActionSource.DETERMINISTIC and action1.source == ActionSource.AI_DRIVEN:
        return action2
    return None
```

**Rationale**: Established procedures are more reliable than AI predictions.

#### Rule 2: Priority Conflict
**Priority**: Higher priority wins

```python
def _resolve_priority_conflict(self, action1: Action, action2: Action) -> Optional[Action]:
    """Higher priority action wins"""
    if action1.priority != action2.priority:
        return action1 if action1.priority > action2.priority else action2
    return None
```

#### Rule 3: Low Confidence
**Threshold**: 70% (configurable)

```python
def _resolve_low_confidence(self, action1: Action, action2: Action) -> Optional[Action]:
    """Reject AI actions below confidence threshold"""
    confidence_threshold = 0.7

    if action1.source == ActionSource.AI_DRIVEN and action1.confidence < confidence_threshold:
        return action2
    elif action2.source == ActionSource.AI_DRIVEN and action2.confidence < confidence_threshold:
        return action1

    return None
```

**Rationale**: Low-confidence AI predictions should not override other actions.

## REST API Contract

### Base URL
```
http://coordination-engine.self-healing-platform.svc.cluster.local:8080
```

### Endpoints

#### 1. Health Check
```http
GET /health
```

**Response (200 OK):**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "uptime_seconds": 3600
}
```

#### 2. Submit Anomaly
```http
POST /api/v1/anomalies
Content-Type: application/json
```

**Request Body:**
```json
{
  "timestamp": "2025-12-10T14:30:00Z",
  "type": "resource_exhaustion",
  "severity": "critical",
  "confidence_score": 0.92,
  "details": {
    "node": "worker-1",
    "metric": "memory_usage",
    "threshold": 90,
    "current_value": 95
  },
  "recommended_action": "scale_down_pods",
  "source": "ai_driven"
}
```

**Response (201 Created):**
```json
{
  "anomaly_id": "anom-20251210-001",
  "status": "accepted",
  "assigned_layer": "ai_driven",
  "priority": 2,
  "estimated_resolution_time": "5m",
  "action_id": "act-20251210-001"
}
```

**Error Response (400 Bad Request):**
```json
{
  "error": "Invalid request",
  "message": "confidence_score must be between 0.0 and 1.0",
  "field": "confidence_score"
}
```

#### 3. Get Anomaly Status
```http
GET /api/v1/anomalies/<id>
```

**Response (200 OK):**
```json
{
  "anomaly_id": "anom-20251210-001",
  "status": "in_progress",
  "action": {
    "action_id": "act-20251210-001",
    "type": "resource_scaling",
    "status": "running",
    "started_at": "2025-12-10T14:30:05Z"
  },
  "resolution": null
}
```

#### 4. Trigger Remediation
```http
POST /api/v1/remediate
Content-Type: application/json
```

**Request Body:**
```json
{
  "action_type": "node_remediation",
  "target": "worker-1",
  "priority": 1,
  "source": "deterministic",
  "parameters": {
    "remediation_type": "restart_kubelet"
  }
}
```

**Response (202 Accepted):**
```json
{
  "action_id": "act-20251210-002",
  "status": "queued",
  "position_in_queue": 1
}
```

#### 5. Get Engine Status
```http
GET /api/v1/status
```

**Response (200 OK):**
```json
{
  "engine_status": "operational",
  "active_actions": 3,
  "queued_actions": 7,
  "conflicts_detected_today": 2,
  "conflicts_resolved_today": 2,
  "layers": {
    "deterministic": {
      "status": "healthy",
      "actions_processed": 150
    },
    "ai_driven": {
      "status": "healthy",
      "actions_processed": 45
    }
  }
}
```

#### 6. Prometheus Metrics
```http
GET /metrics
```

**Exported Metrics:**
```prometheus
# HELP coordination_actions_total Total actions processed
# TYPE coordination_actions_total counter
coordination_actions_total{type="node_remediation",source="deterministic"} 150

# HELP coordination_conflicts_total Total conflicts detected
# TYPE coordination_conflicts_total counter
coordination_conflicts_total{conflict_type="same_target"} 12

# HELP coordination_resolution_time_seconds Time to resolve conflicts
# TYPE coordination_resolution_time_seconds histogram
coordination_resolution_time_seconds_bucket{le="0.1"} 45
coordination_resolution_time_seconds_bucket{le="0.5"} 87

# HELP coordination_active_actions Currently active actions
# TYPE coordination_active_actions gauge
coordination_active_actions 3
```

## Integration Examples

### From Jupyter Notebooks

```python
import requests
from datetime import datetime

class CoordinationEngineClient:
    """Client for Coordination Engine API"""

    def __init__(self, base_url='http://coordination-engine:8080'):
        self.base_url = base_url
        self.session = requests.Session()

    def submit_anomaly(self, anomaly_data):
        """Submit anomaly for processing"""
        response = self.session.post(
            f'{self.base_url}/api/v1/anomalies',
            json=anomaly_data,
            timeout=30
        )
        response.raise_for_status()
        return response.json()

    def get_status(self, anomaly_id):
        """Get anomaly processing status"""
        response = self.session.get(
            f'{self.base_url}/api/v1/anomalies/{anomaly_id}',
            timeout=10
        )
        response.raise_for_status()
        return response.json()

# Usage in notebook
client = CoordinationEngineClient()

# Submit anomaly detected by ML model
anomaly = {
    'timestamp': datetime.utcnow().isoformat() + 'Z',
    'type': 'memory_leak',
    'severity': 'high',
    'confidence_score': 0.89,
    'details': {
        'namespace': 'production',
        'pod': 'app-server-abc123',
        'memory_usage_mb': 7800,
        'threshold_mb': 6000
    },
    'recommended_action': 'restart_pod',
    'source': 'ai_driven'
}

result = client.submit_anomaly(anomaly)
print(f"✅ Anomaly submitted: {result['anomaly_id']}")
```

### From Prometheus AlertManager

```yaml
# alertmanager.yaml
receivers:
  - name: coordination-engine
    webhook_configs:
      - url: http://coordination-engine.self-healing-platform.svc:8080/api/v1/anomalies
        send_resolved: true

route:
  receiver: coordination-engine
  routes:
    - match:
        severity: critical
      receiver: coordination-engine
```

## Development

### Local Setup

```bash
# Install dependencies
cd src/coordination-engine
pip install -r requirements.txt

# Run locally (development mode)
export FLASK_ENV=development
python app.py

# Server starts on http://localhost:8080
```

### Dependencies

**requirements.txt:**
```txt
flask==2.3.2
prometheus-client==0.17.1
kubernetes==27.2.0
requests==2.31.0
pydantic==2.1.1
```

### Testing

#### Unit Tests

```bash
# Run unit tests
cd src/coordination-engine
pytest tests/test_basic.py -v

# Run with coverage
pytest tests/ --cov=. --cov-report=html
```

#### Integration Tests

```bash
# Test from within cluster (requires deployed engine)
oc exec -it self-healing-workbench-0 -n self-healing-platform -- bash

# Test health endpoint
curl http://coordination-engine:8080/health

# Test anomaly submission
curl -X POST http://coordination-engine:8080/api/v1/anomalies \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2025-12-10T14:30:00Z",
    "type": "test",
    "severity": "low",
    "confidence_score": 0.95,
    "source": "test"
  }'
```

### Building Container Image

```bash
# Build image
cd src/coordination-engine
podman build -t coordination-engine:latest .

# Tag for registry
podman tag coordination-engine:latest quay.io/takinosh/coordination-engine:latest

# Push to registry
podman push quay.io/takinosh/coordination-engine:latest
```

## Deployment

### Kubernetes Deployment

**Applied via Helm Chart**: `charts/hub/templates/coordination-engine.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coordination-engine
  namespace: self-healing-platform
spec:
  replicas: 2
  selector:
    matchLabels:
      app: coordination-engine
  template:
    metadata:
      labels:
        app: coordination-engine
    spec:
      serviceAccountName: coordination-engine-sa
      containers:
      - name: coordination-engine
        image: quay.io/takinosh/coordination-engine:latest
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 9090
          name: metrics
        env:
        - name: FLASK_ENV
          value: "production"
        - name: LOG_LEVEL
          value: "INFO"
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
```

### RBAC Permissions

**Reference**: [ADR-033: Coordination Engine RBAC Permissions](../../docs/adrs/033-coordination-engine-rbac-permissions.md)

**Required Permissions:**
- `deployments` (get, list, watch, update, patch)
- `pods` (get, list, watch, delete)
- `nodes` (get, list, watch, patch)
- `inferenceservices` (get, list, watch, create, update, patch, delete)
- `machineconfigs` (get, list, watch, create, update)
- `prometheusrules` (get, list, watch)

## Observability

### Prometheus Metrics

**Scraping Configuration:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: coordination-engine
  namespace: self-healing-platform
spec:
  selector:
    matchLabels:
      app: coordination-engine
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

**Key Metrics to Monitor:**

| Metric | Type | Description | Alert Threshold |
|--------|------|-------------|-----------------|
| `coordination_actions_total` | Counter | Total actions processed | N/A |
| `coordination_conflicts_total` | Counter | Total conflicts detected | Rate > 10/min |
| `coordination_resolution_time_seconds` | Histogram | Conflict resolution latency | P95 > 1s |
| `coordination_active_actions` | Gauge | Currently active actions | > 50 |

### Logging

**Log Levels:**
- `DEBUG`: Detailed action processing
- `INFO`: Normal operations (default)
- `WARNING`: Conflicts detected, retries
- `ERROR`: Action failures, API errors

**Example Log Output:**
```
2025-12-10 14:30:00 INFO: Anomaly submitted: anom-20251210-001
2025-12-10 14:30:00 INFO: Action queued: act-20251210-001 (priority: 2)
2025-12-10 14:30:01 WARNING: Conflict detected: act-20251210-001 vs act-20251210-002
2025-12-10 14:30:01 INFO: Conflict resolved using rule: same_target
2025-12-10 14:30:05 INFO: Executing action: act-20251210-001
2025-12-10 14:30:12 INFO: Action completed: act-20251210-001 (duration: 7s)
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FLASK_ENV` | `production` | Flask environment (development/production) |
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG/INFO/WARNING/ERROR) |
| `CONFIDENCE_THRESHOLD` | `0.7` | Minimum AI confidence for actions |
| `MAX_ACTIVE_ACTIONS` | `10` | Maximum concurrent actions |
| `PROMETHEUS_PORT` | `9090` | Prometheus metrics port |

### Conflict Resolution Configuration

```python
# In app.py
CONFLICT_RESOLUTION_CONFIG = {
    'confidence_threshold': 0.7,
    'priority_weights': {
        ActionSource.DETERMINISTIC: 2.0,
        ActionSource.AI_DRIVEN: 1.0
    },
    'retry_attempts': 3,
    'retry_backoff': 5  # seconds
}
```

## Troubleshooting

### Common Issues

#### 1. Actions Stuck in Queue

**Symptom**: Actions remain in `PENDING` status

**Diagnosis:**
```bash
curl http://coordination-engine:8080/api/v1/status
```

**Solutions:**
- Check engine logs: `oc logs deployment/coordination-engine`
- Verify RBAC permissions (can engine modify resources?)
- Check resource quotas (cluster capacity)

#### 2. High Conflict Rate

**Symptom**: Many conflicts detected

**Diagnosis:**
```promql
rate(coordination_conflicts_total[5m]) > 10
```

**Solutions:**
- Review conflict resolution rules
- Adjust confidence thresholds
- Increase action priority granularity

#### 3. Slow Conflict Resolution

**Symptom**: P95 latency > 1s

**Diagnosis:**
```promql
histogram_quantile(0.95, rate(coordination_resolution_time_seconds_bucket[5m]))
```

**Solutions:**
- Optimize resolution rule logic
- Reduce queue size (increase `MAX_ACTIVE_ACTIONS`)
- Scale engine replicas

## Performance Tuning

### Recommended Configuration by Scale

| Cluster Size | Replicas | CPU | Memory | Max Actions |
|--------------|----------|-----|--------|-------------|
| **Small** (<50 nodes) | 1 | 500m | 1Gi | 10 |
| **Medium** (50-200 nodes) | 2 | 1 | 2Gi | 25 |
| **Large** (200+ nodes) | 3 | 2 | 4Gi | 50 |

### Optimization Checklist

- [ ] Enable action deduplication (prevent duplicate actions)
- [ ] Implement rate limiting (prevent action storms)
- [ ] Use priority queues (process high-priority first)
- [ ] Add circuit breakers (protect against cascading failures)
- [ ] Implement caching (reduce Kubernetes API calls)

## Security Considerations

1. **Authentication**: Uses Kubernetes ServiceAccount tokens
2. **Authorization**: RBAC-controlled permissions (ADR-033)
3. **Network Policy**: Restrict ingress to trusted sources
4. **Secrets**: Never log sensitive data (credentials, tokens)
5. **Input Validation**: All API inputs validated via Pydantic schemas

## Related Documentation

- [ADR-002: Hybrid Deterministic-AI Self-Healing Approach](../../docs/adrs/002-hybrid-self-healing-approach.md)
- [ADR-033: Coordination Engine RBAC Permissions](../../docs/adrs/033-coordination-engine-rbac-permissions.md)
- [PRD Section 4.3: Coordination Engine](../../PRD.md#43-coordination-engine)
- [Notebook Integration Guide](../../docs/how-to/coordination-engine-integration.md)

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for development guidelines.

**Code Style:**
- Follow PEP 8
- Use type hints
- Add docstrings to all public methods
- Write unit tests for new features

## License

GNU General Public License v3.0 - See [LICENSE](../../LICENSE)
