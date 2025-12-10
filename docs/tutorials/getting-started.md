---
title: Getting Started with OpenShift AIOps Platform
description: A step-by-step guide to accessing and using the Self-Healing Platform workbench
---

# Getting Started with OpenShift AIOps Platform

Welcome to the **OpenShift AIOps Platform**! This tutorial will guide you through accessing the Self-Healing Platform workbench and running your first AI/ML experiments.

## About Red Hat OpenShift AI (RHODS)

**Red Hat OpenShift AI** (formerly Red Hat OpenShift Data Science) is an enterprise-grade machine learning platform built on Kubernetes. It provides:

- **Workbenches**: Pre-configured Jupyter notebook environments for data science development
- **Model Training**: GPU-accelerated training with PyTorch, TensorFlow, and other frameworks
- **Model Serving**: Deploy trained models as scalable inference endpoints
- **Data Management**: Integrated data storage and feature management
- **Collaboration**: Multi-user support with role-based access control
- **Hardware Acceleration**: GPU and specialized hardware support for ML workloads

The Self-Healing Platform leverages RHODS to provide a complete AI/ML development environment for building anomaly detection models and self-healing algorithms.

## What You'll Learn

By the end of this tutorial, you will:
- Access the RHODS (Red Hat OpenShift AI) workbench
- Verify your development environment (Python, PyTorch, GPU)
- Clone the Self-Healing Platform repository
- Run your first anomaly detection experiment
- Understand the platform's key components and architecture

## Prerequisites

Before you begin, ensure you have:
- **OpenShift Cluster Access**: Access to an OpenShift 4.18+ cluster with Red Hat OpenShift AI installed
- **CLI Tools**: `oc` CLI tool installed and configured on your local machine
- **Credentials**: Valid OpenShift credentials with access to the `self-healing-platform` namespace
- **Basic Knowledge**: Familiarity with Python, Jupyter notebooks, and Git
- **Browser**: A modern web browser for accessing the RHODS dashboard

## Step 1: Access the Red Hat OpenShift AI Dashboard

### 1.1 Open the RHODS Dashboard

The RHODS dashboard is your gateway to the Self-Healing Platform workbench. This is the central hub for managing your data science workbenches, notebooks, and ML projects.

Navigate to the RHODS dashboard:

```
https://rhods-dashboard-redhat-ods-applications.apps.cluster-dzqpc.dzqpc.sandbox29.opentlc.com/
```

You should see the RHODS login page. Authenticate using your OpenShift credentials.

**What is the RHODS Dashboard?**

The RHODS dashboard provides:
- **Workbench Management**: Start, stop, and configure Jupyter notebook environments
- **Project Organization**: Organize your work into data science projects
- **Resource Monitoring**: Track CPU, memory, and GPU usage
- **Model Registry**: Manage and version your trained models
- **Connections**: Configure connections to data sources and external services

### 1.2 Verify Workbench Status

Once logged in, you'll see the RHODS dashboard with available workbenches. A **workbench** in RHODS is a containerized Jupyter notebook environment with pre-installed libraries and tools for data science work.

Verify that the **Self-Healing Workbench** is running:

1. Look for **"self-healing-workbench-dev"** in the workbench list
2. Check that the status shows **Running** (green indicator)
3. If not running, click the **Start** button to launch it
4. Wait for the workbench to initialize (typically 1-2 minutes)

**Expected Result**: You should see a workbench with status "Running" and a **Connect** button available.

**About the Self-Healing Workbench**

The Self-Healing Workbench is configured with:
- **Base Image**: PyTorch 2025.1 with CUDA support
- **Pre-installed Libraries**:
  - PyTorch 2.x for deep learning
  - NumPy, Pandas, Scikit-learn for data processing
  - Prometheus client for metrics collection
  - Kubernetes client for cluster interaction
- **Storage**:
  - 5Gi persistent volume for data and notebooks
  - 10Gi ReadWriteMany volume for shared model artifacts
- **GPU Support**: NVIDIA GPU acceleration (if available in cluster)

## Step 2: Connect to the Workbench

### 2.1 Terminal Access (Recommended)

For immediate productivity, use terminal access via the `oc` CLI:

```bash
# Verify the workbench pod is running
oc get pods -n self-healing-platform | grep workbench

# Expected output:
# self-healing-workbench-dev-0   2/2     Running     0          10m
```

Connect to the workbench terminal:

```bash
# Connect to the workbench container
oc exec -it self-healing-workbench-dev-0 -c self-healing-workbench \
  -n self-healing-platform -- /bin/bash
```

You should see a prompt like:
```
(base) 1001@self-healing-workbench-dev-0:/opt/app-root/src$
```

### 2.2 Web Interface Access (Alternative)

You can also access the workbench through the RHODS web interface:

1. Click the **Connect** button next to the workbench in the RHODS dashboard
2. Wait for JupyterLab to load (this may take 30-60 seconds)
3. You'll see the JupyterLab interface with a file browser on the left

**Note**: The web interface may have configuration complexities with the PyTorch base image. If you experience issues, use terminal access instead.

## Step 3: Verify Your Environment

### 3.1 Check Python and PyTorch

Verify that your development environment is properly configured:

```bash
# Check Python version
python --version
# Expected: Python 3.11.x or higher

# Check PyTorch installation
python -c "import torch; print(f'PyTorch: {torch.__version__}')"
# Expected: PyTorch: 2.x.x

# Check available ML libraries
pip list | grep -E "(torch|numpy|pandas|scikit-learn|prometheus)"
```

### 3.2 Verify GPU Access (Optional)

If GPU nodes are available in your cluster:

```bash
# Check CUDA availability
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"

# Check GPU count
python -c "import torch; print(f'GPU count: {torch.cuda.device_count()}')"

# Test GPU tensor creation
python -c "
import torch
if torch.cuda.is_available():
    x = torch.randn(3, 3).cuda()
    print(f'GPU tensor created: {x.device}')
else:
    print('CUDA not available - CPU mode')
"
```

### 3.3 Verify Persistent Storage

Check that your persistent volumes are mounted:

```bash
# List data directory (5Gi persistent volume)
ls -la /opt/app-root/src/data

# List models directory (10Gi ReadWriteMany persistent volume)
ls -la /opt/app-root/src/models

# Create working directories
mkdir -p /opt/app-root/src/data/notebooks
mkdir -p /opt/app-root/src/data/datasets
mkdir -p /opt/app-root/src/models/checkpoints
```

## Step 4: Clone the Repository

### 4.1 Clone the Project

Inside the workbench terminal, clone the Self-Healing Platform repository:

```bash
# Clone the repository
git clone https://gitea-with-admin-gitea.apps.cluster-dzqpc.dzqpc.sandbox29.opentlc.com/user1/openshift-aiops-platform.git

# Navigate to the project directory
cd openshift-aiops-platform

# Verify the clone
ls -la
```

You should see directories like:
- `docs/` - Documentation and ADRs
- `src/` - Source code
- `k8s/` - Kubernetes manifests
- `notebooks/` - Jupyter notebooks (create if needed)

### 4.2 Install Project Dependencies

```bash
# Install project requirements
pip install --user -r requirements.txt

# Install additional ML libraries for anomaly detection
pip install --user \
    statsmodels>=0.14.0 \
    prophet>=1.1.4 \
    tslearn>=0.6.0 \
    pyod>=1.1.0 \
    xgboost>=2.0.0 \
    prometheus-client>=0.17.0
```

## Step 5: Run Your First Experiment

### 5.1 Create a Simple Anomaly Detection Script

Create a test script to verify everything works:

```bash
# Create a test script
cat > test_anomaly_detection.py << 'EOF'
import torch
import numpy as np
from sklearn.preprocessing import StandardScaler

# Generate sample time series data
np.random.seed(42)
normal_data = np.random.normal(100, 10, 1000)
anomalies = np.array([150, 160, 155])  # Anomalous values
data = np.concatenate([normal_data, anomalies])

# Standardize the data
scaler = StandardScaler()
scaled_data = scaler.fit_transform(data.reshape(-1, 1))

# Simple anomaly detection using z-score
z_scores = np.abs(scaled_data)
threshold = 3
anomaly_indices = np.where(z_scores > threshold)[0]

print(f"Total data points: {len(data)}")
print(f"Detected anomalies: {len(anomaly_indices)}")
print(f"Anomaly indices: {anomaly_indices}")
print(f"PyTorch available: {torch.cuda.is_available()}")
print("✓ Environment verification successful!")
EOF

# Run the test script
python test_anomaly_detection.py
```

**Expected Output**:
```
Total data points: 1003
Detected anomalies: 3
Anomaly indices: [1000 1001 1002]
PyTorch available: False (or True if GPU available)
✓ Environment verification successful!
```

## Step 6: Explore the Platform

### 6.1 Review Architecture Documentation

Understand the platform design:

```bash
# Read the architecture overview
cat docs/explanation/architecture-overview.md

# Review key ADRs
cat docs/adrs/002-hybrid-self-healing-approach.md
cat docs/adrs/011-self-healing-workbench-base-image.md
```

### 6.2 Explore Example Notebooks

Check out example notebooks in the repository:

```bash
# List available notebooks
find . -name "*.ipynb" -type f

# Or create your own notebook directory
mkdir -p notebooks/experiments
cd notebooks/experiments
```

## Summary

In this tutorial, you learned how to:
- ✓ Access the RHODS dashboard and workbench
- ✓ Verify your development environment (Python, PyTorch, GPU)
- ✓ Clone the Self-Healing Platform repository
- ✓ Install project dependencies
- ✓ Run a simple anomaly detection experiment
- ✓ Understand the platform structure

## Next Steps

Now that you have a working environment, explore these resources:

1. **[Workbench Development Guide](./workbench-development-guide.md)** - Deep dive into developing self-healing algorithms
2. **[How to Access Workbench](../how-to/access-workbench.md)** - Detailed access instructions and troubleshooting
3. **[Architecture Overview](../explanation/architecture-overview.md)** - Understand the system design
4. **[ADR Reference](../reference/adrs.md)** - Review architectural decisions

## Troubleshooting

### Issue: Workbench Pod Not Running

```bash
# Check pod status
oc describe pod self-healing-workbench-dev-0 -n self-healing-platform

# Check events
oc get events -n self-healing-platform --sort-by='.lastTimestamp'

# Restart the workbench
oc delete pod self-healing-workbench-dev-0 -n self-healing-platform
```

### Issue: Git Clone Fails

```bash
# Configure git credentials
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Use token authentication if needed
git clone https://username:token@gitea-server/repo.git
```

### Issue: Package Installation Fails

```bash
# Use user installation
pip install --user package_name

# Clear pip cache
pip cache purge

# Check pip configuration
pip config list
```

## Support

If you encounter issues:

1. Check the [How-To Guides](../how-to/) for detailed troubleshooting
2. Review the [ADRs](../reference/adrs.md) for architectural context
3. Check pod logs: `oc logs self-healing-workbench-dev-0 -c self-healing-workbench -n self-healing-platform`
4. Contact the platform team for assistance
