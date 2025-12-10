# ADR-008: Kubeflow Pipelines for MLOps Automation

## Status

⚠️ **DEPRECATED** (2025-12-01)

---

## ⚠️ DEPRECATION NOTICE

**This ADR is DEPRECATED as of 2025-12-01.**

**Reason**: The proposed Kubeflow Pipelines implementation was never realized. The actual MLOps architecture uses:
- **Tekton Pipelines** for infrastructure validation (ADR-021)
- **Jupyter Notebook Validator Operator** for notebook execution (ADR-029)
- **Direct notebook execution** in OpenShift AI workbenches (ADR-011, ADR-012)

**Superseded By**:
- **ADR-021**: Tekton Pipeline for Post-Deployment Validation (infrastructure validation)
- **ADR-029**: Jupyter Notebook Validator Operator (notebook validation and execution)
- **ADR-027**: CI/CD Pipeline Automation with Tekton and ArgoCD

**Evidence of Non-Implementation**:
- ❌ No Kubeflow Pipeline YAML definitions in codebase
- ❌ No `kfp` (Kubeflow Pipelines SDK) imports in Python code
- ❌ No Kubeflow components or pipeline definitions
- ✅ Tekton extensively used for all pipeline automation (ADR-021, ADR-027)
- ✅ Notebooks executed directly via operator (ADR-029) or workbenches (ADR-011)

**Migration Path**: No migration needed - this ADR was never implemented.

**Historical Value**: This ADR is preserved for historical context showing the original MLOps approach considered but not implemented. The detailed pipeline code examples below represent the original design intent, not actual implementation.

---

## Original ADR Content (For Historical Reference)

## Context

The Self-Healing Platform requires automated MLOps pipelines to support:

- **Continuous Model Training**: Automated retraining based on new operational data
- **Model Validation**: Automated testing and validation of model performance
- **Model Deployment**: Seamless deployment of validated models to production
- **Data Pipeline Management**: Automated data ingestion, preprocessing, and feature engineering
- **Experiment Tracking**: Version control and comparison of model experiments

### Current Environment Analysis

Our OpenShift AI 2.22.2 deployment includes:
- **Data Science Pipelines**: Kubeflow Pipelines integrated with OpenShift AI
- **Pipeline Components**: Pre-built components for common ML tasks
- **Workflow Engine**: Argo Workflows for pipeline execution
- **Artifact Storage**: S3-compatible storage for pipeline artifacts
- **Experiment Tracking**: MLflow integration for experiment management

### Requirements from PRD

- Automated pipeline for ingesting, cleaning, and preprocessing operational data
- Support for training anomaly detection and operational AI models
- Automated model validation and deployment workflows
- Integration with Prometheus for data collection
- Scheduled retraining (weekly) and event-driven retraining

## Decision

We will use **Kubeflow Pipelines** (via OpenShift AI Data Science Pipelines) as the primary MLOps automation platform for the Self-Healing Platform.

### Key Pipeline Capabilities

1. **Workflow Orchestration**
   - DAG-based pipeline definition and execution
   - Conditional execution and branching logic
   - Parallel execution of independent tasks
   - Error handling and retry mechanisms

2. **Component Ecosystem**
   - Pre-built components for common ML tasks
   - Custom component development support
   - Reusable pipeline templates
   - Integration with popular ML frameworks

3. **Artifact Management**
   - Versioned storage of datasets, models, and metrics
   - Lineage tracking for reproducibility
   - Metadata management for experiments
   - Integration with model registries

4. **Scheduling and Triggers**
   - Cron-based scheduling for regular retraining
   - Event-driven triggers for data drift detection
   - Manual pipeline execution for experimentation
   - Integration with external systems via webhooks

## Alternatives Considered

### Apache Airflow
- **Pros**: Mature workflow orchestration, rich operator ecosystem, good monitoring
- **Cons**: Not ML-focused, requires separate ML tooling, complex setup
- **Verdict**: Rejected - general-purpose workflow tool, not optimized for ML

### MLflow Pipelines
- **Pros**: Integrated with MLflow ecosystem, good for experiment tracking
- **Cons**: Limited workflow orchestration, less mature than Kubeflow
- **Verdict**: Rejected - insufficient workflow capabilities

### Tekton Pipelines
- **Pros**: Kubernetes-native, good CI/CD integration, already available in cluster
- **Cons**: Not ML-focused, requires custom ML components, steeper learning curve
- **Verdict**: Rejected - general-purpose CI/CD tool, not optimized for ML workflows

### Custom Pipeline Solution
- **Pros**: Tailored to specific needs, full control over workflow logic
- **Cons**: Significant development effort, maintenance overhead, reinventing solutions
- **Verdict**: Rejected - Kubeflow Pipelines provides comprehensive ML-focused solution

## Consequences

### Positive

- **ML-Focused**: Purpose-built for machine learning workflows
- **Integrated Platform**: Native integration with OpenShift AI ecosystem
- **Proven Solution**: Battle-tested in production ML environments
- **Rich Ecosystem**: Extensive library of pre-built ML components
- **Experiment Tracking**: Built-in experiment management and comparison
- **Existing Deployment**: Already available via OpenShift AI 2.22.2

### Negative

- **Learning Curve**: Team needs to learn Kubeflow-specific concepts and SDK
- **Resource Overhead**: Additional components consume cluster resources
- **Complexity**: Can be complex for simple ML workflows
- **Vendor Dependency**: Tied to Kubeflow ecosystem and release cycles

### Neutral

- **Python-Centric**: Primarily Python-focused, good fit for ML teams
- **Cloud Native**: Kubernetes-native architecture aligns with platform strategy
- **Extensibility**: Can be extended with custom components as needed

## Implementation Architecture

### Self-Healing MLOps Pipeline

```python
from kfp import dsl, components
from kfp.client import Client

@dsl.component
def data_ingestion_op(
    prometheus_url: str,
    start_time: str,
    end_time: str
) -> str:
    """Ingest operational data from Prometheus"""
    import pandas as pd
    from prometheus_api_client import PrometheusConnect

    prom = PrometheusConnect(url=prometheus_url)

    # Query operational metrics
    queries = {
        'cpu': 'rate(container_cpu_usage_seconds_total[5m])',
        'memory': 'container_memory_working_set_bytes',
        'network': 'rate(container_network_receive_bytes_total[5m])'
    }

    data = {}
    for metric, query in queries.items():
        data[metric] = prom.get_metric_range_data(query, start_time, end_time)

    # Save to artifact storage
    dataset_path = '/tmp/operational_data.parquet'
    pd.DataFrame(data).to_parquet(dataset_path)

    return dataset_path

@dsl.component
def feature_engineering_op(dataset_path: str) -> str:
    """Engineer features for anomaly detection"""
    import pandas as pd
    import numpy as np

    df = pd.read_parquet(dataset_path)

    # Time-based features
    df['hour'] = pd.to_datetime(df['timestamp']).dt.hour
    df['day_of_week'] = pd.to_datetime(df['timestamp']).dt.dayofweek

    # Statistical features
    df['cpu_rolling_mean'] = df['cpu'].rolling(window=10).mean()
    df['memory_rolling_std'] = df['memory'].rolling(window=10).std()

    # Save engineered features
    features_path = '/tmp/engineered_features.parquet'
    df.to_parquet(features_path)

    return features_path

@dsl.component
def model_training_op(features_path: str) -> str:
    """Train anomaly detection model"""
    import pandas as pd
    from sklearn.ensemble import IsolationForest
    from sklearn.preprocessing import StandardScaler
    import joblib

    df = pd.read_parquet(features_path)

    # Prepare training data
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(df.select_dtypes(include=[np.number]))

    # Train model
    model = IsolationForest(contamination=0.1, random_state=42)
    model.fit(X_scaled)

    # Save model artifacts
    model_path = '/tmp/anomaly_model.pkl'
    scaler_path = '/tmp/scaler.pkl'

    joblib.dump(model, model_path)
    joblib.dump(scaler, scaler_path)

    return model_path

@dsl.component
def model_validation_op(model_path: str, test_data_path: str) -> bool:
    """Validate model performance"""
    import joblib
    import pandas as pd
    from sklearn.metrics import classification_report

    model = joblib.load(model_path)
    test_data = pd.read_parquet(test_data_path)

    # Perform validation
    predictions = model.predict(test_data)
    accuracy = (predictions == 1).mean()  # Normal samples should be 1

    # Validation threshold
    return accuracy > 0.8

@dsl.component
def model_deployment_op(model_path: str, model_name: str):
    """Deploy model to KServe"""
    import yaml
    from kubernetes import client, config

    # KServe InferenceService definition
    inference_service = {
        'apiVersion': 'serving.kserve.io/v1beta1',
        'kind': 'InferenceService',
        'metadata': {
            'name': model_name,
            'namespace': 'self-healing-platform'
        },
        'spec': {
            'predictor': {
                'sklearn': {
                    'storageUri': f's3://model-storage/{model_name}/',
                    'resources': {
                        'requests': {'cpu': '1', 'memory': '2Gi'},
                        'limits': {'cpu': '2', 'memory': '4Gi'}
                    }
                }
            }
        }
    }

    # Deploy to cluster
    config.load_incluster_config()
    api = client.CustomObjectsApi()
    api.create_namespaced_custom_object(
        group='serving.kserve.io',
        version='v1beta1',
        namespace='self-healing-platform',
        plural='inferenceservices',
        body=inference_service
    )

@dsl.pipeline(
    name='self-healing-mlops-pipeline',
    description='Automated MLOps pipeline for Self-Healing Platform'
)
def self_healing_pipeline(
    prometheus_url: str = 'http://prometheus.openshift-monitoring.svc:9090',
    model_name: str = 'anomaly-detector'
):
    # Data ingestion
    data_task = data_ingestion_op(
        prometheus_url=prometheus_url,
        start_time='2024-01-01T00:00:00Z',
        end_time='2024-01-02T00:00:00Z'
    )

    # Feature engineering
    features_task = feature_engineering_op(
        dataset_path=data_task.output
    )

    # Model training
    training_task = model_training_op(
        features_path=features_task.output
    )

    # Model validation
    validation_task = model_validation_op(
        model_path=training_task.output,
        test_data_path=features_task.output
    )

    # Conditional deployment
    with dsl.Condition(validation_task.output == True):
        deployment_task = model_deployment_op(
            model_path=training_task.output,
            model_name=model_name
        )
```

### Pipeline Scheduling

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: self-healing-mlops-schedule
  namespace: self-healing-platform
spec:
  schedule: "0 2 * * 0"  # Weekly on Sunday at 2 AM
  workflowSpec:
    entrypoint: mlops-pipeline
    templates:
    - name: mlops-pipeline
      dag:
        tasks:
        - name: trigger-pipeline
          template: kfp-trigger
```

## Monitoring and Observability

### Pipeline Metrics

- **Pipeline Success Rate**: Percentage of successful pipeline runs
- **Pipeline Duration**: Time taken for complete pipeline execution
- **Model Performance**: Accuracy and performance metrics over time
- **Resource Utilization**: CPU/memory usage during pipeline execution

### Alert Configuration

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mlops-pipeline-alerts
spec:
  groups:
  - name: mlops.rules
    rules:
    - alert: MLOpsPipelineFailure
      expr: kfp_pipeline_run_status{status="Failed"} > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "MLOps pipeline execution failed"

    - alert: ModelPerformanceDegradation
      expr: model_accuracy < 0.8
      for: 15m
      labels:
        severity: critical
      annotations:
        summary: "Model performance has degraded below threshold"
```

## Success Metrics

- **Pipeline Reliability**: >95% successful pipeline execution rate
- **Training Frequency**: Weekly automated retraining with <4 hour execution time
- **Model Deployment**: <30 minutes from validation to production deployment
- **Data Freshness**: <24 hours from data generation to model training

## Related ADRs

- [ADR-003: Red Hat OpenShift AI for ML Platform](003-openshift-ai-ml-platform.md)
- [ADR-004: KServe for Model Serving Infrastructure](004-kserve-model-serving.md)
- [ADR-007: Prometheus-Based Monitoring and Data Collection](007-prometheus-monitoring-integration.md)

## References

- [Kubeflow Pipelines Documentation](https://www.kubeflow.org/docs/components/pipelines/)
- [OpenShift AI Data Science Pipelines](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.22/html/working_with_data_science_pipelines)
- [Self-Healing Platform PRD](../../PRD.md) - Section 5.5: MLOps Pipeline Configuration
