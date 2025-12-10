---
title: Working with RHODS Notebooks
description: Guide to using Jupyter notebooks in Red Hat OpenShift AI for AI/ML development
---

# Working with RHODS Notebooks

This guide explains how to use Jupyter notebooks in Red Hat OpenShift AI (RHODS) for developing anomaly detection models and self-healing algorithms.

## What is a RHODS Notebook?

A **RHODS notebook** is a Jupyter notebook environment running in a containerized workbench on OpenShift. It provides:

- **Interactive Development**: Write and execute Python code in cells
- **Data Visualization**: Create plots and visualizations inline
- **Documentation**: Mix code, markdown, and visualizations
- **Persistence**: Save notebooks to persistent storage
- **Collaboration**: Share notebooks with team members
- **GPU Access**: Use GPU acceleration for model training

## Accessing Notebooks

### Via Web Interface

1. Open the RHODS dashboard
2. Click **Connect** on the Self-Healing Workbench
3. JupyterLab will open in a new tab
4. You'll see the file browser on the left

### Via Terminal

```bash
# Connect to workbench terminal
oc exec -it self-healing-workbench-dev-0 -c self-healing-workbench \
  -n self-healing-platform -- /bin/bash

# Start Jupyter Lab (if not already running)
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root
```

## Creating Your First Notebook

### Step 1: Create a New Notebook

In JupyterLab:

1. Click the **+** button in the file browser
2. Select **Python 3** from the Notebook section
3. A new notebook will open

### Step 2: Add Your First Cell

In the first cell, add:

```python
import torch
import numpy as np
import pandas as pd

print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print("✓ Environment ready!")
```

Click the **Run** button (▶) or press `Shift+Enter` to execute.

### Step 3: Save Your Notebook

```bash
# Notebooks are auto-saved, but you can also:
# Use Ctrl+S or File > Save Notebook

# Save to persistent storage
# File > Save As > /opt/app-root/src/data/notebooks/my_notebook.ipynb
```

## Working with Data

### Loading Data

```python
import pandas as pd

# Load CSV from persistent storage
df = pd.read_csv('/opt/app-root/src/data/datasets/my_data.csv')

# Display first few rows
print(df.head())
print(df.info())
```

### Saving Results

```python
# Save processed data
df.to_csv('/opt/app-root/src/data/datasets/processed_data.csv', index=False)

# Save plots
import matplotlib.pyplot as plt
plt.savefig('/opt/app-root/src/data/notebooks/plot.png', dpi=300, bbox_inches='tight')
```

## Building Anomaly Detection Models

### Example: Simple Anomaly Detection

```python
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import IsolationForest

# Generate sample data
np.random.seed(42)
normal_data = np.random.normal(100, 10, 1000)
anomalies = np.array([150, 160, 155])
data = np.concatenate([normal_data, anomalies]).reshape(-1, 1)

# Standardize
scaler = StandardScaler()
scaled_data = scaler.fit_transform(data)

# Train Isolation Forest
model = IsolationForest(contamination=0.01, random_state=42)
predictions = model.fit_predict(scaled_data)

# Identify anomalies
anomaly_indices = np.where(predictions == -1)[0]
print(f"Detected {len(anomaly_indices)} anomalies")
```

## Using GPU Acceleration

### Check GPU Availability

```python
import torch

print(f"CUDA available: {torch.cuda.is_available()}")
print(f"GPU count: {torch.cuda.device_count()}")

if torch.cuda.is_available():
    print(f"Current GPU: {torch.cuda.get_device_name(0)}")
    print(f"GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")
```

### Train on GPU

```python
import torch
import torch.nn as nn

# Create model
model = nn.Sequential(
    nn.Linear(10, 64),
    nn.ReLU(),
    nn.Linear(64, 1)
)

# Move to GPU if available
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model = model.to(device)

# Create sample data
X = torch.randn(100, 10).to(device)
y = torch.randn(100, 1).to(device)

# Training loop
optimizer = torch.optim.Adam(model.parameters())
criterion = nn.MSELoss()

for epoch in range(10):
    optimizer.zero_grad()
    output = model(X)
    loss = criterion(output, y)
    loss.backward()
    optimizer.step()
    print(f"Epoch {epoch+1}, Loss: {loss.item():.4f}")
```

## Saving Models

### Save PyTorch Models

```python
import torch

# Save model state
torch.save(model.state_dict(), '/opt/app-root/src/models/trained/model.pth')

# Save entire model
torch.save(model, '/opt/app-root/src/models/trained/model_full.pth')

# Load model
loaded_model = torch.load('/opt/app-root/src/models/trained/model.pth')
```

### Save Scikit-learn Models

```python
import joblib

# Save model
joblib.dump(model, '/opt/app-root/src/models/trained/sklearn_model.pkl')

# Load model
loaded_model = joblib.load('/opt/app-root/src/models/trained/sklearn_model.pkl')
```

## Visualization

### Create Plots

```python
import matplotlib.pyplot as plt
import seaborn as sns

# Set style
sns.set_style("darkgrid")

# Create figure
fig, axes = plt.subplots(2, 2, figsize=(12, 10))

# Plot data
axes[0, 0].plot(data)
axes[0, 0].set_title('Time Series Data')

# Plot distribution
axes[0, 1].hist(data, bins=50)
axes[0, 1].set_title('Distribution')

# Plot anomalies
axes[1, 0].scatter(range(len(data)), data, c=predictions, cmap='coolwarm')
axes[1, 0].set_title('Anomaly Detection Results')

plt.tight_layout()
plt.show()

# Save figure
plt.savefig('/opt/app-root/src/data/notebooks/analysis.png', dpi=300)
```

## Best Practices

### 1. Organize Your Work

```bash
# Create a clear structure
/opt/app-root/src/data/
├── notebooks/          # Your Jupyter notebooks
├── datasets/           # Input data
└── experiments/        # Experiment results

/opt/app-root/src/models/
├── trained/            # Trained models
├── checkpoints/        # Training checkpoints
└── artifacts/          # Model artifacts
```

### 2. Document Your Code

```python
"""
Anomaly Detection Model Training

This notebook trains an Isolation Forest model for detecting
anomalies in time series data from Prometheus metrics.

Author: Your Name
Date: 2025-01-16
"""

# Add markdown cells to explain your approach
# Use comments in code cells for complex logic
```

### 3. Version Your Work

```bash
# Use git to version notebooks
git add notebooks/my_notebook.ipynb
git commit -m "Add anomaly detection model training"
git push origin feature/anomaly-detection
```

### 4. Monitor Resources

```python
import psutil
import torch

# Check CPU usage
print(f"CPU usage: {psutil.cpu_percent()}%")
print(f"Memory usage: {psutil.virtual_memory().percent}%")

# Check GPU usage (if available)
if torch.cuda.is_available():
    print(f"GPU memory used: {torch.cuda.memory_allocated() / 1e9:.2f} GB")
```

## Troubleshooting

### Issue: Notebook Kernel Dies

**Solution**:
```python
# Restart kernel: Kernel > Restart Kernel
# Clear memory: %reset -f
# Check memory usage: !free -h
```

### Issue: Out of Memory

**Solution**:
```python
# Process data in batches
batch_size = 1000
for i in range(0, len(data), batch_size):
    batch = data[i:i+batch_size]
    # Process batch
```

### Issue: GPU Out of Memory

**Solution**:
```python
# Clear GPU cache
torch.cuda.empty_cache()

# Use smaller batch sizes
batch_size = 32  # Reduce from 128
```

## Next Steps

- Review [Workbench Development Guide](../tutorials/workbench-development-guide.md)
- Explore [Architecture Overview](../explanation/architecture-overview.md)
- Check [ADR-012: Notebook Architecture](../adrs/012-notebook-architecture-for-end-to-end-workflows.md)
