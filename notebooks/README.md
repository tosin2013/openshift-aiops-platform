# Self-Healing Platform Notebooks

This directory contains comprehensive Jupyter notebooks demonstrating end-to-end workflows for the OpenShift AIOps Self-Healing Platform. The notebooks are organized following the architecture defined in ADR-012.

## 📚 Notebook Structure

### 01-data-collection/
**Purpose**: Data collection and preprocessing workflows for OpenShift metrics

- **`prometheus-metrics-collection.ipynb`** - Collect and process Prometheus metrics for anomaly detection
- **`openshift-events-analysis.ipynb`** - Process OpenShift events for pattern recognition and anomaly detection
- **`log-parsing-analysis.ipynb`** - Container log collection and structured parsing with error detection
- **`feature-store-demo.ipynb`** - Feature store implementation with Parquet files and data versioning
- **`synthetic-anomaly-generation.ipynb`** - Generate realistic anomaly scenarios for testing *(Coming Soon)*

### 02-anomaly-detection/
**Purpose**: AI/ML model development for anomaly detection

- **`isolation-forest-implementation.ipynb`** - Isolation Forest anomaly detection implementation
- **`time-series-anomaly-detection.ipynb`** - Time series analysis for anomaly detection *(Coming Soon)*
- **`lstm-based-prediction.ipynb`** - LSTM neural networks for predictive anomaly detection *(Coming Soon)*
- **`ensemble-anomaly-methods.ipynb`** - Ensemble methods combining multiple algorithms *(Coming Soon)*

### 03-self-healing-logic/
**Purpose**: Integration with coordination engine and self-healing workflows

- **`coordination-engine-integration.ipynb`** - Complete integration with the coordination engine
- **`rule-based-remediation.ipynb`** - Deterministic rule-based healing logic *(Coming Soon)*
- **`ai-driven-decision-making.ipynb`** - AI-powered remediation decisions *(Coming Soon)*
- **`hybrid-healing-workflows.ipynb`** - Combining rule-based and AI approaches *(Coming Soon)*

### 04-model-serving/
**Purpose**: Model deployment and serving with KServe

- **`kserve-model-deployment.ipynb`** - Deploy models to KServe for production *(Coming Soon)*
- **`model-versioning-mlops.ipynb`** - MLOps workflows for model lifecycle *(Coming Soon)*
- **`inference-pipeline-setup.ipynb`** - Real-time inference pipeline setup *(Coming Soon)*

### 05-end-to-end-scenarios/
**Purpose**: Complete use case demonstrations

- **`pod-crash-loop-healing.ipynb`** - Detect and heal pod crash loops *(Coming Soon)*
- **`resource-exhaustion-detection.ipynb`** - Handle resource exhaustion scenarios *(Coming Soon)*
- **`network-anomaly-response.ipynb`** - Network anomaly detection and response *(Coming Soon)*
- **`complete-platform-demo.ipynb`** - Full platform demonstration *(Coming Soon)*

### utils/
**Purpose**: Shared utility functions and helpers

- **`common_functions.py`** - Common functions used across all notebooks
- **`mcp_client.py`** - MCP client for coordination engine integration
- **`prometheus_client.py`** - Prometheus client utilities *(Coming Soon)*
- **`openshift_utils.py`** - OpenShift API utilities *(Coming Soon)*
- **`visualization_helpers.py`** - Visualization and plotting helpers *(Coming Soon)*

## ✅ Notebook Validation

**New in 2025-11-18**: Notebook validation has been migrated to the **[Jupyter Notebook Validator Operator](https://github.com/tosin2013/jupyter-notebook-validator-operator)** (ADR-029).

### Validation Workflow

Notebooks are validated using **NotebookValidationJob CRDs** instead of manual execution:

```yaml
apiVersion: mlops.mlops.dev/v1alpha1
kind: NotebookValidationJob
metadata:
  name: prometheus-metrics-collection
  namespace: self-healing-platform
spec:
  notebook:
    git:
      url: "https://github.com/openshift-aiops/openshift-aiops-platform.git"
      ref: "main"
    path: "notebooks/01-data-collection/prometheus-metrics-collection.ipynb"

  podConfig:
    containerImage: "quay.io/jupyter/datascience-notebook:latest"
    resources:
      requests:
        memory: "2Gi"
        cpu: "1000m"
      limits:
        memory: "4Gi"
        cpu: "2000m"

  timeout: "30m"
```

### Check Validation Status

```bash
# List all notebook validation jobs
oc get notebookvalidationjob -n self-healing-platform

# Check specific notebook validation
oc get notebookvalidationjob prometheus-metrics-collection -n self-healing-platform

# View validation logs
POD=$(oc get pods -n self-healing-platform -l job-name=prometheus-metrics-collection --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
oc logs $POD -n self-healing-platform
```

### Migration Information

- 📄 **Migration Guide**: [NOTEBOOK-VALIDATION-MIGRATION.md](../docs/NOTEBOOK-VALIDATION-MIGRATION.md)
- 📋 **ADR**: [ADR-029: Jupyter Notebook Validator Operator](../docs/adrs/029-jupyter-notebook-validator-operator.md)
- ⚙️ **Operator**: [Jupyter Notebook Validator Operator](https://github.com/tosin2013/jupyter-notebook-validator-operator)

## 🚀 Getting Started

### Prerequisites

1. **Access to Self-Healing Workbench**:
   ```bash
   oc exec -it self-healing-workbench-dev-0 -c self-healing-workbench -n self-healing-platform -- /bin/bash
   ```

2. **Clone the Repository**:
   ```bash
   git clone https://gitea-with-admin-gitea.apps.cluster-dzqpc.dzqpc.sandbox29.opentlc.com/user1/openshift-aiops-platform.git
   cd openshift-aiops-platform/notebooks
   ```

3. **Install Additional Dependencies** (if needed):
   ```bash
   pip install --user -r ../requirements.txt
   ```

### Running the Notebooks

**Recommended Approach**: Use NotebookValidationJob CRDs (see [Notebook Validation](#-notebook-validation) section above)

**For Development/Testing**: You can still run notebooks manually

#### Option 1: Jupyter Lab (Recommended)
```bash
# Start Jupyter Lab
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root

# Access via port-forward (from local machine)
oc port-forward self-healing-workbench-dev-0 8888:8888 -n self-healing-platform
```

#### Option 2: Command Line Execution
```bash
# Convert notebook to Python script and run
jupyter nbconvert --to script 01-data-collection/prometheus-metrics-collection.ipynb
python 01-data-collection/prometheus-metrics-collection.py
```

#### Option 3: Direct Python Execution
```bash
# Run notebook cells interactively
python -c "
import sys
sys.path.append('utils')
from common_functions import setup_environment
env_info = setup_environment()
print('Environment ready!')
"
```

## 📖 Learning Path

### For Beginners
1. Start with **`01-data-collection/prometheus-metrics-collection.ipynb`**
2. Learn anomaly detection with **`02-anomaly-detection/isolation-forest-implementation.ipynb`**
3. Understand integration with **`03-self-healing-logic/coordination-engine-integration.ipynb`**

### For Advanced Users
1. Explore ensemble methods in **`02-anomaly-detection/`**
2. Implement custom remediation logic in **`03-self-healing-logic/`**
3. Deploy production models with **`04-model-serving/`**
4. Run complete scenarios from **`05-end-to-end-scenarios/`**

## 🔧 Development Guidelines

### Notebook Standards
- **Header Section**: Title, description, prerequisites, expected outcomes
- **Setup Section**: Imports, configuration, environment verification
- **Implementation Section**: Core logic with detailed explanations
- **Validation Section**: Testing and verification of results
- **Integration Section**: Connection to coordination engine
- **Cleanup Section**: Resource cleanup and next steps

### Code Quality
- Use the shared `common_functions.py` for reusable code
- Include comprehensive error handling
- Add detailed markdown explanations
- Validate data quality at each step
- Save intermediate results to persistent storage

### Data Management
- **Input Data**: Store in `/opt/app-root/src/data/`
- **Processed Data**: Save to `/opt/app-root/src/data/processed/`
- **Models**: Save to `/opt/app-root/src/models/`
- **Outputs**: Use appropriate subdirectories

## 🎯 Integration Points

### Coordination Engine
- Base URL: `http://coordination-engine.self-healing-platform.svc.cluster.local:8080`
- Health Check: `/health`
- Anomaly Submission: `/api/v1/anomalies`
- Metrics: `/metrics`

### Prometheus Metrics
- Cluster Prometheus: `https://prometheus-k8s.openshift-monitoring.svc.cluster.local:9091`
- Key Metrics: Node utilization, pod metrics, cluster health
- Query Patterns: Defined in `common_functions.py`

### Persistent Storage
- **Data Volume**: `/opt/app-root/src/data` (5Gi)
- **Models Volume**: `/opt/app-root/src/models` (10Gi, RWX)
- **Format**: Parquet for efficient storage

## 🔍 Troubleshooting

### Common Issues

**Issue**: Import errors for custom modules
```bash
# Solution: Add utils to Python path
import sys
sys.path.append('../utils')
```

**Issue**: Permission denied when saving files
```bash
# Solution: Use persistent storage directories
save_path = '/opt/app-root/src/data/my_file.pkl'
```

**Issue**: Jupyter kernel crashes
```bash
# Solution: Check memory usage and restart if needed
oc delete pod self-healing-workbench-dev-0 -n self-healing-platform
```

**Issue**: Cannot connect to coordination engine
```bash
# Solution: Check if coordination engine is running
oc get pods -n self-healing-platform | grep coordination
```

### Getting Help

1. **Check the ADRs**: Review architectural decisions in `../docs/adrs/`
2. **Examine Logs**: Use `oc logs` to check pod logs
3. **Validate Environment**: Run environment setup functions
4. **Test Connections**: Use health check functions

## 📚 References

- **ADR-002**: Hybrid Deterministic-AI Self-Healing Approach
- **ADR-011**: Self-Healing Workbench Base Image Selection
- **ADR-012**: Notebook Architecture for End-to-End Workflows
- **ADR-013**: Data Collection and Preprocessing Workflows
- **ADR-029**: Jupyter Notebook Validator Operator (**NEW**: CRD-based validation)
- **Migration Guide**: [NOTEBOOK-VALIDATION-MIGRATION.md](../docs/NOTEBOOK-VALIDATION-MIGRATION.md)

## 🤝 Contributing

1. Follow the notebook standards defined above
2. Test notebooks in clean environment before committing
3. Update this README when adding new notebooks
4. Include comprehensive documentation and examples

---

**Happy Learning and Building! 🚀**

*These notebooks demonstrate the full capabilities of the Self-Healing Platform and provide a foundation for developing production-ready AI/ML-driven self-healing solutions.*
