# Self-Healing Workbench Development Guide

## Overview

This guide walks you through using the Self-Healing Platform's AI/ML workbench for developing anomaly detection models and self-healing algorithms. The workbench uses a PyTorch 2025.1 base image with GPU acceleration support.

This is a **comprehensive end-to-end guide** covering:
1. **Workbench Setup** - Access and environment verification
2. **Model Development** - Anomaly detection and predictive analytics
3. **Model Serving** - Deploy models with KServe
4. **MCP Server Integration** - Connect to OpenShift Lightspeed
5. **Self-Healing Workflows** - Implement remediation logic
6. **Monitoring & Metrics** - Prometheus integration

## Prerequisites

- Access to the OpenShift cluster
- `oc` CLI tool configured
- Basic knowledge of Python, Jupyter, and Git
- GPU node available (optional but recommended)

## Quick Start (In RHODS Workbench)

**Assumption**: You're already in the RHODS workbench at:
```
https://self-healing-workbench-dev-self-healing-platform.apps.cluster-dzqpc.dzqpc.sandbox29.opentlc.com/notebook/self-healing-platform/self-healing-workbench-dev/lab
```

### Step 1: Open Terminal in JupyterLab

In the JupyterLab interface:
1. Click **File** → **New** → **Terminal**
2. Or use the Terminal icon in the launcher

You'll now have a terminal in `/opt/app-root/src/`

### Step 2: Clone the Repository

In the terminal, clone the project repository:

```bash
# Clone the Self-Healing Platform repository
git clone https://gitea-with-admin-gitea.apps.cluster-dzqpc.dzqpc.sandbox29.opentlc.com/user1/openshift-aiops-platform.git

# Navigate to the project directory
cd openshift-aiops-platform

# Verify the clone
ls -la
```

### Step 3: Run Environment Setup Notebook ⭐ IMPORTANT

**Before running any other notebooks, you MUST run the setup notebook:**

1. In the file browser, navigate to: `openshift-aiops-platform/notebooks/00-setup/`
2. Double-click: `environment-setup.ipynb`
3. Click "Run All" button
4. Wait for all cells to complete
5. Review the setup summary report

**This notebook will**:
- ✅ Verify Python and PyTorch installation
- ✅ Check GPU availability
- ✅ Verify persistent storage volumes
- ✅ Test required dependencies
- ✅ Create necessary directories
- ✅ Generate setup summary report

**Time**: 5-10 minutes

**What to look for**:
- Python 3.11+ ✓
- PyTorch 2025.1 ✓
- CUDA Available (True or False - both OK)
- All dependencies installed ✓
- Data and Models volumes accessible ✓

### Step 4: Address Any Issues (If Needed)

If the setup notebook shows missing dependencies:

```bash
# Install additional packages (if needed)
pip install --user \
    statsmodels>=0.14.0 \
    prophet>=1.1.4 \
    tslearn>=0.6.0 \
    pyod>=1.1.0 \
    xgboost>=2.0.0 \
    lightgbm>=4.0.0 \
    prometheus-client>=0.17.0 \
    kubernetes>=28.0.0 \
    kserve>=0.11.0 \
    seaborn>=0.12.0 \
    plotly>=5.17.0 \
    bokeh>=3.0.0 \
    networkx>=3.0 \
    pyyaml>=6.0 \
    requests>=2.31.0
```

**Note**: Most dependencies are pre-installed in PyTorch 2025.1 image.

## Development Workflow in RHODS Workbench

### Working with Jupyter Notebooks

You're already in JupyterLab! Here's how to work with notebooks:

1. **Navigate to notebooks directory:**
   - In the file browser on the left, navigate to: `openshift-aiops-platform/notebooks/`
   - Or use the terminal: `cd openshift-aiops-platform/notebooks/`

2. **Open a notebook:**
   - Double-click any `.ipynb` file to open it
   - Or right-click → Open With → Notebook

3. **Run cells:**
   - Click a cell and press `Shift+Enter` to run it
   - Or use the Run button in the toolbar
   - Use "Run All" to execute the entire notebook

4. **Create new notebooks:**
   - Right-click in file browser → New → Notebook
   - Select Python 3 kernel
   - Start coding!

### Project Structure

The repository contains:

```
openshift-aiops-platform/
├── docs/
│   ├── adrs/                          # Architectural Decision Records
│   ├── tutorials/                     # Tutorial guides (this file!)
│   ├── NOTEBOOK-EXECUTION-READY.md    # Start here!
│   ├── NOTEBOOK-EXECUTION-GUIDE.md    # Detailed instructions
│   └── NOTEBOOK-EXECUTION-CHECKLIST.md # Track progress
├── notebooks/
│   ├── 01-data-collection/            # Phase 1: Data Collection (5 notebooks)
│   ├── 02-anomaly-detection/          # Phase 2: Anomaly Detection (4 notebooks)
│   ├── 03-self-healing-logic/         # Phase 3: Self-Healing Logic (4 notebooks)
│   ├── 04-model-serving/              # Phase 4: Model Serving (3 notebooks)
│   ├── 05-end-to-end-scenarios/       # Phase 5: End-to-End Scenarios (4 notebooks)
│   ├── 06-mcp-lightspeed-integration/ # Phase 6: MCP & Lightspeed (3 notebooks)
│   ├── 07-monitoring-operations/      # Phase 7: Monitoring & Operations (3 notebooks)
│   ├── 08-advanced-scenarios/         # Phase 8: Advanced Scenarios (4 notebooks)
│   ├── utils/                         # Shared utilities
│   └── README.md                      # Notebook documentation
├── src/coordination-engine/           # Self-healing coordination logic
├── k8s/                               # Kubernetes manifests
└── models/                            # Trained models (persistent storage)
```

### Working with Persistent Storage

The workbench has access to persistent volumes:

- **Data Volume** (`/opt/app-root/src/data`): Store datasets and training data (20GB)
- **Models Volume** (`/opt/app-root/src/models`): Store trained models (50GB, shared across pods)

**In your notebooks:**

```python
import pandas as pd
import joblib

# Save training data
df = pd.DataFrame(...)
df.to_parquet('/opt/app-root/src/data/my_dataset.parquet')

# Load training data
df = pd.read_parquet('/opt/app-root/src/data/my_dataset.parquet')

# Save trained models
joblib.dump(model, '/opt/app-root/src/models/my_model.pkl')

# Load trained models
model = joblib.load('/opt/app-root/src/models/my_model.pkl')
```

**In terminal:**

```bash
# Create directories for organization
mkdir -p /opt/app-root/src/data/training
mkdir -p /opt/app-root/src/data/processed
mkdir -p /opt/app-root/src/models/anomaly-detection

# List what's stored
ls -lah /opt/app-root/src/data/
ls -lah /opt/app-root/src/models/
```

## End-to-End Notebook Tutorials

Follow these notebooks in order to build a complete self-healing platform workflow. The notebooks are organized in the `notebooks/` directory and follow a structured learning path.

### 📓 Phase 1: Data Collection & Preparation

#### 1.1 Prometheus Metrics Collection
**File**: `notebooks/01-data-collection/prometheus-metrics-collection.ipynb` ✅ **EXISTS**

**Objectives**:
- Collect Prometheus metrics from OpenShift cluster
- Process and normalize metrics
- Store in feature store
- Validate data quality

**Key Topics**:
- Prometheus query API
- Time series data handling
- Feature engineering
- Data validation

---

#### 1.2 OpenShift Events Analysis
**File**: `notebooks/01-data-collection/openshift-events-analysis.ipynb` ✅ **EXISTS**

**Objectives**:
- Parse OpenShift events
- Extract patterns and anomalies
- Correlate with metrics
- Create event features

**Key Topics**:
- Kubernetes event API
- Event parsing and filtering
- Pattern recognition
- Event correlation

---

#### 1.3 Log Parsing & Analysis
**File**: `notebooks/01-data-collection/log-parsing-analysis.ipynb` ✅ **EXISTS**

**Objectives**:
- Collect container logs
- Parse structured and unstructured logs
- Extract error patterns
- Create log-based features

**Key Topics**:
- Log collection from pods
- Structured log parsing
- Error detection
- Log aggregation

---

#### 1.4 Feature Store Implementation
**File**: `notebooks/01-data-collection/feature-store-demo.ipynb` ✅ **EXISTS**

**Objectives**:
- Implement feature store
- Version features
- Store in Parquet format
- Enable feature reuse

**Key Topics**:
- Feature store design
- Data versioning
- Efficient storage
- Feature retrieval

---

#### 1.5 Synthetic Anomaly Generation
**File**: `notebooks/01-data-collection/synthetic-anomaly-generation.ipynb` ⏳ **NEEDED**

**Objectives**:
- Generate realistic anomaly scenarios
- Create labeled training data
- Simulate cluster failures
- Enable model testing

**Key Topics**:
- Synthetic data generation
- Anomaly injection
- Realistic failure scenarios
- Data labeling

---

### 📓 Phase 2: Anomaly Detection Model Development

#### 2.1 Isolation Forest Implementation
**File**: `notebooks/02-anomaly-detection/01-isolation-forest-implementation.ipynb` ✅ **EXISTS**

**Objectives**:
- Implement Isolation Forest algorithm
- Train on cluster metrics
- Evaluate performance
- Save trained model

**Key Topics**:
- Isolation Forest algorithm
- Model training and evaluation
- Hyperparameter tuning
- Model persistence

---

#### 2.2 Time Series Anomaly Detection
**File**: `notebooks/02-anomaly-detection/02-time-series-anomaly-detection.ipynb` ⏳ **NEEDED**

**Objectives**:
- Implement time series anomaly detection
- Use ARIMA/Prophet for forecasting
- Detect deviations from forecast
- Handle seasonal patterns

**Key Topics**:
- Time series decomposition
- ARIMA/Prophet models
- Forecast-based anomaly detection
- Seasonal adjustment

---

#### 2.3 LSTM-Based Prediction
**File**: `notebooks/02-anomaly-detection/03-lstm-based-prediction.ipynb` ⏳ **NEEDED**

**Objectives**:
- Build LSTM neural networks
- Train on GPU
- Detect anomalies via reconstruction error
- Evaluate deep learning models

**Key Topics**:
- LSTM architecture
- GPU acceleration with PyTorch
- Reconstruction error
- Deep learning best practices

---

#### 2.4 Ensemble Anomaly Methods
**File**: `notebooks/02-anomaly-detection/04-ensemble-anomaly-methods.ipynb` ⏳ **NEEDED**

**Objectives**:
- Combine multiple anomaly detection methods
- Implement voting/averaging
- Improve detection accuracy
- Handle edge cases

**Key Topics**:
- Ensemble methods
- Voting strategies
- Confidence scoring
- Method comparison

---

### 📓 Phase 3: Self-Healing Logic & Integration

#### 3.1 Coordination Engine Integration
**File**: `notebooks/03-self-healing-logic/coordination-engine-integration.ipynb` ✅ **EXISTS**

**Objectives**:
- Connect to coordination engine
- Submit anomalies
- Query health status
- Trigger remediation

**Key Topics**:
- Coordination engine API
- Incident submission
- Health monitoring
- Remediation triggering

---

#### 3.2 Rule-Based Remediation
**File**: `notebooks/03-self-healing-logic/rule-based-remediation.ipynb` ⏳ **NEEDED**

**Objectives**:
- Implement deterministic healing rules
- Map anomalies to actions
- Execute remediation
- Validate results

**Key Topics**:
- Rule engine design
- Action mapping
- Remediation execution
- Result validation

---

#### 3.3 AI-Driven Decision Making
**File**: `notebooks/03-self-healing-logic/ai-driven-decision-making.ipynb` ⏳ **NEEDED**

**Objectives**:
- Use ML models for remediation decisions
- Implement confidence scoring
- Handle uncertainty
- Learn from outcomes

**Key Topics**:
- Decision tree models
- Confidence scoring
- Uncertainty handling
- Feedback loops

---

#### 3.4 Hybrid Healing Workflows
**File**: `notebooks/03-self-healing-logic/hybrid-healing-workflows.ipynb` ⏳ **NEEDED**

**Objectives**:
- Combine rule-based and AI approaches
- Route decisions intelligently
- Optimize healing success
- Monitor effectiveness

**Key Topics**:
- Hybrid architecture
- Decision routing
- Performance optimization
- Effectiveness metrics

---

### 📓 Phase 4: Model Serving & Deployment

#### 4.1 KServe Model Deployment
**File**: `notebooks/04-model-serving/kserve-model-deployment.ipynb` ⏳ **NEEDED**

**Objectives**:
- Package models for KServe
- Deploy InferenceService
- Test inference endpoints
- Monitor serving performance

**Key Topics**:
- KServe InferenceService
- Model format conversion
- Inference testing
- Performance monitoring

---

#### 4.2 Model Versioning & MLOps
**File**: `notebooks/04-model-serving/model-versioning-mlops.ipynb` ⏳ **NEEDED**

**Objectives**:
- Implement model versioning
- Create MLOps pipeline
- Automate model updates
- Track model lineage

**Key Topics**:
- Model versioning strategies
- MLOps workflows
- Automated retraining
- Model registry

---

#### 4.3 Inference Pipeline Setup
**File**: `notebooks/04-model-serving/inference-pipeline-setup.ipynb` ⏳ **NEEDED**

**Objectives**:
- Build real-time inference pipeline
- Handle streaming data
- Implement batching
- Optimize latency

**Key Topics**:
- Pipeline architecture
- Streaming inference
- Batch processing
- Latency optimization

---

### 📓 Phase 5: End-to-End Scenarios

#### 5.1 Pod Crash Loop Healing
**File**: `notebooks/05-end-to-end-scenarios/pod-crash-loop-healing.ipynb` ⏳ **NEEDED**

**Objectives**:
- Detect pod crash loops
- Analyze root causes
- Execute healing actions
- Verify recovery

**Key Topics**:
- Crash loop detection
- Root cause analysis
- Healing actions
- Recovery verification

---

#### 5.2 Resource Exhaustion Detection
**File**: `notebooks/05-end-to-end-scenarios/resource-exhaustion-detection.ipynb` ⏳ **NEEDED**

**Objectives**:
- Detect resource exhaustion
- Predict resource needs
- Trigger scaling
- Monitor recovery

**Key Topics**:
- Resource monitoring
- Exhaustion prediction
- Auto-scaling
- Recovery monitoring

---

#### 5.3 Network Anomaly Response
**File**: `notebooks/05-end-to-end-scenarios/network-anomaly-response.ipynb` ⏳ **NEEDED**

**Objectives**:
- Detect network anomalies
- Analyze network patterns
- Execute network healing
- Validate connectivity

**Key Topics**:
- Network metrics
- Anomaly detection
- Network healing
- Connectivity validation

---

#### 5.4 Complete Platform Demo
**File**: `notebooks/05-end-to-end-scenarios/complete-platform-demo.ipynb` ⏳ **NEEDED**

**Objectives**:
- Demonstrate full platform
- Run end-to-end workflow
- Show all components
- Validate integration

**Key Topics**:
- Platform overview
- Workflow demonstration
- Component integration
- Success metrics

---

### 📓 Phase 6: Advanced Integration (NEW)

#### 6.1 MCP Server Integration
**File**: `notebooks/06-mcp-integration/mcp-server-integration.ipynb` ⏳ **NEEDED**

**Objectives**:
- Connect to Cluster Health MCP Server
- Query cluster health resources
- Trigger remediation via MCP
- Test MCP protocol

**Key Topics**:
- MCP protocol
- Resource queries
- Tool invocation
- Error handling

---

#### 6.2 OpenShift Lightspeed Integration
**File**: `notebooks/06-mcp-integration/openshift-lightspeed-integration.ipynb` ⏳ **NEEDED**

**Objectives**:
- Deploy MCP server for Lightspeed
- Configure OLSConfig
- Test Lightspeed queries
- Validate AI responses

**Key Topics**:
- OLSConfig setup
- Lightspeed integration
- Prompt engineering
- Response validation

---

#### 6.3 LlamaStack Integration
**File**: `notebooks/06-mcp-integration/llamastack-integration.ipynb` ⏳ **NEEDED**

**Objectives**:
- Deploy LlamaStack runtime
- Integrate with platform
- Use Llama models for analysis
- Implement AI-powered remediation

**Key Topics**:
- LlamaStack deployment
- vLLM model serving
- Prompt engineering
- Cost optimization

---

### 📓 Phase 7: Monitoring & Operations

#### 7.1 Prometheus Metrics & Monitoring
**File**: `notebooks/07-monitoring/prometheus-metrics-monitoring.ipynb` ⏳ **NEEDED**

**Objectives**:
- Add Prometheus metrics
- Create custom metrics
- Build Grafana dashboards
- Set up alerts

**Key Topics**:
- Prometheus client
- Custom metrics
- Grafana dashboards
- Alert rules

---

#### 7.2 Model Performance Monitoring
**File**: `notebooks/07-monitoring/model-performance-monitoring.ipynb` ⏳ **NEEDED**

**Objectives**:
- Monitor model accuracy
- Track prediction drift
- Detect model degradation
- Trigger retraining

**Key Topics**:
- Model metrics
- Drift detection
- Performance degradation
- Retraining triggers

---

#### 7.3 Healing Success Tracking
**File**: `notebooks/07-monitoring/healing-success-tracking.ipynb` ⏳ **NEEDED**

**Objectives**:
- Track healing success rates
- Analyze failure patterns
- Optimize remediation
- Generate reports

**Key Topics**:
- Success metrics
- Failure analysis
- Optimization
- Reporting

---

### 📓 Utility Functions

**File**: `notebooks/utils/` ✅ **EXISTS**

- `common_functions.py` - Shared utility functions
- `mcp_client.py` - MCP client for integration
- `prometheus_client.py` ⏳ **NEEDED** - Prometheus utilities
- `openshift_utils.py` ⏳ **NEEDED** - OpenShift API utilities
- `visualization_helpers.py` ⏳ **NEEDED** - Visualization helpers

## 🚀 Getting Started with Notebooks (In Workbench)

**You're already in the workbench at:**
```
https://self-healing-workbench-dev-self-healing-platform.apps.cluster-dzqpc.dzqpc.sandbox29.opentlc.com/notebook/self-healing-platform/self-healing-workbench-dev/lab
```

### Quick Start Path

1. **Open a terminal in JupyterLab**:
   - Click **File** → **New** → **Terminal**
   - Or click the Terminal icon in the launcher
   - You'll be in `/opt/app-root/src/`

2. **Clone the Repository** (if not already cloned):
   ```bash
   cd /opt/app-root/src
   git clone https://gitea-with-admin-gitea.apps.cluster-dzqpc.dzqpc.sandbox29.opentlc.com/user1/openshift-aiops-platform.git
   cd openshift-aiops-platform
   ```

3. **⭐ RUN SETUP NOTEBOOK FIRST** (5-10 minutes):
   - Navigate to: `openshift-aiops-platform/notebooks/00-setup/`
   - Double-click: `environment-setup.ipynb`
   - Click "Run All" button
   - Review the setup summary report
   - **This is REQUIRED before running other notebooks!**

4. **Start with Phase 1** - Data Collection:
   - Navigate to: `openshift-aiops-platform/notebooks/01-data-collection/`
   - Double-click: `prometheus-metrics-collection.ipynb`
   - Click "Run All" or run cells with `Shift+Enter`
   - Review outputs and verify data collection works

5. **Progress to Phase 2** - Anomaly Detection:
   - Navigate to: `notebooks/02-anomaly-detection/`
   - Open: `01-isolation-forest-implementation.ipynb`
   - Train your first anomaly detection model
   - Model will be saved to `/opt/app-root/src/models/`

6. **Continue through all 8 phases**:
   - Follow: `docs/NOTEBOOK-EXECUTION-CHECKLIST.md`
   - Check off each notebook as you complete it
   - Estimated total time: 18-24 hours (plus 5-10 min setup)

7. **Track your progress**:
   - Use: `docs/NOTEBOOK-EXECUTION-CHECKLIST.md` (in the repo)
   - Or create your own execution log in a notebook

### Learning Paths

#### For Beginners (2-3 hours)
1. `notebooks/01-data-collection/prometheus-metrics-collection.ipynb`
2. `notebooks/02-anomaly-detection/01-isolation-forest-implementation.ipynb`
3. `notebooks/03-self-healing-logic/coordination-engine-integration.ipynb`

#### For Intermediate Users (4-6 hours)
1. Complete Beginner path
2. `notebooks/01-data-collection/openshift-events-analysis.ipynb`
3. `notebooks/01-data-collection/log-parsing-analysis.ipynb`
4. `notebooks/01-data-collection/feature-store-demo.ipynb`

#### For Advanced Users (Full Platform - 18-24 hours)
1. Complete Intermediate path
2. All Phase 4 notebooks (Model Serving)
3. All Phase 5 notebooks (End-to-End Scenarios)
4. Phase 6 notebooks (MCP & Lightspeed Integration)
5. Phase 7 notebooks (Monitoring & Operations)
6. Phase 8 notebooks (Advanced Scenarios)

## 📋 Notebook Status & Roadmap

### ✅ ALL 31 NOTEBOOKS COMPLETE! (100%)

**Phase 00: Setup (1 notebook)** ✅ START HERE!
- `00-setup/environment-setup.ipynb` - Environment verification and configuration

**Phase 1: Data Collection (5 notebooks)** ✅
- `01-data-collection/prometheus-metrics-collection.ipynb`
- `01-data-collection/openshift-events-analysis.ipynb`
- `01-data-collection/log-parsing-analysis.ipynb`
- `01-data-collection/feature-store-demo.ipynb`
- `01-data-collection/synthetic-anomaly-generation.ipynb`

**Phase 2: Anomaly Detection (4 notebooks)** ✅
- `02-anomaly-detection/01-isolation-forest-implementation.ipynb`
- `02-anomaly-detection/02-time-series-anomaly-detection.ipynb`
- `02-anomaly-detection/03-lstm-based-prediction.ipynb` ⚠️ GPU Required
- `02-anomaly-detection/04-ensemble-anomaly-methods.ipynb`

**Phase 3: Self-Healing Logic (4 notebooks)** ✅
- `03-self-healing-logic/coordination-engine-integration.ipynb`
- `03-self-healing-logic/rule-based-remediation.ipynb`
- `03-self-healing-logic/ai-driven-decision-making.ipynb`
- `03-self-healing-logic/hybrid-healing-workflows.ipynb`

**Phase 4: Model Serving (3 notebooks)** ✅
- `04-model-serving/kserve-model-deployment.ipynb`
- `04-model-serving/model-versioning-mlops.ipynb`
- `04-model-serving/inference-pipeline-setup.ipynb`

**Phase 5: End-to-End Scenarios (4 notebooks)** ✅
- `05-end-to-end-scenarios/pod-crash-loop-healing.ipynb`
- `05-end-to-end-scenarios/resource-exhaustion-detection.ipynb`
- `05-end-to-end-scenarios/network-anomaly-response.ipynb`
- `05-end-to-end-scenarios/complete-platform-demo.ipynb`

**Phase 6: MCP & Lightspeed Integration (3 notebooks)** ✅
- `06-mcp-lightspeed-integration/mcp-server-integration.ipynb`
- `06-mcp-lightspeed-integration/openshift-lightspeed-integration.ipynb`
- `06-mcp-lightspeed-integration/llamastack-integration.ipynb`

**Phase 7: Monitoring & Operations (3 notebooks)** ✅
- `07-monitoring-operations/prometheus-metrics-monitoring.ipynb`
- `07-monitoring-operations/model-performance-monitoring.ipynb`
- `07-monitoring-operations/healing-success-tracking.ipynb`

**Phase 8: Advanced Scenarios (4 notebooks)** ✅ NEW!
- `08-advanced-scenarios/multi-cluster-healing-coordination.ipynb`
- `08-advanced-scenarios/predictive-scaling-capacity-planning.ipynb`
- `08-advanced-scenarios/security-incident-response-automation.ipynb`
- `08-advanced-scenarios/cost-optimization-resource-efficiency.ipynb`

### 🛠️ Utility Functions (Ready to Use)
- `utils/common_functions.py` - Shared utilities and helpers
- `utils/mcp_client.py` - MCP client library
- `notebooks/README.md` - Comprehensive notebook documentation

## 📚 Additional Resources

### Notebook Execution Guides
- **NOTEBOOK-EXECUTION-READY.md** - Visual overview and quick start (START HERE!)
- **NOTEBOOK-QUICK-REFERENCE.md** - Quick reference card (5 min read)
- **NOTEBOOK-EXECUTION-GUIDE.md** - Detailed execution instructions
- **NOTEBOOK-EXECUTION-CHECKLIST.md** - Step-by-step checklist for all 30 notebooks
- **NOTEBOOK-EXECUTION-SUMMARY.md** - Getting started guide with learning paths
- **NOTEBOOK-ROADMAP.md** - Development roadmap and status

### Documentation
- **Notebook README**: `notebooks/README.md` - Comprehensive guide
- **ADRs**: `docs/adrs/` - Architectural decisions
- **Workbench Access Guide**: `docs/WORKBENCH-ACCESS-GUIDE.md`
- **Deployment Guide**: `docs/DEPLOYMENT-GUIDE.md`

## 🎯 Next Steps (In Workbench)

### Right Now (You're Already Here!)

1. **Open a terminal** in JupyterLab:
   - File → New → Terminal

2. **Clone the repository**:
   ```bash
   cd /opt/app-root/src
   git clone https://gitea-with-admin-gitea.apps.cluster-dzqpc.dzqpc.sandbox29.opentlc.com/user1/openshift-aiops-platform.git
   cd openshift-aiops-platform
   ```

3. **Read the execution guide** (5 minutes):
   - In the file browser, open: `docs/NOTEBOOK-QUICK-REFERENCE.md`
   - Or in terminal: `cat docs/NOTEBOOK-QUICK-REFERENCE.md`

### Start Executing (18-24 hours)

1. **Open the first notebook**:
   - Navigate to: `notebooks/01-data-collection/prometheus-metrics-collection.ipynb`
   - Double-click to open

2. **Run the notebook**:
   - Click "Run All" button
   - Or run cells individually with `Shift+Enter`
   - Wait for completion

3. **Track your progress**:
   - Open: `docs/NOTEBOOK-EXECUTION-CHECKLIST.md`
   - Check off each notebook as you complete it

4. **Continue through all phases**:
   - Phase 1: Data Collection (2-3 hours)
   - Phase 2: Anomaly Detection (3-4 hours)
   - Phase 3: Self-Healing Logic (2-3 hours)
   - Phase 4: Model Serving (2-3 hours)
   - Phase 5: End-to-End Scenarios (2-3 hours)
   - Phase 6: MCP & Lightspeed (2 hours)
   - Phase 7: Monitoring & Operations (2 hours)
   - Phase 8: Advanced Scenarios (2-3 hours)

### Tips for Success

- **Save your work**: Use `Ctrl+S` frequently in notebooks
- **Check outputs**: Review each notebook's output before moving to the next
- **Use persistent storage**: Save models to `/opt/app-root/src/models/`
- **Monitor resources**: Check GPU/CPU usage in terminal: `nvidia-smi` or `top`
- **Create checkpoints**: Save intermediate results to persistent storage
- **Document findings**: Add markdown cells with your observations

---

**Ready to Execute! 🚀** All 30 notebooks are complete and ready for production use!

Start with Phase 1 now! 🎉

## Troubleshooting

### Common Issues

**Issue**: Permission denied when writing files
**Solution**: Use the persistent volumes (`/opt/app-root/src/data` or `/opt/app-root/src/models`)

**Issue**: GPU not available
**Solution**: Check if GPU nodes are available: `oc describe nodes | grep nvidia`

**Issue**: Package installation fails
**Solution**: Use `pip install --user` to install in user directory

### Getting Help

- Check the ADRs in `docs/adrs/` for architectural guidance
- Review the coordination engine source in `src/coordination-engine/`
- Examine Kubernetes configurations in `k8s/`

## Advanced Topics

- **GPU Acceleration**: Using CUDA for training large models
- **Distributed Training**: Multi-node training strategies
- **Model Serving**: Deploying models with KServe
- **Monitoring**: Integrating with Prometheus and Grafana
