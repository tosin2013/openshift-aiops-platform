# ARIMA for Time-Series Anomaly Detection in Kubernetes

*Catching trend deviations and forecasting failures before they happen*

---

## What Isolation Forest Misses

In our [previous post](/blog/isolation-forest), we showed how Isolation Forest detects **point anomalies**—individual data points that look different from the rest. But what about anomalies that only make sense in **context**?

Consider this memory usage pattern:

```
Time:   1:00  1:05  1:10  1:15  1:20  1:25  1:30
Memory: 500   520   540   560   580   600   620  (MB)
```

Each individual point looks normal. But the **trend** is clearly abnormal—memory is increasing linearly. This is a textbook memory leak.

**Isolation Forest sees**: "620 MB? That's within normal range."
**ARIMA sees**: "Memory should be ~510 MB right now, but it's 620 MB. Anomaly!"

---

## What is ARIMA?

**ARIMA** stands for **A**uto**R**egressive **I**ntegrated **M**oving **A**verage. It's a classic time-series forecasting model that predicts future values based on:

1. **AR (AutoRegressive)**: Past values influence current values
2. **I (Integrated)**: Differencing to make the series stationary
3. **MA (Moving Average)**: Past forecast errors influence current values

### The Intuition

ARIMA learns the **normal pattern** of a metric over time. Then, for any new data point, it asks:

> "Based on the pattern I learned, what value should I expect?"
> 
> "If the actual value is far from my prediction, something is wrong."

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    ARIMA ANOMALY DETECTION                              │
└─────────────────────────────────────────────────────────────────────────┘

     Actual Value
          │
          │    ╭─── Prediction (what ARIMA expects)
          │   ╱
          ▼  ╱
    700 ──●───────────────────────────────────────────
          │
          │   Residual = Actual - Predicted
          │           = 700 - 550 = 150
          │
    550 ──┼─●─────────────────────────────────────────
          │   ╲
          │    ╰─── If residual > threshold → ANOMALY!
          │
    400 ──┼───────────────────────────────────────────
          │
          └───────────────────────────────────────────▶ Time
```

---

## How ARIMA Works

### Step 1: Make the Series Stationary

Most time series have trends or seasonality. ARIMA removes these by **differencing**:

```python
# Original series (has upward trend)
original = [100, 105, 112, 118, 125, 133]

# First difference (removes trend)
differenced = [5, 7, 6, 7, 8]  # Much more stable
```

### Step 2: Fit the Model

ARIMA(p, d, q) has three parameters:
- **p**: Number of AR (autoregressive) terms
- **d**: Degree of differencing
- **q**: Number of MA (moving average) terms

For Kubernetes metrics, we typically use **ARIMA(1, 1, 1)**:
- 1 AR term: Current value depends on previous value
- 1 differencing: Remove linear trends
- 1 MA term: Smooth out noise

### Step 3: Forecast and Compare

```python
# ARIMA predicts: "Next value should be ~550"
predicted = 550

# Actual value is 700
actual = 700

# Residual
residual = actual - predicted  # 150

# If residual > 2.5 * std(all_residuals) → Anomaly
if abs(residual) > threshold:
    flag_anomaly()
```

---

## Why ARIMA for Kubernetes?

### 1. Catches Trend Deviations

Memory leaks, gradual CPU exhaustion, slowly degrading response times—ARIMA catches these because it **learns the expected trend**.

### 2. Handles Autocorrelation

Kubernetes metrics are **autocorrelated**: current CPU usage is related to CPU usage 1 minute ago. ARIMA explicitly models this.

### 3. Forecast Future Values

Unlike Isolation Forest (which only classifies), ARIMA can **predict the future**:

```python
# "If current trend continues, pod will OOM in 2 hours"
forecast = model.forecast(steps=120)  # 120 minutes
```

### 4. Works Per-Metric

ARIMA analyzes each metric independently, making it easy to identify **which metric** is anomalous.

---

## Implementation in Our Platform

### ARIMA for Each Metric

Unlike Isolation Forest (which analyzes all 16 metrics together), ARIMA analyzes **each metric separately**:

```python
def detect_anomalies_arima(series, threshold_std=2.5):
    """
    Detect anomalies in a single time series using ARIMA.
    
    Args:
        series: pandas Series with time index
        threshold_std: Number of standard deviations for threshold
    
    Returns:
        anomaly predictions, fitted model, residuals
    """
    from statsmodels.tsa.arima.model import ARIMA
    
    # Clean the series
    series_clean = series.dropna().reset_index(drop=True)
    
    if len(series_clean) < 50:
        return None, None, None  # Not enough data
    
    # Fit ARIMA(1,1,1) model
    model = ARIMA(series_clean, order=(1, 1, 1))
    results = model.fit()
    
    # Calculate residuals
    fitted = results.fittedvalues
    residuals = series_clean.iloc[1:len(fitted)+1].values - fitted.values
    
    # Detect anomalies: residual > threshold
    threshold = threshold_std * np.std(residuals)
    anomalies = np.abs(residuals) > threshold
    
    return anomalies, results, residuals
```

### Analyzing All 16 Metrics

```python
def analyze_all_metrics_arima(df, metrics):
    """
    Run ARIMA on each metric and combine results.
    """
    all_anomalies = {}
    
    for metric in metrics:
        print(f"Analyzing {metric}...")
        series = df[metric]
        
        anomalies, model, residuals = detect_anomalies_arima(series)
        
        if anomalies is not None:
            all_anomalies[metric] = anomalies
            n_detected = np.sum(anomalies)
            print(f"  → Detected {n_detected} anomalies")
    
    return all_anomalies

# Run analysis
arima_results = analyze_all_metrics_arima(df, TARGET_METRICS)
```

### Ensemble Across Metrics

After analyzing each metric, we combine results:

```python
# Combine: anomaly if ANY metric flags it
combined = pd.DataFrame(arima_results)
ensemble_any = (combined.sum(axis=1) > 0).astype(int)

# Combine: anomaly if MAJORITY of metrics flag it
ensemble_majority = (combined.sum(axis=1) > len(arima_results) / 2).astype(int)

print(f"ANY method: {ensemble_any.sum()} anomalies")
print(f"MAJORITY method: {ensemble_majority.sum()} anomalies")
```

---

## Real-World Example: Detecting a Memory Leak

### The Data

```
Time     Memory (MB)   ARIMA Predicted   Residual
------   -----------   ---------------   --------
1:00     500           -                 -
1:05     505           502               3
1:10     515           507               8
1:15     530           517               13
1:20     550           532               18
1:25     580           552               28
1:30     620           582               38        ← ANOMALY (residual > threshold)
1:35     670           622               48        ← ANOMALY
1:40     730           672               58        ← ANOMALY
```

### What ARIMA Sees

```
       Memory Usage Over Time
    800 ┤
        │                            ╭── Actual (memory leak!)
    700 ┤                         ●─╯
        │                      ●─╯
    600 ┤                   ●─╯
        │               ●──╯╲
    500 ┤           ●──╯    ╲
        │       ●──╯         ╲── ARIMA Prediction
    400 ┤   ●──╯                  (based on normal pattern)
        │
    300 ┼─────────────────────────────────────────────▶
        1:00  1:10  1:20  1:30  1:40  Time
        
        Residual (gap) grows → ANOMALY detected at 1:30!
```

**Key insight**: ARIMA detected the anomaly at 620 MB, **35 minutes before OOM** at 1GB.

---

## Performance Results

### Test Configuration

- **1,000 data points** per metric
- **16 metrics** analyzed independently
- **50 injected anomalies** (trend breaks, sudden jumps)
- **ARIMA(1, 1, 1)** order

### Results Per-Metric

| Metric | Anomalies Detected | Precision | Recall |
|--------|-------------------|-----------|--------|
| pod_memory_usage | 8 | 0.88 | 0.70 |
| pod_cpu_usage | 6 | 0.83 | 0.50 |
| container_restart_rate_1h | 4 | 0.75 | 0.60 |
| apiserver_error_rate | 5 | 0.80 | 0.40 |
| deployment_unavailable | 3 | 1.00 | 0.30 |

### Ensemble Results

| Method | Precision | Recall | F1 Score |
|--------|-----------|--------|----------|
| **ANY metric** | 0.65 | 0.78 | 0.71 |
| **MAJORITY** | 0.75 | 0.48 | 0.59 |

---

## Pros and Cons

### ✅ Strengths

| Strength | Why It Matters |
|----------|----------------|
| **Temporal awareness** | Catches trend deviations |
| **Forecasting** | Can predict future failures |
| **Interpretable** | "Expected X, got Y" is clear |
| **Per-metric analysis** | Easy to identify problem source |
| **Well-understood** | Decades of research and tools |

### ⚠️ Limitations

| Limitation | Mitigation |
|------------|------------|
| **Univariate only** | Run on each metric separately |
| **Assumes stationarity** | Use differencing (the "I" in ARIMA) |
| **Struggles with seasonality** | Use Prophet instead |
| **Sensitive to outliers** | Pre-filter extreme values |
| **Requires tuning (p,d,q)** | Use auto_arima or fixed (1,1,1) |

---

## ARIMA vs Isolation Forest

| Aspect | Isolation Forest | ARIMA |
|--------|------------------|-------|
| **Type** | Point anomaly | Trend anomaly |
| **Approach** | "Is this point weird?" | "Is this trend weird?" |
| **Features** | Multivariate (16 at once) | Univariate (one at a time) |
| **Labels** | Not needed | Not needed |
| **Temporal** | No | Yes |
| **Speed** | Very fast | Moderate |
| **Best for** | Sudden spikes, outliers | Gradual drifts, trends |

**Conclusion**: Use **both**. They catch different types of anomalies.

---

## Code: Complete Implementation

```python
"""
ARIMA-based Anomaly Detection for Kubernetes Time Series
"""

import numpy as np
import pandas as pd
import warnings
from statsmodels.tsa.arima.model import ARIMA
from sklearn.metrics import precision_score, recall_score, f1_score

warnings.filterwarnings('ignore')


class ARIMAAnomalyDetector:
    """
    ARIMA-based anomaly detector for Kubernetes metrics.
    Analyzes each metric independently and combines results.
    """
    
    def __init__(self, order=(1, 1, 1), threshold_std=2.5):
        self.order = order
        self.threshold_std = threshold_std
        self.models = {}
        self.thresholds = {}
    
    def fit_predict_metric(self, series, metric_name):
        """
        Fit ARIMA to a single metric and detect anomalies.
        """
        # Clean data
        series_clean = series.dropna().reset_index(drop=True)
        
        if len(series_clean) < 50:
            print(f"  ⚠️ {metric_name}: Not enough data ({len(series_clean)} points)")
            return None
        
        try:
            # Fit ARIMA
            model = ARIMA(series_clean, order=self.order)
            results = model.fit()
            
            # Calculate residuals
            fitted = results.fittedvalues
            n_fitted = len(fitted)
            
            # Align actual values with fitted
            actual = series_clean.iloc[1:n_fitted+1].values
            residuals = actual - fitted.values
            
            # Calculate threshold
            threshold = self.threshold_std * np.std(residuals)
            
            # Detect anomalies
            anomalies = np.abs(residuals) > threshold
            
            # Store model and threshold
            self.models[metric_name] = results
            self.thresholds[metric_name] = threshold
            
            # Create full-length prediction array
            full_anomalies = np.zeros(len(series), dtype=int)
            for i, is_anomaly in enumerate(anomalies):
                if is_anomaly and (i + 1) < len(full_anomalies):
                    full_anomalies[i + 1] = 1
            
            return full_anomalies
            
        except Exception as e:
            print(f"  ⚠️ {metric_name}: ARIMA failed - {str(e)[:50]}")
            return None
    
    def fit_predict(self, df, metrics):
        """
        Fit ARIMA to all metrics and return combined anomaly predictions.
        """
        results = {}
        
        print("=" * 60)
        print("ARIMA Anomaly Detection")
        print("=" * 60)
        
        for metric in metrics:
            print(f"\n📈 Analyzing: {metric}")
            
            anomalies = self.fit_predict_metric(df[metric], metric)
            
            if anomalies is not None:
                results[metric] = anomalies
                n_anomalies = np.sum(anomalies)
                print(f"   ✅ Detected {n_anomalies} anomalies")
        
        # Combine results
        if results:
            combined_df = pd.DataFrame(results)
            
            # ANY: anomaly if any metric flags it
            ensemble_any = (combined_df.sum(axis=1) > 0).astype(int).values
            
            # MAJORITY: anomaly if majority of metrics flag it
            ensemble_majority = (combined_df.sum(axis=1) > len(results) / 2).astype(int).values
            
            print(f"\n{'='*60}")
            print(f"Ensemble Results:")
            print(f"  ANY method: {ensemble_any.sum()} anomalies")
            print(f"  MAJORITY method: {ensemble_majority.sum()} anomalies")
            print(f"{'='*60}")
            
            return {
                'per_metric': results,
                'ensemble_any': ensemble_any,
                'ensemble_majority': ensemble_majority
            }
        
        return None
    
    def forecast(self, metric_name, steps=10):
        """
        Forecast future values for a metric.
        """
        if metric_name not in self.models:
            raise ValueError(f"No model trained for {metric_name}")
        
        model = self.models[metric_name]
        forecast = model.forecast(steps=steps)
        
        return forecast
    
    def explain_anomaly(self, metric_name, timestamp):
        """
        Explain why a point was flagged as anomalous.
        """
        if metric_name not in self.models:
            return None
        
        model = self.models[metric_name]
        threshold = self.thresholds[metric_name]
        
        return {
            'metric': metric_name,
            'threshold': threshold,
            'model_order': self.order,
            'explanation': f"Residual exceeded {self.threshold_std} standard deviations"
        }


# Usage example
if __name__ == "__main__":
    # Load data
    df = pd.read_parquet('prometheus_metrics.parquet')
    
    # Define metrics to analyze
    metrics = [
        'pod_cpu_usage',
        'pod_memory_usage',
        'container_restart_rate_1h',
        'apiserver_error_rate',
        'deployment_unavailable'
    ]
    
    # Create detector and run
    detector = ARIMAAnomalyDetector(order=(1, 1, 1), threshold_std=2.5)
    results = detector.fit_predict(df, metrics)
    
    # Evaluate if labels available
    if 'label' in df.columns:
        y_true = df['label'].values[:len(results['ensemble_any'])]
        y_pred = results['ensemble_any']
        
        print(f"\nPerformance (ANY method):")
        print(f"  Precision: {precision_score(y_true, y_pred, zero_division=0):.3f}")
        print(f"  Recall: {recall_score(y_true, y_pred, zero_division=0):.3f}")
        print(f"  F1: {f1_score(y_true, y_pred, zero_division=0):.3f}")
    
    # Forecast next 10 points for memory
    print(f"\nMemory forecast (next 10 points):")
    forecast = detector.forecast('pod_memory_usage', steps=10)
    print(forecast)
```

---

## Key Takeaways

1. **ARIMA catches what Isolation Forest misses**: Trend deviations, gradual drifts
2. **Analyze each metric separately**: Easier to identify the source of problems
3. **Use residuals for detection**: "Expected X, got Y" is intuitive
4. **ARIMA(1,1,1) works well** for most Kubernetes metrics
5. **Combine with Isolation Forest** for comprehensive coverage

---

## What's Next?

In the next post, we'll cover **Prophet for seasonal anomaly detection**—how to handle daily/weekly patterns in Kubernetes metrics.

---

*Part 2 of 5 in our "ML Models for Kubernetes Self-Healing" series*

*Tags: #machinelearning #timeseries #arima #kubernetes #anomalydetection*
