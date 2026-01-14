# Feature: Flexible KServe Model Response Parsing in Coordination Engine

## Summary

Update the coordination engine's `parseForecastResponse()` function to handle multiple KServe model output formats, enabling seamless integration with both custom wrapper models and standard sklearn pipelines.

**Repository**: `openshift-coordination-engine`
**Type**: Enhancement / Bug Fix
**Priority**: High
**Labels**: `enhancement`, `ml-integration`, `kserve`, `api`

---

## Root Cause Analysis

### The Problem

When attempting to use `PredictiveAnalyticsWrapper` (a custom sklearn-compatible class) to output the coordination engine's expected nested format, KServe's sklearn runtime fails to load the model:

```
AttributeError: Can't get attribute 'PredictiveAnalyticsWrapper' on <module '__main__'>
```

### Why This Happens

**Python's pickle serialization requires class definitions at deserialization time.**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       PICKLE SERIALIZATION FLOW                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   TRAINING ENVIRONMENT              INFERENCE ENVIRONMENT                │
│   (Notebook/Workbench)              (KServe sklearn runtime)             │
│   ────────────────────              ────────────────────────             │
│                                                                          │
│   ┌──────────────────────┐          ┌──────────────────────┐            │
│   │ class MyWrapper:     │          │ ❌ Class NOT defined │            │
│   │   def predict():     │          │    here!             │            │
│   │     return {...}     │          │                      │            │
│   └──────────────────────┘          └──────────────────────┘            │
│              │                                  │                        │
│              ▼                                  ▼                        │
│   pickle.dump(wrapper) ──────────► pickle.load() FAILS                  │
│                                                                          │
│   The pickle file contains:         sklearn runtime only has:           │
│   - Class name reference            - sklearn.pipeline.Pipeline         │
│   - Object state                    - sklearn.ensemble.*                │
│   - NOT the class code              - sklearn.preprocessing.*           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Key Insight

**You cannot add custom Python classes to KServe's pre-built sklearn runtime without building a custom container.** This is a fundamental limitation of:
1. Python's pickle serialization
2. KServe's sklearn serving runtime architecture

---

## Architectural Decision

### Why Fix in Coordination Engine (Not Model/KServe)

| Approach | Complexity | Maintenance | Flexibility |
|----------|------------|-------------|-------------|
| Custom KServe Container | High | Every model needs custom image | Low |
| Custom Pickle Classes | High | Fragile, version-dependent | Low |
| **Coordination Engine** | **Low** | **Single place to maintain** | **High** |

**The Coordination Engine is the right place because:**

1. **Single Responsibility**: It's already the orchestration layer between Lightspeed ↔ Models
2. **Centralized Logic**: One fix handles ALL models, current and future
3. **No Custom Containers**: Use standard KServe sklearn runtime
4. **Version Independence**: Model format changes don't break inference
5. **Backwards Compatible**: Supports both old and new format models

### Data Flow (Current vs Fixed)

```
CURRENT (Broken):
─────────────────
KServe sklearn runtime → {"predictions": [[0.604, 0.675]]}
                                    ↓
Coordination Engine parseForecastResponse() → ❌ FAILS
                                    ↓
                         "cannot unmarshal array into map"

FIXED (Flexible):
─────────────────
KServe sklearn runtime → {"predictions": [[0.604, 0.675]]}
                                    ↓
Coordination Engine parseForecastResponse()
  ├─ Try nested format → fails (not a map)
  └─ Try array format → ✅ SUCCESS
                                    ↓
                         Convert to nested format internally
                                    ↓
Lightspeed receives → {"cpu_usage": {...}, "memory_usage": {...}}
```

---

## Implementation

### File to Modify

`pkg/kserve/proxy.go` - Function: `parseForecastResponse()`

### Current Code (Lines 464-488)

```go
func (c *ProxyClient) parseForecastResponse(modelName string, body []byte) (*ModelResponse, error) {
    var forecastResp struct {
        Predictions    map[string]ForecastResult `json:"predictions"`
        // ...
    }
    
    if err := json.Unmarshal(body, &forecastResp); err != nil {
        return nil, fmt.Errorf("failed to decode forecast response: %w", err)
    }
    // Only handles nested format
}
```

### Proposed Code

```go
// parseForecastResponse parses predictive-analytics model responses.
// Supports two formats for flexibility with different model architectures:
//
// Format 1 - Nested (custom wrapper output):
//   {"predictions": {"cpu_usage": {"forecast": [...], ...}, "memory_usage": {...}}}
//
// Format 2 - Array (standard sklearn multi-output):
//   {"predictions": [[cpu_value, memory_value], ...]}
//
func (c *ProxyClient) parseForecastResponse(modelName string, body []byte) (*ModelResponse, error) {
    // Try Format 1: Nested structure
    var nestedResp struct {
        Predictions    map[string]ForecastResult `json:"predictions"`
        ModelName      string                    `json:"model_name,omitempty"`
        ModelVersion   string                    `json:"model_version,omitempty"`
    }
    
    if err := json.Unmarshal(body, &nestedResp); err == nil && 
       nestedResp.Predictions != nil && len(nestedResp.Predictions) > 0 {
        c.log.Debug("Parsed forecast in nested format")
        return &ModelResponse{
            Type: "forecast",
            ForecastResponse: &ForecastResponse{
                Predictions:  nestedResp.Predictions,
                ModelName:    modelName,
                ModelVersion: nestedResp.ModelVersion,
            },
        }, nil
    }
    
    // Fallback to Format 2: Array structure (sklearn multi-output)
    var arrayResp struct {
        Predictions  [][]float64 `json:"predictions"`
        ModelName    string      `json:"model_name,omitempty"`
        ModelVersion string      `json:"model_version,omitempty"`
    }
    
    if err := json.Unmarshal(body, &arrayResp); err != nil {
        return nil, fmt.Errorf("failed to parse forecast response: %w", err)
    }
    
    // Convert array format to nested format
    // Convention: [0] = CPU, [1] = Memory (per model metadata)
    predictions := make(map[string]ForecastResult)
    
    if len(arrayResp.Predictions) > 0 && len(arrayResp.Predictions[0]) >= 2 {
        cpuForecasts := make([]float64, len(arrayResp.Predictions))
        memForecasts := make([]float64, len(arrayResp.Predictions))
        
        for i, pred := range arrayResp.Predictions {
            cpuForecasts[i] = pred[0]
            memForecasts[i] = pred[1]
        }
        
        predictions["cpu_usage"] = ForecastResult{
            Forecast:        cpuForecasts,
            ForecastHorizon: len(cpuForecasts),
            Confidence:      []float64{0.85}, // Default for sklearn
        }
        predictions["memory_usage"] = ForecastResult{
            Forecast:        memForecasts,
            ForecastHorizon: len(memForecasts),
            Confidence:      []float64{0.85},
        }
        
        c.log.WithFields(logrus.Fields{
            "model":  modelName,
            "format": "array_converted",
        }).Debug("Converted array forecast to nested format")
    }
    
    return &ModelResponse{
        Type: "forecast",
        ForecastResponse: &ForecastResponse{
            Predictions:  predictions,
            ModelName:    modelName,
            ModelVersion: arrayResp.ModelVersion,
        },
    }, nil
}
```

---

## Benefits for Future Models

### 1. Model Authors Have Flexibility

| Model Type | Output Format | Coordination Engine |
|------------|---------------|---------------------|
| sklearn Pipeline | `[[cpu, mem]]` | ✅ Supported |
| Custom Wrapper | `{"cpu_usage": {...}}` | ✅ Supported |
| TensorFlow/PyTorch | `[[values...]]` | ✅ Extensible |

### 2. No Custom Containers Required

```yaml
# Works with standard KServe sklearn runtime
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn  # Standard runtime, no custom image
      runtime: sklearn-pvc-runtime
```

### 3. Decoupled Architecture

```
┌─────────────┐     ┌─────────────────────┐     ┌─────────────┐
│   Models    │────▶│ Coordination Engine │────▶│  Lightspeed │
│ (Any Format)│     │ (Format Adapter)    │     │ (Consistent)│
└─────────────┘     └─────────────────────┘     └─────────────┘
     ▲                       ▲
     │                       │
  Flexible              Single place
  output                to maintain
  formats               format logic
```

---

## Testing

### Test Case 1: Array Format (sklearn)

```bash
# Input from KServe
{"predictions": [[0.604, 0.675]]}

# Expected output from Coordination Engine
{
  "predictions": {
    "cpu_usage": {"forecast": [0.604], "forecast_horizon": 1, "confidence": [0.85]},
    "memory_usage": {"forecast": [0.675], "forecast_horizon": 1, "confidence": [0.85]}
  }
}
```

### Test Case 2: Nested Format (custom wrapper)

```bash
# Input from KServe (if custom wrapper worked)
{
  "predictions": {
    "cpu_usage": {"forecast": [0.604], "forecast_horizon": 1, "confidence": [0.92]},
    "memory_usage": {"forecast": [0.675], "forecast_horizon": 1, "confidence": [0.88]}
  }
}

# Expected output (pass-through)
# Same as input
```

---

## Acceptance Criteria

- [ ] `parseForecastResponse()` handles array format `[[cpu, mem]]`
- [ ] `parseForecastResponse()` handles nested format `{"cpu_usage": {...}}`
- [ ] Logs indicate which format was detected
- [ ] Unit tests cover both formats
- [ ] Integration test: Lightspeed query "What will CPU/memory be at 3 PM?" succeeds
- [ ] No changes required to existing models

---

## Related Issues

- `coordination-engine-prediction-type-mismatch.md` - Original error report
- `mcp-server-kserve-url-bug.md` - KServe URL construction issue

## References

- [KServe sklearn Runtime](https://kserve.github.io/website/latest/modelserving/v1beta1/sklearn/)
- [Python Pickle Limitations](https://docs.python.org/3/library/pickle.html#what-can-be-pickled-and-unpickled)
- ADR-039: User-Deployed KServe Models
- ADR-040: Extensible KServe Model Registry
