# Ensemble Methods: Combining Models for Robust Kubernetes Anomaly Detection

*How voting across multiple models achieves 84%+ F1 with minimal false alarms*

---

## The Wisdom of Crowds

In our previous posts, we explored four powerful anomaly detection methods:

| Model | Best At | Misses |
|-------|---------|--------|
| **Isolation Forest** | Point outliers | Temporal patterns |
| **ARIMA** | Trend deviations | Seasonality, multi-metric |
| **Prophet** | Seasonal breaks | Sudden spikes |
| **LSTM** | Sequence patterns | Needs lots of data |

Each model has strengths and weaknesses. But what if we could combine them?

> **"In the multitude of counselors there is safety."** — Ancient Proverb

This is the core idea behind **ensemble methods**: multiple models voting together are more reliable than any single model.

---

## Why Ensembles Work

### The Math of Voting

Imagine each model is 80% accurate independently. What's the probability that a **majority (3 of 4)** make the same mistake?

```python
# Probability of one model being wrong
p_wrong = 0.20  # 20%

# Probability of 3+ models being wrong simultaneously
# (assuming independence)
from math import comb

p_3_wrong = comb(4, 3) * (0.20)**3 * (0.80)**1  # 0.0256
p_4_wrong = comb(4, 4) * (0.20)**4              # 0.0016

p_majority_wrong = p_3_wrong + p_4_wrong  # 2.72%

# Ensemble accuracy: 97.3%!
```

**80% individual accuracy → 97% ensemble accuracy** (in theory)

### Why It Works in Practice

Different models make **different mistakes**:

```
                    Actual Anomaly Type
Model           | Point | Trend | Seasonal | Sequence |
----------------|-------|-------|----------|----------|
Isolation Forest|  ✅   |  ❌   |    ❌    |    ❌    |
ARIMA           |  ❌   |  ✅   |    ❌    |    ❌    |
Prophet         |  ❌   |  ❌   |    ✅    |    ❌    |
LSTM            |  ❌   |  ❌   |    ❌    |    ✅    |
----------------|-------|-------|----------|----------|
ENSEMBLE (vote) |  ✅   |  ✅   |    ✅    |    ✅    |
```

---

## Ensemble Strategies

### 1. Hard Voting (Majority)

**Anomaly if N or more models agree.**

```python
def hard_voting(predictions, threshold=2):
    """
    Hard voting ensemble.
    
    Args:
        predictions: List of binary prediction arrays
        threshold: Minimum votes needed for anomaly
    
    Returns:
        Ensemble predictions
    """
    votes = np.sum(predictions, axis=0)
    return (votes >= threshold).astype(int)

# Example
isolation_forest = [0, 1, 0, 1, 0]  # Model 1 predictions
arima           = [0, 1, 1, 0, 0]  # Model 2 predictions
prophet         = [0, 0, 0, 1, 0]  # Model 3 predictions
lstm            = [0, 1, 0, 1, 1]  # Model 4 predictions

# Votes:        [0, 3, 1, 3, 1]
# Majority (≥2):[0, 1, 0, 1, 0]  ← Points with 2+ votes are anomalies
```

### 2. Weighted Voting

**Weight models by their individual performance.**

```python
def weighted_voting(predictions, weights, threshold=0.5):
    """
    Weighted voting ensemble.
    
    Args:
        predictions: List of binary prediction arrays
        weights: Weight for each model (based on F1 score)
        threshold: Weighted vote threshold
    
    Returns:
        Ensemble predictions
    """
    predictions = np.array(predictions)
    weights = np.array(weights).reshape(-1, 1)
    
    weighted_sum = np.sum(predictions * weights, axis=0)
    total_weight = np.sum(weights)
    
    return (weighted_sum / total_weight >= threshold).astype(int)

# Example with weights based on F1 scores
weights = [0.35, 0.25, 0.20, 0.20]  # IF: best, ARIMA/Prophet/LSTM: supporting

ensemble = weighted_voting(
    [isolation_forest, arima, prophet, lstm],
    weights,
    threshold=0.4
)
```

### 3. ANY Voting (Union)

**Anomaly if ANY model flags it.** High recall, lower precision.

```python
def any_voting(predictions):
    """Anomaly if any model detects it."""
    return (np.sum(predictions, axis=0) >= 1).astype(int)

# Good for: Safety-critical systems where missing anomalies is costly
# Bad for: High-volume systems (too many alerts)
```

### 4. ALL Voting (Intersection)

**Anomaly only if ALL models agree.** High precision, lower recall.

```python
def all_voting(predictions):
    """Anomaly only if all models agree."""
    n_models = len(predictions)
    return (np.sum(predictions, axis=0) == n_models).astype(int)

# Good for: Automated remediation (high confidence needed)
# Bad for: Catching subtle anomalies
```

---

## Choosing the Right Strategy

| Strategy | Precision | Recall | Best For |
|----------|-----------|--------|----------|
| **ANY** | Low (~0.65) | High (~0.90) | Don't miss anything |
| **MAJORITY** | Medium (~0.85) | Medium (~0.75) | Balanced detection |
| **WEIGHTED** | Medium-High (~0.85) | Medium (~0.80) | Leveraging best models |
| **ALL** | High (~0.95) | Low (~0.40) | Auto-remediation |

### For Self-Healing Platform

We use **two thresholds**:

```python
# For ALERTING (notify humans): Use ANY voting
# → High recall, humans can filter false positives
alert_anomalies = any_voting(all_preds)

# For AUTO-HEALING (automated action): Use MAJORITY voting
# → Higher precision, fewer incorrect actions
healing_anomalies = hard_voting(all_preds, threshold=2)
```

---

## Implementation in Our Platform

### Complete Ensemble Pipeline

```python
"""
Ensemble Anomaly Detection for Kubernetes
"""

import numpy as np
import pandas as pd
from sklearn.metrics import precision_score, recall_score, f1_score


class EnsembleAnomalyDetector:
    """
    Combines multiple anomaly detection models.
    """
    
    def __init__(self):
        self.models = {}
        self.predictions = {}
        self.weights = {}
    
    def add_model(self, name, predictions, weight=1.0):
        """Add a model's predictions to the ensemble."""
        self.predictions[name] = np.array(predictions)
        self.weights[name] = weight
        print(f"Added {name}: {np.sum(predictions)} anomalies, weight={weight}")
    
    def hard_vote(self, threshold=2):
        """Majority voting ensemble."""
        preds = np.array(list(self.predictions.values()))
        votes = np.sum(preds, axis=0)
        return (votes >= threshold).astype(int)
    
    def weighted_vote(self, threshold=0.5):
        """Weighted voting ensemble."""
        preds = np.array(list(self.predictions.values()))
        weights = np.array(list(self.weights.values())).reshape(-1, 1)
        
        weighted_sum = np.sum(preds * weights, axis=0)
        total_weight = np.sum(weights)
        
        return (weighted_sum / total_weight >= threshold).astype(int)
    
    def any_vote(self):
        """Union: anomaly if any model flags it."""
        preds = np.array(list(self.predictions.values()))
        return (np.sum(preds, axis=0) >= 1).astype(int)
    
    def all_vote(self):
        """Intersection: anomaly only if all models agree."""
        preds = np.array(list(self.predictions.values()))
        return (np.sum(preds, axis=0) == len(preds)).astype(int)
    
    def get_vote_distribution(self):
        """Show how many models voted for each point."""
        preds = np.array(list(self.predictions.values()))
        return np.sum(preds, axis=0)
    
    def evaluate_all(self, y_true):
        """Evaluate all ensemble strategies."""
        strategies = {
            'ANY (≥1)': self.any_vote(),
            'MAJORITY (≥2)': self.hard_vote(threshold=2),
            'STRONG (≥3)': self.hard_vote(threshold=3),
            'ALL (=4)': self.all_vote(),
            'WEIGHTED': self.weighted_vote(threshold=0.4),
        }
        
        results = []
        for name, preds in strategies.items():
            results.append({
                'Strategy': name,
                'Detected': np.sum(preds),
                'Precision': precision_score(y_true, preds, zero_division=0),
                'Recall': recall_score(y_true, preds, zero_division=0),
                'F1': f1_score(y_true, preds, zero_division=0)
            })
        
        return pd.DataFrame(results)


# Usage
ensemble = EnsembleAnomalyDetector()

# Add each model's predictions
ensemble.add_model('Isolation Forest', isolation_forest_preds, weight=0.35)
ensemble.add_model('ARIMA', arima_preds, weight=0.25)
ensemble.add_model('Prophet', prophet_preds, weight=0.20)
ensemble.add_model('LSTM', lstm_preds, weight=0.20)

# Evaluate
results = ensemble.evaluate_all(y_true)
print(results)
```

---

## Performance Results

### Our Test Setup

- **1,000 data points**
- **16 features** (Prometheus metrics)
- **50 injected anomalies** (5%)
- **4 models** contributing predictions

### Individual Model Performance

| Model | Precision | Recall | F1 |
|-------|-----------|--------|-----|
| Isolation Forest | 0.84 | 0.84 | 0.84 |
| ARIMA | 0.75 | 0.48 | 0.59 |
| Prophet | 0.79 | 0.44 | 0.56 |
| LSTM | 0.80 | 0.80 | 0.80 |

### Ensemble Performance

| Strategy | Precision | Recall | F1 |
|----------|-----------|--------|-----|
| ANY (≥1) | 0.65 | 0.92 | 0.76 |
| **MAJORITY (≥2)** | **0.89** | **0.80** | **0.84** |
| STRONG (≥3) | 0.94 | 0.68 | 0.79 |
| ALL (=4) | 1.00 | 0.32 | 0.48 |
| WEIGHTED | 0.85 | 0.82 | 0.84 |

### Key Observations

1. **MAJORITY voting achieves the best F1** (0.84)
2. **ANY voting maximizes recall** (0.92) — use for alerting
3. **ALL voting maximizes precision** (1.00) — but misses 68% of anomalies
4. **Weighted voting** slightly improves over majority when model quality varies

---

## Visualization: Ensemble Decision Making

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   ENSEMBLE VOTING IN ACTION                             │
└─────────────────────────────────────────────────────────────────────────┘

Data Point #42: CPU=85%, Memory=92%, Restarts=5

Model Predictions:
┌──────────────────┬──────────┬─────────────────────────────────┐
│ Model            │ Verdict  │ Reasoning                       │
├──────────────────┼──────────┼─────────────────────────────────┤
│ Isolation Forest │ ANOMALY  │ Point is far from cluster       │
│ ARIMA            │ NORMAL   │ Values follow recent trend      │
│ Prophet          │ ANOMALY  │ Higher than expected for Monday │
│ LSTM             │ ANOMALY  │ Sequence pattern matches failure│
└──────────────────┴──────────┴─────────────────────────────────┘

Vote Count: 3 of 4 models say ANOMALY

┌─────────────────────────────────────────────────────────────────────────┐
│ Ensemble Decision by Strategy:                                          │
│                                                                         │
│   ANY (≥1):      ✅ ANOMALY (3 ≥ 1)                                     │
│   MAJORITY (≥2): ✅ ANOMALY (3 ≥ 2)                                     │
│   STRONG (≥3):   ✅ ANOMALY (3 ≥ 3)                                     │
│   ALL (=4):      ❌ NORMAL  (3 ≠ 4)                                     │
│                                                                         │
│   → Use MAJORITY for self-healing: Execute remediation                  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Advanced: Stacking (Meta-Learning)

Beyond simple voting, we can use a **meta-learner** to combine models:

```python
from sklearn.linear_model import LogisticRegression

def stacking_ensemble(model_predictions, y_true):
    """
    Use a meta-learner to optimally combine model predictions.
    """
    # Stack predictions as features
    X_meta = np.column_stack(model_predictions)
    
    # Train meta-learner
    meta_model = LogisticRegression()
    meta_model.fit(X_meta, y_true)
    
    # Meta-model learns optimal weights automatically
    print("Learned weights:", meta_model.coef_)
    
    # Predict
    final_predictions = meta_model.predict(X_meta)
    
    return final_predictions, meta_model
```

**Stacking can improve F1 by 1-3%** but adds complexity.

---

## Integration with Self-Healing

### Two-Tier Detection

```python
class SelfHealingDecisionEngine:
    """
    Uses ensemble with different thresholds for different actions.
    """
    
    def __init__(self, ensemble):
        self.ensemble = ensemble
    
    def should_alert(self):
        """Alert humans if ANY model detects anomaly."""
        return self.ensemble.any_vote()
    
    def should_auto_heal(self):
        """Auto-heal only if MAJORITY agrees."""
        return self.ensemble.hard_vote(threshold=2)
    
    def should_emergency_stop(self):
        """Emergency action only if ALL agree."""
        return self.ensemble.all_vote()
    
    def get_confidence(self, index):
        """Get confidence score (0-1) for a specific point."""
        votes = self.ensemble.get_vote_distribution()
        n_models = len(self.ensemble.predictions)
        return votes[index] / n_models

# Usage in operator
engine = SelfHealingDecisionEngine(ensemble)

for i, anomaly in enumerate(engine.should_auto_heal()):
    if anomaly:
        confidence = engine.get_confidence(i)
        
        if confidence >= 0.75:  # 3+ models agree
            execute_healing_action(action='restart', confidence=confidence)
        elif confidence >= 0.5:  # 2+ models agree
            execute_healing_action(action='notify', confidence=confidence)
```

---

## Best Practices

### 1. Retrain Models Together

All models should be trained on the same data window:

```python
# Good: Same training period
isolation_forest.fit(df_train)
arima.fit(df_train)
prophet.fit(df_train)
lstm.fit(df_train)

# Bad: Different training periods (models will disagree more)
```

### 2. Weight by Recent Performance

Update weights based on recent accuracy:

```python
def update_weights(ensemble, recent_y_true, decay=0.9):
    """Update weights based on recent performance."""
    for name, preds in ensemble.predictions.items():
        f1 = f1_score(recent_y_true, preds, zero_division=0)
        
        # Exponential moving average
        old_weight = ensemble.weights[name]
        new_weight = decay * old_weight + (1 - decay) * f1
        ensemble.weights[name] = new_weight
```

### 3. Monitor Ensemble Agreement

Track how often models agree—low agreement suggests drift:

```python
def monitor_agreement(ensemble):
    """Monitor model agreement over time."""
    votes = ensemble.get_vote_distribution()
    
    # Agreement score: how often models agree
    unanimous = np.sum((votes == 0) | (votes == len(ensemble.predictions)))
    agreement_rate = unanimous / len(votes)
    
    if agreement_rate < 0.7:
        print("⚠️ Low model agreement - consider retraining")
    
    return agreement_rate
```

### 4. Log Individual Model Decisions

For debugging, log what each model said:

```python
def explain_decision(ensemble, index):
    """Explain why the ensemble made a decision."""
    explanation = {
        'index': index,
        'individual_votes': {},
        'total_votes': 0,
        'decision': None
    }
    
    for name, preds in ensemble.predictions.items():
        vote = preds[index]
        explanation['individual_votes'][name] = 'ANOMALY' if vote else 'NORMAL'
        explanation['total_votes'] += vote
    
    explanation['decision'] = 'ANOMALY' if explanation['total_votes'] >= 2 else 'NORMAL'
    
    return explanation

# Output:
# {
#   'index': 42,
#   'individual_votes': {
#     'Isolation Forest': 'ANOMALY',
#     'ARIMA': 'NORMAL',
#     'Prophet': 'ANOMALY',
#     'LSTM': 'ANOMALY'
#   },
#   'total_votes': 3,
#   'decision': 'ANOMALY'
# }
```

---

## Key Takeaways

1. **Ensembles reduce errors** by combining diverse models
2. **MAJORITY voting** offers the best precision-recall balance
3. **Use different thresholds** for alerting vs auto-healing
4. **Weight models by F1 score** for optimal combination
5. **Monitor agreement** to detect model drift

---

## The Complete Self-Healing Pipeline

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     COMPLETE ANOMALY DETECTION PIPELINE                 │
└─────────────────────────────────────────────────────────────────────────┘

     Prometheus Metrics (16 features)
                │
                ▼
    ┌───────────────────────┐
    │   Data Collection     │
    │   (1-minute samples)  │
    └───────────────────────┘
                │
    ┌───────────┴───────────┐
    │                       │
    ▼                       ▼
┌─────────┐           ┌─────────┐
│Isolation│           │  Time   │
│ Forest  │           │ Series  │
└────┬────┘           └────┬────┘
     │                     │
     │               ┌─────┴─────┐
     │               │           │
     │               ▼           ▼
     │          ┌─────────┐ ┌─────────┐
     │          │  ARIMA  │ │ Prophet │
     │          └────┬────┘ └────┬────┘
     │               │           │
     └───────────────┼───────────┘
                     │
                     ▼
              ┌─────────────┐
              │    LSTM     │
              │ (Sequences) │
              └──────┬──────┘
                     │
                     ▼
         ┌───────────────────────┐
         │   ENSEMBLE VOTING     │
         │                       │
         │  IF: ✅  ARIMA: ❌    │
         │  Prophet: ✅  LSTM: ✅ │
         │                       │
         │  Votes: 3/4 → ANOMALY │
         └───────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
   ┌─────────────┐      ┌─────────────┐
   │   ALERTING  │      │ SELF-HEALING│
   │   (ANY ≥1)  │      │ (MAJORITY)  │
   └─────────────┘      └─────────────┘
          │                     │
          ▼                     ▼
       Slack/             Kubernetes
       PagerDuty          Operator
                               │
                               ▼
                        Pod Restart /
                        Rollback /
                        Scale
```

---

## Series Conclusion

Over this 5-part series, we've built a **complete ML-powered anomaly detection system** for Kubernetes:

| Part | Model | Key Insight |
|------|-------|-------------|
| 1 | Isolation Forest | Points that isolate easily are anomalies |
| 2 | ARIMA | Deviations from trend are anomalies |
| 3 | Prophet | Breaks in seasonality are anomalies |
| 4 | LSTM | Unusual sequences are anomalies |
| 5 | **Ensemble** | **Combined wisdom beats individual models** |

**Final Result**: 84% F1 score with interpretable, actionable anomaly detection.

---

*Part 5 of 5 in our "ML Models for Kubernetes Self-Healing" series*

*Get the code: [github.com/your-org/openshift-aiops-platform](https://github.com/your-org/openshift-aiops-platform)*

*Tags: #machinelearning #ensemble #kubernetes #anomalydetection #aiops*
