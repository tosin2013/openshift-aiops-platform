# Notebook Validator Operator Enhancements

## Overview

This document specifies enhancements to the Jupyter Notebook Validator Operator to catch model configuration issues (like missing `--model_name` parameters) before they cause runtime errors in the coordination engine and MCP server.

## Context

**Issue #13 - KServe Model Registration Fix (2026-01-27)**

The MCP server received errors when trying to use model prediction tools because KServe InferenceServices were missing the `--model_name` parameter, causing models to register as `"model"` instead of their actual names.

**Current Notebook Validator Capabilities:**
- ✅ Validates notebooks execute successfully
- ✅ Compares output with golden notebooks
- ✅ Checks model serving platform availability (spec.modelValidation.enabled)
- ✅ Validates predictions match expected output
- ⚠️ **MISSING**: Does not verify model registration names
- ⚠️ **MISSING**: Does not test specific KServe endpoints
- ⚠️ **MISSING**: Does not validate coordination engine integration

## Proposed Enhancements

### Enhancement 1: KServe Model Registration Validation

**What:** Verify that models register with correct names in KServe, not the default "model".

**Why:** Prevents the exact issue we encountered where models registered as "model" instead of "predictive-analytics" or "anomaly-detector".

**Implementation:**

1. **After InferenceService becomes Ready**, get the predictor pod IP
2. **Call `/v1/models` endpoint** to list registered models
3. **Verify the target model name is in the list** (not "model")

**Pseudo-code:**

```python
def validate_model_registration(model_name: str, namespace: str) -> ValidationResult:
    """
    Validates that a KServe model is registered with the correct name.

    Args:
        model_name: Expected model name (e.g., "predictive-analytics")
        namespace: Kubernetes namespace

    Returns:
        ValidationResult with success status and message
    """
    # Get predictor pod for the InferenceService
    pod_ip = get_predictor_pod_ip(
        label_selector=f"serving.kserve.io/inferenceservice={model_name}",
        namespace=namespace
    )

    if not pod_ip:
        return ValidationResult(
            success=False,
            message=f"Predictor pod for {model_name} not found"
        )

    # Test 1: Check /v1/models endpoint
    try:
        response = requests.get(f"http://{pod_ip}:8080/v1/models", timeout=10)
        response.raise_for_status()

        models_list = response.json().get("models", [])

        # CRITICAL CHECK: Verify model name is NOT "model" (the default)
        if "model" in models_list and model_name not in models_list:
            return ValidationResult(
                success=False,
                message=f"Model registered as 'model' instead of '{model_name}'. "
                        f"Missing --model_name parameter in InferenceService args. "
                        f"See docs/MODEL_DEPLOYMENT_CHECKLIST.md for fix."
            )

        # Verify correct model name is registered
        if model_name not in models_list:
            return ValidationResult(
                success=False,
                message=f"Model {model_name} not found in registered models. "
                        f"Found: {models_list}"
            )

    except Exception as e:
        return ValidationResult(
            success=False,
            message=f"Failed to query /v1/models endpoint: {str(e)}"
        )

    return ValidationResult(
        success=True,
        message=f"Model {model_name} registered correctly"
    )
```

**CRD Changes:** None required - this uses existing `spec.modelValidation.targetModels` field.

**Status Update:** Add to `status.modelValidationResult.existingEnvironmentCheck.modelsChecked[]`:
```yaml
modelsChecked:
  - modelName: predictive-analytics
    available: true
    healthy: true
    registrationNameCorrect: true  # NEW FIELD
    message: "Model registered with correct name 'predictive-analytics'"
```

### Enhancement 2: KServe Endpoint Testing

**What:** Test all critical KServe endpoints to ensure model is fully operational.

**Why:** Catches configuration issues, model loading errors, and network problems before deployment.

**Endpoints to Test:**

1. **GET /v1/models** - List all models
2. **GET /v1/models/{name}** - Get model metadata and ready status
3. **POST /v1/models/{name}:predict** - Test prediction with sample data

**Implementation:**

```python
def validate_kserve_endpoints(model_name: str, namespace: str, test_data: dict = None) -> ValidationResult:
    """
    Validates all KServe endpoints for a model.

    Args:
        model_name: Model name (e.g., "predictive-analytics")
        namespace: Kubernetes namespace
        test_data: Optional test data for prediction (from spec.modelValidation.predictionValidation.testData)

    Returns:
        ValidationResult with detailed endpoint test results
    """
    pod_ip = get_predictor_pod_ip(
        label_selector=f"serving.kserve.io/inferenceservice={model_name}",
        namespace=namespace
    )

    results = {
        "list_models": False,
        "get_metadata": False,
        "predict": False
    }
    messages = []

    # Test 1: List models
    try:
        response = requests.get(f"http://{pod_ip}:8080/v1/models", timeout=10)
        response.raise_for_status()
        models = response.json().get("models", [])

        if model_name in models:
            results["list_models"] = True
            messages.append(f"✅ GET /v1/models - Model found in list")
        else:
            messages.append(f"❌ GET /v1/models - Model {model_name} not in list: {models}")
    except Exception as e:
        messages.append(f"❌ GET /v1/models - Failed: {str(e)}")

    # Test 2: Get model metadata
    try:
        response = requests.get(f"http://{pod_ip}:8080/v1/models/{model_name}", timeout=10)
        response.raise_for_status()
        metadata = response.json()

        # Check model is ready
        if metadata.get("ready") == True:
            results["get_metadata"] = True
            messages.append(f"✅ GET /v1/models/{model_name} - Model ready")
        else:
            messages.append(f"❌ GET /v1/models/{model_name} - Model not ready: {metadata}")
    except Exception as e:
        messages.append(f"❌ GET /v1/models/{model_name} - Failed: {str(e)}")

    # Test 3: Prediction endpoint
    if test_data:
        try:
            response = requests.post(
                f"http://{pod_ip}:8080/v1/models/{model_name}:predict",
                json=test_data,
                headers={"Content-Type": "application/json"},
                timeout=30
            )
            response.raise_for_status()
            prediction = response.json()

            if "predictions" in prediction:
                results["predict"] = True
                messages.append(f"✅ POST /v1/models/{model_name}:predict - Prediction successful")
            else:
                messages.append(f"❌ POST /v1/models/{model_name}:predict - No predictions in response: {prediction}")
        except Exception as e:
            messages.append(f"❌ POST /v1/models/{model_name}:predict - Failed: {str(e)}")
    else:
        messages.append(f"⚠️ POST /v1/models/{model_name}:predict - Skipped (no test data)")
        results["predict"] = True  # Don't fail if no test data provided

    all_passed = all(results.values())

    return ValidationResult(
        success=all_passed,
        message="\n".join(messages),
        endpoint_results=results  # NEW: Detailed per-endpoint results
    )
```

**CRD Usage:** Use existing fields:
- `spec.modelValidation.predictionValidation.testData` - JSON test data
- `spec.modelValidation.predictionValidation.expectedOutput` - Expected prediction result
- `spec.modelValidation.timeout` - Timeout for all tests

**Example NotebookValidationJob:**
```yaml
apiVersion: mlops.mlops.dev/v1alpha1
kind: NotebookValidationJob
metadata:
  name: predictive-analytics-validation
spec:
  notebook:
    path: notebooks/predictive-analytics.ipynb
    git:
      url: https://github.com/org/repo.git
      ref: main
  modelValidation:
    enabled: true
    targetModels:
      - predictive-analytics
    predictionValidation:
      enabled: true
      testData: |
        {
          "instances": [
            [0.5, 0.6, 0.4, 100, 80]
          ]
        }
      tolerance: "0.01"
  podConfig:
    containerImage: quay.io/jupyter/minimal-notebook:latest
```

### Enhancement 3: Coordination Engine Integration Testing

**What:** Verify the coordination engine can reach and query the model.

**Why:** Catches network policy issues, service discovery problems, and integration errors.

**Implementation:**

```python
def validate_coordination_engine_integration(model_name: str, namespace: str) -> ValidationResult:
    """
    Validates that the coordination engine can reach the model.

    Args:
        model_name: Model name (e.g., "predictive-analytics")
        namespace: Kubernetes namespace

    Returns:
        ValidationResult with coordination engine integration status
    """
    # Get coordination engine service
    coord_engine_service = f"coordination-engine.{namespace}.svc.cluster.local"
    coord_engine_url = f"http://{coord_engine_service}:8080"

    # Get model predictor service
    predictor_service = f"{model_name}-predictor.{namespace}.svc.cluster.local"

    # Test 1: DNS resolution
    try:
        # Run from validation pod (which has network access)
        dns_result = socket.getaddrinfo(predictor_service, 8080)
        messages = [f"✅ DNS resolution successful: {predictor_service}"]
    except Exception as e:
        return ValidationResult(
            success=False,
            message=f"❌ DNS resolution failed for {predictor_service}: {str(e)}"
        )

    # Test 2: Network connectivity
    try:
        # Use curl from validation pod or direct request
        response = requests.get(
            f"http://{predictor_service}:8080/v1/models",
            timeout=10
        )
        response.raise_for_status()
        messages.append(f"✅ Network connectivity to predictor service successful")
    except Exception as e:
        return ValidationResult(
            success=False,
            message=f"❌ Network connectivity failed: {str(e)}"
        )

    # Test 3: Coordination engine can reach model (optional - may require coordination engine API)
    # This would require the coordination engine to expose an endpoint for model health checks
    # For now, we can verify the predictor service is reachable from the validation pod,
    # which should be sufficient since the coordination engine is in the same namespace

    return ValidationResult(
        success=True,
        message="\n".join(messages)
    )
```

**CRD Changes:** Add optional field for coordination engine URL (use default if not specified):
```yaml
spec:
  modelValidation:
    coordinationEngineURL: "http://coordination-engine:8080"  # NEW FIELD (optional)
```

**Status Update:**
```yaml
status:
  modelValidationResult:
    existingEnvironmentCheck:
      coordinationEngineIntegration:  # NEW SECTION
        dnsResolution: true
        networkConnectivity: true
        success: true
        message: "Coordination engine can reach model"
```

### Enhancement 4: Retry Logic for Model Loading

**What:** Wait for models to load before running validation tests.

**Why:** KServe models can take 30-60 seconds to load after pod starts. Current validation may fail if run too early.

**Implementation:**

```python
def wait_for_model_ready(model_name: str, namespace: str, timeout: int = 300, retry_interval: int = 10) -> bool:
    """
    Waits for a KServe model to become ready.

    Args:
        model_name: Model name
        namespace: Kubernetes namespace
        timeout: Maximum wait time in seconds (default 5 minutes)
        retry_interval: Time between retries in seconds (default 10s)

    Returns:
        True if model becomes ready, False if timeout
    """
    start_time = time.time()

    while time.time() - start_time < timeout:
        try:
            # Check InferenceService status
            inference_service = get_inference_service(model_name, namespace)

            if inference_service.status.ready:
                # Also verify pod is actually serving
                pod_ip = get_predictor_pod_ip(
                    label_selector=f"serving.kserve.io/inferenceservice={model_name}",
                    namespace=namespace
                )

                if pod_ip:
                    try:
                        response = requests.get(f"http://{pod_ip}:8080/v1/models/{model_name}", timeout=5)
                        if response.status_code == 200 and response.json().get("ready"):
                            return True
                    except:
                        pass  # Not ready yet, continue waiting
        except Exception as e:
            logger.debug(f"Waiting for model {model_name}: {str(e)}")

        time.sleep(retry_interval)

    return False
```

**CRD Usage:** Use existing `spec.modelValidation.timeout` field (default: 5m)

**Logging:**
```
[INFO] Waiting for model predictive-analytics to become ready...
[INFO] Model predictive-analytics ready after 45 seconds
```

## Implementation Checklist

### Operator Code Changes

- [ ] Add `validate_model_registration()` function to existing environment check phase
- [ ] Add `validate_kserve_endpoints()` function with comprehensive endpoint testing
- [ ] Add `validate_coordination_engine_integration()` function for integration testing
- [ ] Add `wait_for_model_ready()` with retry logic and configurable timeout
- [ ] Update reconciliation loop to call new validation functions
- [ ] Add detailed error messages referencing MODEL_DEPLOYMENT_CHECKLIST.md

### Status Reporting Enhancements

- [ ] Add `registrationNameCorrect` field to `modelsChecked[]` status
- [ ] Add `endpointResults` section with per-endpoint test results
- [ ] Add `coordinationEngineIntegration` section to status
- [ ] Include specific error messages for common issues:
  - Missing `--model_name` parameter
  - Model file not found
  - Network connectivity issues
  - RBAC permission errors

### CRD Enhancements (Optional)

These are **optional** - existing CRD fields are sufficient for basic functionality:

```yaml
spec:
  modelValidation:
    # OPTIONAL: Coordination engine URL (defaults to http://coordination-engine:8080)
    coordinationEngineURL: "http://coordination-engine:8080"

    # OPTIONAL: Retry configuration for model readiness
    readinessCheck:
      enabled: true  # Default: true
      timeout: "5m"  # Default: same as spec.modelValidation.timeout
      retryInterval: "10s"  # Default: 10 seconds

    # OPTIONAL: Endpoint validation configuration
    endpointValidation:
      enabled: true  # Default: true
      testListModels: true  # Test GET /v1/models
      testMetadata: true  # Test GET /v1/models/{name}
      testPredict: true  # Test POST /v1/models/{name}:predict
```

### Documentation

- [ ] Update operator README with new validation features
- [ ] Add troubleshooting guide for common model registration issues
- [ ] Document how to use `spec.modelValidation.predictionValidation.testData`
- [ ] Add examples of NotebookValidationJob with model validation enabled

## Testing Strategy

### Unit Tests

```python
def test_validate_model_registration_success():
    """Test successful model registration validation."""
    # Mock KServe API responses
    mock_response = {"models": ["predictive-analytics"]}

    result = validate_model_registration("predictive-analytics", "default")

    assert result.success == True
    assert "registered correctly" in result.message

def test_validate_model_registration_default_name():
    """Test detection of default 'model' name issue."""
    # Mock KServe API responses
    mock_response = {"models": ["model"]}  # BUG: Using default name

    result = validate_model_registration("predictive-analytics", "default")

    assert result.success == False
    assert "Missing --model_name parameter" in result.message
    assert "MODEL_DEPLOYMENT_CHECKLIST.md" in result.message

def test_validate_kserve_endpoints():
    """Test KServe endpoint validation."""
    test_data = {"instances": [[1, 2, 3]]}

    result = validate_kserve_endpoints("predictive-analytics", "default", test_data)

    assert result.success == True
    assert result.endpoint_results["list_models"] == True
    assert result.endpoint_results["get_metadata"] == True
    assert result.endpoint_results["predict"] == True

def test_wait_for_model_ready_timeout():
    """Test timeout when model doesn't become ready."""
    result = wait_for_model_ready("nonexistent-model", "default", timeout=5)

    assert result == False
```

### Integration Tests

1. **Deploy InferenceService WITHOUT --model_name** → Validation should FAIL with helpful error
2. **Deploy InferenceService WITH --model_name** → Validation should PASS
3. **Deploy model with invalid model file** → Validation should FAIL with file not found error
4. **Deploy model with network policy blocking coordination engine** → Integration test should FAIL

### E2E Test Scenario

```bash
# 1. Create NotebookValidationJob with model validation
oc apply -f - <<EOF
apiVersion: mlops.mlops.dev/v1alpha1
kind: NotebookValidationJob
metadata:
  name: test-model-validation
  namespace: self-healing-platform
spec:
  notebook:
    path: notebooks/predictive-analytics.ipynb
    git:
      url: https://github.com/org/repo.git
      ref: main
  modelValidation:
    enabled: true
    targetModels:
      - predictive-analytics
    predictionValidation:
      enabled: true
      testData: '{"instances": [[0.5, 0.6, 0.4, 100, 80]]}'
  podConfig:
    containerImage: quay.io/jupyter/minimal-notebook:latest
EOF

# 2. Wait for completion
oc wait --for=jsonpath='{.status.phase}'=Succeeded \
  notebookvalidationjob/test-model-validation \
  -n self-healing-platform \
  --timeout=10m

# 3. Check validation results
oc get notebookvalidationjob test-model-validation -n self-healing-platform -o yaml

# Expected status:
# status:
#   phase: Succeeded
#   modelValidationResult:
#     success: true
#     existingEnvironmentCheck:
#       modelsChecked:
#         - modelName: predictive-analytics
#           available: true
#           healthy: true
#           registrationNameCorrect: true  # ✅ NEW CHECK
#           message: "Model registered with correct name 'predictive-analytics'"
```

## Benefits

### Immediate Benefits

1. **Catches configuration errors early** - Missing `--model_name` detected during validation, not at runtime
2. **Better error messages** - Specific guidance on how to fix issues (references MODEL_DEPLOYMENT_CHECKLIST.md)
3. **Prevents MCP server failures** - Models validated before MCP server tries to query them
4. **Faster troubleshooting** - Validation results show exactly what's wrong

### Long-term Benefits

1. **Repeatability** - Same validation process for all future models
2. **Confidence** - Know models will work before deploying to production
3. **Documentation** - Validation results document what was tested
4. **Integration testing** - Verifies end-to-end integration with coordination engine

## Migration Path

### Phase 1: Implement in Operator (v1.0.6)

- Add new validation functions to operator code
- Update status reporting with new fields
- No CRD changes required (use existing fields)
- **Backward compatible** - existing NotebookValidationJobs continue to work

### Phase 2: Update Documentation

- Create MODEL_DEPLOYMENT_CHECKLIST.md (✅ Done)
- Update operator README
- Add troubleshooting guide
- Document best practices

### Phase 3: Update Existing NotebookValidationJobs

- Add `modelValidation.enabled: true` to predictive-analytics validation
- Add `predictionValidation.testData` for realistic test inputs
- Verify all models pass new validation checks

### Phase 4: CRD Enhancements (v1.1.0 - Optional)

- Add optional fields for coordination engine URL
- Add retry configuration
- Add endpoint validation toggles
- **Backward compatible** - all fields are optional with sensible defaults

## Success Criteria

- [ ] Validation detects missing `--model_name` parameter
- [ ] Validation tests all KServe endpoints (list, metadata, predict)
- [ ] Validation verifies coordination engine can reach model
- [ ] Validation waits for model to load before testing (retry logic)
- [ ] Error messages reference MODEL_DEPLOYMENT_CHECKLIST.md
- [ ] All existing NotebookValidationJobs continue to work (backward compatibility)
- [ ] New validation catches the exact issue from Issue #13

## Example Error Messages

### Missing --model_name Parameter

```
❌ Model Validation Failed: Model Registration Issue

Model 'predictive-analytics' is registered as 'model' instead of 'predictive-analytics'.

This usually means the InferenceService is missing the --model_name parameter.

Fix:
1. Edit charts/hub/templates/model-serving.yaml (or charts/hub/values.yaml if using model loop)
2. Add --model_name parameter to InferenceService args:

   args:
   - --model_name=predictive-analytics  # ← Add this line
   - --model_dir=/mnt/models/predictive-analytics
   - --http_port=8080

3. Commit and sync with ArgoCD

See docs/MODEL_DEPLOYMENT_CHECKLIST.md for detailed instructions.
```

### Model File Not Found

```
❌ Model Validation Failed: Model File Not Found

KServe logs show: "failed to locate model file for model predictive-analytics under dir /mnt/models/predictive-analytics"

This usually means:
1. Notebook didn't save model to correct path
2. PVC mount is not working
3. Directory path doesn't match model name

Fix:
1. Verify model file exists:
   oc exec deployment/predictive-analytics-predictor -- ls -lh /mnt/models/predictive-analytics/model.pkl

2. Check notebook saves to correct path:
   joblib.dump(model, "/mnt/models/predictive-analytics/model.pkl")

See docs/MODEL_DEPLOYMENT_CHECKLIST.md for detailed instructions.
```

## Related Resources

- [MODEL_DEPLOYMENT_CHECKLIST.md](MODEL_DEPLOYMENT_CHECKLIST.md) - Deployment checklist for models
- [KServe SKLearn Server Documentation](https://github.com/kserve/kserve/tree/master/python/sklearnserver)
- [Jupyter Notebook Validator Operator Repository](https://github.com/org/jupyter-notebook-validator-operator)
- ADR-XXX: Model Validation Enhancement (to be created)

## Questions for Implementation

1. **Where is the operator source code?** Need to locate the operator repository to implement these changes
2. **What version should include these enhancements?** Suggest v1.0.6 for bug fix, v1.1.0 for CRD changes
3. **Should this be opt-in or opt-out?** Suggest opt-in via `spec.modelValidation.enabled: true` (current behavior)
4. **Should we add Prometheus metrics?** Could track validation success/failure rates, model load times, etc.
5. **Integration with ArgoCD health checks?** Could use validation results in ArgoCD Application health status
