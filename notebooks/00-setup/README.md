# Phase 00: Environment Setup

**Status**: ✅ Ready
**Time**: 5-10 minutes
**Objective**: Verify and configure the workbench environment

## Overview

This phase contains a single setup notebook that verifies your RHODS workbench is properly configured before executing the 30 notebooks in the Self-Healing Platform.

## Notebooks

### 00-environment-setup.ipynb

**Purpose**: Verify and configure the workbench environment

**What It Does**:
1. ✅ Verifies Python and PyTorch installation
2. ✅ Checks GPU availability
3. ✅ Verifies persistent storage volumes
4. ✅ Tests required dependencies
5. ✅ Creates necessary directories
6. ✅ Generates setup summary report

**Time**: 5-10 minutes

**Key Outputs**:
- Setup summary report (JSON)
- Directory structure created
- Dependency verification

**Success Criteria**:
- ✅ Python 3.11+ installed
- ✅ PyTorch 2025.1 available
- ✅ Persistent storage volumes accessible
- ✅ Most dependencies installed
- ✅ Directories created

## How to Run

1. **Open the notebook**:
   - In JupyterLab, navigate to: `notebooks/00-setup/`
   - Double-click: `environment-setup.ipynb`

2. **Run all cells**:
   - Click "Run All" button
   - Or run cells individually with `Shift+Enter`

3. **Review the output**:
   - Check Python and PyTorch versions
   - Verify GPU availability
   - Review dependency status
   - Check persistent storage

4. **Address any issues**:
   - If GPU not available: You can still run most notebooks on CPU
   - If dependencies missing: Run the pip install command shown
   - If storage not found: Contact administrator

## What Happens

### Step 1: Python & PyTorch Verification
```
✓ Python Version: 3.11.x
✓ PyTorch Version: 2025.1
```

### Step 2: GPU Check
```
✓ CUDA Available: True/False
✓ GPU Device Count: 1 (or more)
✓ GPU Test: PASSED
```

### Step 3: Storage Verification
```
✓ Data Volume: /opt/app-root/src/data (20GB)
✓ Models Volume: /opt/app-root/src/models (50GB)
```

### Step 4: Dependency Check
```
✓ NumPy
✓ Pandas
✓ Scikit-learn
... (16 more packages)
```

### Step 5: Directory Creation
```
✓ /opt/app-root/src/data/processed
✓ /opt/app-root/src/data/training
✓ /opt/app-root/src/data/reports
✓ /opt/app-root/src/models/anomaly-detection
✓ /opt/app-root/src/models/serving
✓ /opt/app-root/src/models/checkpoints
```

### Step 6: Summary Report
```
Setup Timestamp: 2025-10-17T...
Python Version: 3.11.x
PyTorch Version: 2025.1
CUDA Available: True/False
GPU Count: 1
Dependencies: 16/16 installed
Data Volume: ✓
Models Volume: ✓
```

## Troubleshooting

### GPU Not Available
- **Issue**: CUDA Available: False
- **Solution**: You can still run all notebooks except Phase 2 LSTM on CPU
- **Note**: Phase 2 LSTM notebook requires GPU for reasonable performance

### Missing Dependencies
- **Issue**: Some packages show as NOT INSTALLED
- **Solution**: Run the pip install command shown in the notebook
- **Command**: `pip install --user <package-names>`

### Storage Not Found
- **Issue**: Data or Models volume not found
- **Solution**: Contact your administrator
- **Note**: These volumes are required for persistent storage

### Python Version Mismatch
- **Issue**: Python version is not 3.11+
- **Solution**: Contact your administrator
- **Note**: PyTorch 2025.1 requires Python 3.11+

## Next Steps

After setup is complete:

1. **Review the summary** - Ensure all checks passed
2. **Address any issues** - Follow troubleshooting if needed
3. **Start Phase 1** - Navigate to `notebooks/01-data-collection/`
4. **Open first notebook** - `01-prometheus-metrics-collection.ipynb`
5. **Follow execution checklist** - Use `docs/NOTEBOOK-EXECUTION-CHECKLIST.md`

## Execution Timeline

After setup, you'll execute:

| Phase | Notebooks | Time |
|-------|-----------|------|
| 1: Data Collection | 5 | 2-3h |
| 2: Anomaly Detection | 4 | 3-4h |
| 3: Self-Healing Logic | 4 | 2-3h |
| 4: Model Serving | 3 | 2-3h |
| 5: End-to-End Scenarios | 4 | 2-3h |
| 6: MCP & Lightspeed | 3 | 2h |
| 7: Monitoring & Operations | 3 | 2h |
| 8: Advanced Scenarios | 4 | 2-3h |
| **TOTAL** | **30** | **18-24h** |

---

**Ready to start? Open `environment-setup.ipynb` now! 🚀**
