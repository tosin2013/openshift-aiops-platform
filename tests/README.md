# Notebook Testing Infrastructure

This directory contains comprehensive testing infrastructure for the OpenShift AIOps Self-Healing Platform notebooks using **Papermill** for notebook execution testing and validation.

## 🎯 Overview

The testing infrastructure provides:
- **Automated notebook execution testing** using Papermill
- **Data validation and quality checks** for notebook outputs
- **CI/CD integration** with GitHub Actions
- **Local development testing** with comprehensive reporting
- **Performance benchmarking** and regression detection

## 📁 Files Structure

```
tests/
├── README.md                      # This file
├── requirements.txt               # Testing dependencies
├── notebook_test_config.yaml     # Comprehensive test configuration
├── notebook_tests.py              # Main testing framework
├── run_notebook_tests.sh          # Local testing script
└── test_notebooks_pytest.py       # Pytest integration
```

## 🚀 Quick Start

### Local Testing

```bash
# Run all notebook tests
./tests/run_notebook_tests.sh

# Run with verbose output
./tests/run_notebook_tests.sh -v

# Test specific notebook
./tests/run_notebook_tests.sh -n prometheus-metrics-collection.ipynb

# Run comprehensive Python-based tests
cd tests
python notebook_tests.py
```

### Pytest Integration

```bash
# Install test dependencies
pip install -r tests/requirements.txt

# Run all notebook tests with pytest
pytest tests/test_notebooks_pytest.py -v

# Run specific test categories
pytest tests/test_notebooks_pytest.py -m data_collection
pytest tests/test_notebooks_pytest.py -m anomaly_detection
pytest tests/test_notebooks_pytest.py -m self_healing
```

## 📊 Tested Notebooks

### ✅ Currently Tested (6 notebooks)

#### Data Collection (4 notebooks)
- **`prometheus-metrics-collection.ipynb`** - Prometheus metrics collection and processing
- **`openshift-events-analysis.ipynb`** - OpenShift events pattern analysis
- **`log-parsing-analysis.ipynb`** - Container log parsing and error detection
- **`feature-store-demo.ipynb`** - Feature store with Parquet files and versioning

#### Anomaly Detection (1 notebook)
- **`isolation-forest-implementation.ipynb`** - Isolation Forest anomaly detection

#### Self-Healing Logic (1 notebook)
- **`coordination-engine-integration.ipynb`** - Coordination engine and MCP client integration

### 🔄 Test Parameters

Each notebook is tested with:
- **`TEST_MODE=true`** - Enables test-specific behavior
- **`SYNTHETIC_DATA_ONLY=true`** - Uses synthetic data instead of real cluster data
- **Custom parameters** - Notebook-specific test parameters (sample sizes, timeouts, etc.)

## 🔧 Configuration

### Test Configuration (`notebook_test_config.yaml`)

The configuration file defines:
- **Execution timeouts** for each notebook
- **Test parameters** passed to notebooks
- **Expected outputs** and validation rules
- **Data quality checks** and assertions
- **Performance benchmarks**

Example configuration:
```yaml
notebooks:
  "01-data-collection/prometheus-metrics-collection.ipynb":
    timeout: 300
    parameters:
      TEST_MODE: true
      SYNTHETIC_DATA_ONLY: true
      MAX_METRICS: 100
    expected_outputs:
      - "metrics_df"
      - "processed_metrics"
    data_validations:
      - variable: "metrics_df"
        type: "DataFrame"
        min_rows: 1
```

### Environment Variables

- **`NOTEBOOK_TEST_MODE`** - Set to `true` to enable test mode
- **`SYNTHETIC_DATA_ONLY`** - Set to `true` to use synthetic data
- **`NOTEBOOK_TEST_TIMEOUT`** - Default timeout in seconds (default: 300)
- **`PYTHONPATH`** - Should include `notebooks/utils` for imports

## 🧪 Testing Framework Features

### 1. Execution Testing
- **Papermill-based execution** - Runs notebooks with parameters
- **Timeout handling** - Prevents hanging tests
- **Error capture** - Detailed error reporting and stack traces
- **Output validation** - Checks for expected notebook outputs

### 2. Data Validation
- **DataFrame validation** - Row counts, column presence, data types
- **Object validation** - Method existence, type checking
- **Value range validation** - Numeric ranges, categorical values
- **Custom assertions** - Notebook-specific validation rules

### 3. Performance Monitoring
- **Execution time tracking** - Performance regression detection
- **Memory usage monitoring** - Resource consumption tracking
- **Benchmark comparison** - Against established baselines
- **Performance alerts** - When thresholds are exceeded

### 4. CI/CD Integration
- **GitHub Actions integration** - Automated testing on commits
- **Artifact generation** - Test reports and notebook outputs
- **Test result summaries** - In GitHub PR comments
- **Failure notifications** - Immediate feedback on issues

## 📈 Test Reports

### JSON Report Format
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "total_notebooks": 6,
  "passed": 5,
  "failed": 1,
  "success_rate": 83.3,
  "notebooks": {
    "01-data-collection/prometheus-metrics-collection.ipynb": {
      "status": "PASSED",
      "execution_time": 45.2,
      "validations": {...}
    }
  }
}
```

### HTML Reports
- **Visual test results** with charts and graphs
- **Execution timeline** showing performance trends
- **Error details** with stack traces and context
- **Validation results** with pass/fail indicators

## 🔍 Troubleshooting

### Common Issues

1. **Import Errors**
   ```bash
   # Ensure PYTHONPATH includes utils
   export PYTHONPATH="$PWD/notebooks/utils:$PYTHONPATH"
   ```

2. **Timeout Issues**
   ```bash
   # Increase timeout for slow notebooks
   export NOTEBOOK_TEST_TIMEOUT=600
   ```

3. **Missing Dependencies**
   ```bash
   # Install all test dependencies
   pip install -r tests/requirements.txt
   ```

4. **Synthetic Data Issues**
   ```bash
   # Ensure test mode is enabled
   export TEST_MODE=true
   export SYNTHETIC_DATA_ONLY=true
   ```

### Debug Mode

```bash
# Run with maximum verbosity
./tests/run_notebook_tests.sh -v --no-cleanup

# Check specific notebook output
papermill notebooks/01-data-collection/prometheus-metrics-collection.ipynb \
  /tmp/debug_output.ipynb \
  -p TEST_MODE true \
  -p SYNTHETIC_DATA_ONLY true
```

## 🚀 CI/CD Pipeline

The testing is integrated into the GitHub Actions pipeline:

```yaml
test-notebooks:
  name: Notebooks - Comprehensive Testing
  runs-on: ubuntu-latest
  steps:
    - name: Run comprehensive notebook tests
      run: |
        cd tests
        python notebook_tests.py
```

### Pipeline Features
- **Parallel execution** (when enabled)
- **Artifact upload** - Test reports and outputs
- **GitHub summaries** - Test results in PR comments
- **Failure notifications** - Immediate feedback

## 📚 Best Practices

### For Notebook Authors
1. **Add test mode support** - Check for `TEST_MODE` environment variable
2. **Use synthetic data** - When `SYNTHETIC_DATA_ONLY=true`
3. **Handle missing dependencies** - Graceful fallbacks for optional imports
4. **Validate outputs** - Ensure expected variables are created
5. **Add documentation** - Clear explanations of test behavior

### For Test Maintainers
1. **Update configurations** - When adding new notebooks
2. **Monitor performance** - Track execution times and resource usage
3. **Review failures** - Investigate and fix failing tests promptly
4. **Update dependencies** - Keep test requirements current
5. **Expand coverage** - Add tests for new notebook features

## 🎯 Future Enhancements

- **Visual regression testing** - Compare notebook output visualizations
- **Integration testing** - Test notebook interactions with live services
- **Load testing** - Test notebooks with large datasets
- **Security testing** - Validate data handling and credential management
- **Cross-platform testing** - Test on different Python versions and OS

## 📞 Support

For issues with notebook testing:
1. Check the troubleshooting section above
2. Review test logs and error messages
3. Verify environment setup and dependencies
4. Check notebook-specific test configurations
5. Create an issue with detailed error information
