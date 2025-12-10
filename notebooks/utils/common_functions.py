"""
Common utility functions for Self-Healing Platform notebooks

This module provides shared functionality across all notebooks including:
- Data validation and quality checks
- Visualization helpers
- Storage management
- Configuration management

References:
- ADR-012: Notebook Architecture for End-to-End Workflows
- ADR-013: Data Collection and Preprocessing Workflows
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime, timedelta
import os
import json
import warnings
import requests
from typing import Dict, List, Tuple, Optional, Any

# Suppress warnings for cleaner notebook output
warnings.filterwarnings('ignore')

# Configuration constants
DATA_DIR = '/opt/app-root/src/data'
MODELS_DIR = '/opt/app-root/src/models'
CONFIG_DIR = '/opt/app-root/src/.config'

# Quality thresholds
QUALITY_THRESHOLDS = {
    'missing_values_threshold': 0.05,
    'outlier_ratio_threshold': 0.05,
    'time_gap_tolerance_minutes': 5,
    'minimum_quality_score': 0.7
}

# Prometheus configuration for in-cluster access
PROMETHEUS_CONFIG = {
    'base_url': 'https://prometheus-k8s.openshift-monitoring.svc.cluster.local:9091',
    'thanos_url': 'https://thanos-querier.openshift-monitoring.svc.cluster.local:9091',
    'timeout': 30,
    'max_samples': 10000
}

def setup_environment() -> Dict[str, Any]:
    """
    Set up the notebook environment and verify prerequisites

    Returns:
        Dict containing environment information
    """
    env_info = {
        'data_dir': DATA_DIR,
        'models_dir': MODELS_DIR,
        'workbench_detected': False,
        'storage_available_gb': 0,
        'python_version': None,
        'key_libraries': {}
    }

    # Create necessary directories
    os.makedirs(f"{DATA_DIR}/prometheus", exist_ok=True)
    os.makedirs(f"{DATA_DIR}/processed", exist_ok=True)
    os.makedirs(f"{DATA_DIR}/synthetic", exist_ok=True)
    os.makedirs(f"{MODELS_DIR}/anomaly-detection", exist_ok=True)
    os.makedirs(f"{MODELS_DIR}/checkpoints", exist_ok=True)

    # Check if running in workbench
    env_info['workbench_detected'] = os.path.exists('/opt/app-root/src/.jupyter')

    # Calculate available storage
    try:
        stat = os.statvfs(DATA_DIR)
        env_info['storage_available_gb'] = stat.f_bavail * stat.f_frsize / (1024**3)
    except:
        env_info['storage_available_gb'] = 0

    # Get Python version
    import sys
    env_info['python_version'] = sys.version

    # Check key libraries
    try:
        import torch
        env_info['key_libraries']['torch'] = torch.__version__
    except ImportError:
        env_info['key_libraries']['torch'] = 'Not available'

    try:
        env_info['key_libraries']['pandas'] = pd.__version__
        env_info['key_libraries']['numpy'] = np.__version__
    except:
        pass

    return env_info

def print_environment_info(env_info: Dict[str, Any]) -> None:
    """Print formatted environment information"""
    print("🔧 Environment Setup")
    print("=" * 50)
    print(f"📁 Data directory: {env_info['data_dir']}")
    print(f"🗃️ Models directory: {env_info['models_dir']}")
    print(f"💾 Available storage: {env_info['storage_available_gb']:.2f} GB")

    if env_info['workbench_detected']:
        print("✅ Running in Self-Healing Workbench environment")
    else:
        print("⚠️ Not in expected workbench environment")

    print(f"🐍 Python: {env_info['python_version'].split()[0]}")

    print("\n📚 Key Libraries:")
    for lib, version in env_info['key_libraries'].items():
        print(f"  {lib}: {version}")
    print()

def generate_synthetic_timeseries(
    metric_name: str,
    duration_hours: int = 24,
    interval_minutes: int = 1,
    add_anomalies: bool = True,
    anomaly_probability: float = 0.02
) -> pd.DataFrame:
    """
    Generate synthetic time-series data that mimics real OpenShift metrics

    Args:
        metric_name: Name of the metric to generate
        duration_hours: Duration of data to generate
        interval_minutes: Interval between data points
        add_anomalies: Whether to inject anomalies
        anomaly_probability: Probability of anomalies

    Returns:
        DataFrame with timestamp, value, and metric columns
    """
    # Calculate number of data points
    num_points = int(duration_hours * 60 / interval_minutes)

    # Create time index
    end_time = datetime.now()
    start_time = end_time - timedelta(hours=duration_hours)
    timestamps = pd.date_range(start=start_time, end=end_time, periods=num_points)

    # Generate base pattern based on metric type
    if 'cpu' in metric_name.lower():
        # CPU usage: daily pattern with business hours spike
        hour_of_day = np.array([t.hour for t in timestamps])
        base_pattern = 20 + 30 * np.exp(-((hour_of_day - 14) ** 2) / 50)  # Peak at 2 PM
        daily_cycle = 10 * np.sin(2 * np.pi * np.arange(num_points) / (24 * 60))
        noise = np.random.normal(0, 5, num_points)
        values = np.clip(base_pattern + daily_cycle + noise, 0, 100)

    elif 'memory' in metric_name.lower():
        # Memory usage: gradual increase with occasional drops (GC events)
        trend = np.linspace(40, 70, num_points)
        noise = np.random.normal(0, 3, num_points)
        # Garbage collection events
        gc_events = np.random.choice([0, -15], num_points, p=[0.995, 0.005])
        values = np.clip(trend + noise + gc_events, 10, 95)

    elif 'restart' in metric_name.lower():
        # Container restarts: mostly zero with occasional spikes
        values = np.random.poisson(0.05, num_points)

    elif 'disk' in metric_name.lower():
        # Disk I/O: bursty pattern
        base = np.random.exponential(10, num_points)
        burst_indices = np.random.choice(num_points, size=int(num_points * 0.1), replace=False)
        base[burst_indices] *= np.random.uniform(5, 20, len(burst_indices))
        values = np.clip(base, 0, 100)

    elif 'network' in metric_name.lower():
        # Network traffic: periodic with random spikes
        periodic = 20 + 15 * np.sin(2 * np.pi * np.arange(num_points) / 360)  # 6-hour cycle
        noise = np.random.normal(0, 5, num_points)
        values = np.clip(periodic + noise, 0, 100)

    else:
        # Generic metric: normal distribution with slight trend
        trend = np.linspace(45, 55, num_points)
        noise = np.random.normal(0, 8, num_points)
        values = np.clip(trend + noise, 0, 100)

    # Add anomalies if requested
    if add_anomalies:
        anomaly_indices = np.random.choice(
            num_points,
            size=int(num_points * anomaly_probability),
            replace=False
        )

        for idx in anomaly_indices:
            if 'restart' in metric_name.lower():
                values[idx] += np.random.poisson(5)
            else:
                # Add spike or drop
                if np.random.random() > 0.5:
                    values[idx] *= np.random.uniform(2, 4)  # Spike
                else:
                    values[idx] *= np.random.uniform(0.1, 0.3)  # Drop
                values[idx] = np.clip(values[idx], 0, 100)

    # Create DataFrame
    df = pd.DataFrame({
        'timestamp': timestamps,
        'value': values,
        'metric': metric_name,
        'is_anomaly': False
    })

    # Mark anomalies
    if add_anomalies and len(anomaly_indices) > 0:
        df.loc[anomaly_indices, 'is_anomaly'] = True

    return df

def validate_data_quality(df: pd.DataFrame, metric_name: str) -> Dict[str, Any]:
    """
    Perform comprehensive data quality validation

    Args:
        df: DataFrame with time-series data
        metric_name: Name of the metric being validated

    Returns:
        Dictionary with quality scores and issues
    """
    quality_result = {
        'metric_name': metric_name,
        'total_points': len(df),
        'scores': {
            'completeness': 0.0,
            'consistency': 0.0,
            'accuracy': 0.0,
            'overall': 0.0
        },
        'issues': [],
        'recommendations': []
    }

    # Completeness check
    missing_count = df['value'].isnull().sum()
    missing_ratio = missing_count / len(df)
    quality_result['scores']['completeness'] = max(0, 1 - missing_ratio * 20)

    if missing_ratio > QUALITY_THRESHOLDS['missing_values_threshold']:
        quality_result['issues'].append(f"High missing values: {missing_ratio:.2%}")
        quality_result['recommendations'].append("Consider data imputation or collection review")

    # Consistency check (time gaps)
    if 'timestamp' in df.columns:
        time_diffs = df['timestamp'].diff().dt.total_seconds().dropna()
        if len(time_diffs) > 0:
            expected_interval = time_diffs.median()
            large_gaps = (time_diffs > expected_interval * 3).sum()
            gap_ratio = large_gaps / len(time_diffs)
            quality_result['scores']['consistency'] = max(0, 1 - gap_ratio * 10)

            if gap_ratio > 0.01:
                quality_result['issues'].append(f"Time gaps detected: {large_gaps} gaps")
                quality_result['recommendations'].append("Review data collection intervals")

    # Accuracy check (outlier detection using IQR method)
    Q1 = df['value'].quantile(0.25)
    Q3 = df['value'].quantile(0.75)
    IQR = Q3 - Q1

    if IQR > 0:
        outlier_mask = (df['value'] < Q1 - 1.5 * IQR) | (df['value'] > Q3 + 1.5 * IQR)
        outlier_count = outlier_mask.sum()
        outlier_ratio = outlier_count / len(df)
        quality_result['scores']['accuracy'] = max(0, 1 - outlier_ratio * 5)

        if outlier_ratio > QUALITY_THRESHOLDS['outlier_ratio_threshold']:
            quality_result['issues'].append(f"High outlier ratio: {outlier_ratio:.2%}")
            quality_result['recommendations'].append("Consider outlier treatment or validation")
    else:
        quality_result['scores']['accuracy'] = 0.5  # Constant values
        quality_result['issues'].append("No variance in data (constant values)")

    # Calculate overall score
    quality_result['scores']['overall'] = np.mean([
        quality_result['scores']['completeness'],
        quality_result['scores']['consistency'],
        quality_result['scores']['accuracy']
    ])

    return quality_result

def plot_metric_overview(df: pd.DataFrame, metric_name: str, figsize: Tuple[int, int] = (15, 8)) -> None:
    """
    Create comprehensive visualization of a metric

    Args:
        df: DataFrame with time-series data
        metric_name: Name of the metric
        figsize: Figure size tuple
    """
    fig, axes = plt.subplots(2, 2, figsize=figsize)
    fig.suptitle(f'Metric Overview: {metric_name}', fontsize=16, fontweight='bold')

    # Time series plot
    axes[0, 0].plot(df['timestamp'], df['value'], linewidth=1, alpha=0.8)
    if 'is_anomaly' in df.columns:
        anomaly_points = df[df['is_anomaly']]
        if len(anomaly_points) > 0:
            axes[0, 0].scatter(anomaly_points['timestamp'], anomaly_points['value'],
                             color='red', s=30, alpha=0.7, label='Anomalies')
            axes[0, 0].legend()
    axes[0, 0].set_title('Time Series')
    axes[0, 0].set_xlabel('Time')
    axes[0, 0].set_ylabel('Value')
    axes[0, 0].grid(True, alpha=0.3)

    # Distribution plot
    axes[0, 1].hist(df['value'], bins=50, alpha=0.7, edgecolor='black')
    axes[0, 1].axvline(df['value'].mean(), color='red', linestyle='--', label=f'Mean: {df["value"].mean():.2f}')
    axes[0, 1].axvline(df['value'].median(), color='green', linestyle='--', label=f'Median: {df["value"].median():.2f}')
    axes[0, 1].set_title('Value Distribution')
    axes[0, 1].set_xlabel('Value')
    axes[0, 1].set_ylabel('Frequency')
    axes[0, 1].legend()
    axes[0, 1].grid(True, alpha=0.3)

    # Box plot
    axes[1, 0].boxplot(df['value'])
    axes[1, 0].set_title('Box Plot')
    axes[1, 0].set_ylabel('Value')
    axes[1, 0].grid(True, alpha=0.3)

    # Statistics summary
    stats_text = f"""
    Count: {len(df):,}
    Mean: {df['value'].mean():.2f}
    Std: {df['value'].std():.2f}
    Min: {df['value'].min():.2f}
    Max: {df['value'].max():.2f}

    Missing: {df['value'].isnull().sum()}
    Anomalies: {df.get('is_anomaly', pd.Series([False])).sum()}
    """

    axes[1, 1].text(0.1, 0.5, stats_text, transform=axes[1, 1].transAxes,
                    fontsize=12, verticalalignment='center',
                    bbox=dict(boxstyle='round', facecolor='lightgray', alpha=0.8))
    axes[1, 1].set_title('Statistics Summary')
    axes[1, 1].axis('off')

    plt.tight_layout()
    plt.show()

def save_processed_data(data, filename: str) -> str:
    """
    Save processed data to persistent storage

    Args:
        data: DataFrame, dict of DataFrames, or metadata dict for JSON
        filename: Filename (with or without extension)

    Returns:
        Path to saved file
    """
    # Ensure processed directory exists
    os.makedirs(f"{DATA_DIR}/processed", exist_ok=True)

    # Handle DataFrame directly (most common case)
    if isinstance(data, pd.DataFrame):
        # Determine output format from filename
        if filename.endswith('.parquet'):
            output_path = f"{DATA_DIR}/processed/{filename}"
        elif filename.endswith('.json'):
            output_path = f"{DATA_DIR}/processed/{filename}"
            # Convert DataFrame to dict for JSON
            with open(output_path, 'w') as f:
                json.dump(data.to_dict(orient='records'), f, indent=2, default=str)
            print(f"💾 Saved {len(data):,} records to {output_path}")
            print(f"📊 File size: {os.path.getsize(output_path) / 1024:.2f} KB")
            return output_path
        else:
            output_path = f"{DATA_DIR}/processed/{filename}.parquet"

        data.to_parquet(output_path, index=False)
        print(f"💾 Saved {len(data):,} records to {output_path}")
        print(f"📊 File size: {os.path.getsize(output_path) / (1024*1024):.2f} MB")
        return output_path

    # Handle dict input
    if isinstance(data, dict):
        # Check if dict contains DataFrames
        has_dataframes = any(isinstance(v, pd.DataFrame) for v in data.values())
        has_lists = any(isinstance(v, list) for v in data.values())

        if has_dataframes and not has_lists:
            # Save as Parquet
            if filename.endswith('.parquet'):
                output_path = f"{DATA_DIR}/processed/{filename}"
            else:
                output_path = f"{DATA_DIR}/processed/{filename}.parquet"
            combined_df = pd.concat(data.values(), ignore_index=True)
            combined_df.to_parquet(output_path, index=False)
            print(f"💾 Saved {len(combined_df):,} records to {output_path}")
            print(f"📊 File size: {os.path.getsize(output_path) / (1024*1024):.2f} MB")
        else:
            # Save as JSON (metadata)
            if filename.endswith('.json'):
                output_path = f"{DATA_DIR}/processed/{filename}"
            else:
                output_path = f"{DATA_DIR}/processed/{filename}.json"
            # Convert any non-serializable values
            serializable_data = {}
            for k, v in data.items():
                if isinstance(v, pd.Series):
                    serializable_data[k] = v.to_dict()
                elif hasattr(v, 'tolist'):  # numpy arrays
                    serializable_data[k] = v.tolist()
                else:
                    serializable_data[k] = v
            with open(output_path, 'w') as f:
                json.dump(serializable_data, f, indent=2, default=str)
            print(f"💾 Saved metadata to {output_path}")
            print(f"📊 File size: {os.path.getsize(output_path) / 1024:.2f} KB")

        return output_path

    # Fallback: try to serialize as JSON
    if filename.endswith('.json'):
        output_path = f"{DATA_DIR}/processed/{filename}"
    else:
        output_path = f"{DATA_DIR}/processed/{filename}.json"
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2, default=str)
    print(f"💾 Saved data to {output_path}")
    return output_path

def load_processed_data(filename: str):
    """
    Load processed data from persistent storage

    Args:
        filename: Filename (with or without extension)

    Returns:
        Loaded DataFrame or dict (for JSON files)
    """
    # Determine file path based on extension
    if filename.endswith('.parquet'):
        file_path = f"{DATA_DIR}/processed/{filename}"
    elif filename.endswith('.json'):
        file_path = f"{DATA_DIR}/processed/{filename}"
        if os.path.exists(file_path):
            with open(file_path, 'r') as f:
                data = json.load(f)
            print(f"📂 Loaded data from {file_path}")
            return data
        raise FileNotFoundError(f"File not found: {file_path}")
    else:
        # Try parquet first, then json
        file_path = f"{DATA_DIR}/processed/{filename}.parquet"
        if not os.path.exists(file_path):
            json_path = f"{DATA_DIR}/processed/{filename}.json"
            if os.path.exists(json_path):
                with open(json_path, 'r') as f:
                    data = json.load(f)
                print(f"📂 Loaded data from {json_path}")
                return data

    if not os.path.exists(file_path):
        raise FileNotFoundError(f"File not found: {file_path}")

    df = pd.read_parquet(file_path)
    print(f"📂 Loaded {len(df):,} records from {file_path}")

    return df

def get_prometheus_client(use_thanos=False):
    """
    Get a configured Prometheus client for in-cluster access

    Args:
        use_thanos: Whether to use Thanos Querier instead of Prometheus directly

    Returns:
        Configured requests session with authentication
    """
    # Read service account token
    token_path = '/var/run/secrets/kubernetes.io/serviceaccount/token'
    ca_path = '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'

    session = requests.Session()

    # Set up authentication if token is available
    if os.path.exists(token_path):
        with open(token_path, 'r') as f:
            token = f.read().strip()
        session.headers.update({
            'Authorization': f'Bearer {token}'
        })

    # Configure SSL verification
    if os.path.exists(ca_path):
        session.verify = ca_path
    else:
        session.verify = False
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    # Set base URL
    base_url = PROMETHEUS_CONFIG['thanos_url'] if use_thanos else PROMETHEUS_CONFIG['base_url']

    return session, base_url

def query_prometheus(query_string, time=None, use_thanos=False):
    """
    Execute a PromQL query against the in-cluster Prometheus

    Args:
        query_string: PromQL query to execute
        time: Optional timestamp for point-in-time query
        use_thanos: Whether to use Thanos Querier

    Returns:
        Query result as JSON or None if failed
    """
    try:
        session, base_url = get_prometheus_client(use_thanos)

        url = f"{base_url}/api/v1/query"
        params = {'query': query_string}

        if time:
            params['time'] = time

        response = session.get(
            url,
            params=params,
            timeout=PROMETHEUS_CONFIG['timeout']
        )
        response.raise_for_status()

        result = response.json()
        if result.get('status') == 'success':
            return result
        else:
            print(f"❌ Prometheus query failed: {result.get('error', 'Unknown error')}")
            return None

    except Exception as e:
        print(f"❌ Prometheus query error: {e}")
        return None

def test_prometheus_connection(use_thanos=False):
    """
    Test connection to Prometheus/Thanos

    Args:
        use_thanos: Whether to test Thanos Querier connection

    Returns:
        True if connection successful, False otherwise
    """
    try:
        result = query_prometheus('up', use_thanos=use_thanos)
        if result and result.get('status') == 'success':
            service_name = "Thanos Querier" if use_thanos else "Prometheus"
            print(f"✅ {service_name} connection successful")
            return True
        else:
            service_name = "Thanos Querier" if use_thanos else "Prometheus"
            print(f"❌ {service_name} connection failed")
            return False
    except Exception as e:
        service_name = "Thanos Querier" if use_thanos else "Prometheus"
        print(f"❌ {service_name} connection test failed: {e}")
        return False

# =============================================================================
# S3 Model Storage Functions
# =============================================================================

def get_s3_client():
    """
    Get a configured S3 client for model storage using environment variables
    or secrets mounted in the pod.

    Returns:
        Tuple of (s3_client, bucket_name, endpoint_url) or (None, None, None) if unavailable
    """
    try:
        import boto3
        from botocore.config import Config

        # Try to get credentials from environment or secrets
        access_key = os.environ.get('AWS_ACCESS_KEY_ID')
        secret_key = os.environ.get('AWS_SECRET_ACCESS_KEY')
        endpoint = os.environ.get('AWS_S3_ENDPOINT')
        bucket = os.environ.get('AWS_S3_BUCKET', 'model-storage')
        ssl_verify = os.environ.get('AWS_SSL_VERIFY', 'true').lower() != 'false'

        # If not in environment, try to read from secret mount
        secret_path = '/var/run/secrets/s3'
        if not access_key and os.path.exists(f'{secret_path}/AWS_ACCESS_KEY_ID'):
            with open(f'{secret_path}/AWS_ACCESS_KEY_ID', 'r') as f:
                access_key = f.read().strip()
            with open(f'{secret_path}/AWS_SECRET_ACCESS_KEY', 'r') as f:
                secret_key = f.read().strip()
            with open(f'{secret_path}/AWS_S3_ENDPOINT', 'r') as f:
                endpoint = f.read().strip()

        if not all([access_key, secret_key, endpoint]):
            print("⚠️ S3 credentials not available - model upload disabled")
            return None, None, None

        # Create S3 client
        s3_client = boto3.client(
            's3',
            endpoint_url=endpoint,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            verify=ssl_verify,
            config=Config(signature_version='s3v4')
        )

        return s3_client, bucket, endpoint

    except ImportError:
        print("⚠️ boto3 not available - S3 upload disabled")
        return None, None, None
    except Exception as e:
        print(f"⚠️ S3 client initialization failed: {e}")
        return None, None, None


def upload_model_to_s3(local_path: str, s3_key: str = None, bucket: str = None) -> bool:
    """
    Upload a model file to S3 storage.

    Args:
        local_path: Local path to the model file
        s3_key: S3 object key (default: models/{filename})
        bucket: S3 bucket name (default: from environment)

    Returns:
        True if upload successful, False otherwise
    """
    s3_client, default_bucket, endpoint = get_s3_client()

    if s3_client is None:
        print(f"⚠️ S3 not available - model saved locally only: {local_path}")
        return False

    try:
        bucket = bucket or default_bucket
        filename = os.path.basename(local_path)
        s3_key = s3_key or f"models/{filename}"

        # Upload file
        s3_client.upload_file(local_path, bucket, s3_key)

        print(f"✅ Model uploaded to S3: s3://{bucket}/{s3_key}")
        return True

    except Exception as e:
        print(f"❌ S3 upload failed: {e}")
        return False


def download_model_from_s3(s3_key: str, local_path: str, bucket: str = None) -> bool:
    """
    Download a model file from S3 storage.

    Args:
        s3_key: S3 object key
        local_path: Local path to save the model
        bucket: S3 bucket name (default: from environment)

    Returns:
        True if download successful, False otherwise
    """
    s3_client, default_bucket, endpoint = get_s3_client()

    if s3_client is None:
        print(f"⚠️ S3 not available - cannot download model")
        return False

    try:
        bucket = bucket or default_bucket

        # Ensure local directory exists
        os.makedirs(os.path.dirname(local_path), exist_ok=True)

        # Download file
        s3_client.download_file(bucket, s3_key, local_path)

        print(f"✅ Model downloaded from S3: s3://{bucket}/{s3_key} -> {local_path}")
        return True

    except Exception as e:
        print(f"❌ S3 download failed: {e}")
        return False


def list_models_in_s3(prefix: str = "models/", bucket: str = None) -> list:
    """
    List model files in S3 storage.

    Args:
        prefix: S3 key prefix to filter (default: "models/")
        bucket: S3 bucket name (default: from environment)

    Returns:
        List of S3 object keys
    """
    s3_client, default_bucket, endpoint = get_s3_client()

    if s3_client is None:
        return []

    try:
        bucket = bucket or default_bucket

        response = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix)

        models = []
        for obj in response.get('Contents', []):
            models.append({
                'key': obj['Key'],
                'size_mb': obj['Size'] / (1024 * 1024),
                'last_modified': obj['LastModified'].isoformat()
            })

        return models

    except Exception as e:
        print(f"❌ S3 list failed: {e}")
        return []


def save_model_with_s3_backup(model, local_path: str, s3_key: str = None):
    """
    Save a model locally and upload to S3 as backup.
    Supports PyTorch, scikit-learn, and pickle-serializable models.

    Args:
        model: Model object to save
        local_path: Local path to save the model
        s3_key: S3 object key (default: models/{filename})

    Returns:
        Tuple of (local_path, s3_uploaded)
    """
    import pickle

    # Ensure directory exists
    os.makedirs(os.path.dirname(local_path), exist_ok=True)

    # Determine save method based on file extension and model type
    if local_path.endswith('.pt') or local_path.endswith('.pth'):
        # PyTorch model
        try:
            import torch
            if hasattr(model, 'state_dict'):
                torch.save(model.state_dict(), local_path)
            else:
                torch.save(model, local_path)
            print(f"💾 Saved PyTorch model to {local_path}")
        except Exception as e:
            print(f"❌ PyTorch save failed: {e}")
            return local_path, False
    else:
        # Pickle-based save (scikit-learn, etc.)
        try:
            with open(local_path, 'wb') as f:
                pickle.dump(model, f)
            print(f"💾 Saved model to {local_path}")
        except Exception as e:
            print(f"❌ Pickle save failed: {e}")
            return local_path, False

    # Upload to S3
    s3_uploaded = upload_model_to_s3(local_path, s3_key)

    return local_path, s3_uploaded


def test_s3_connection() -> bool:
    """
    Test S3 connection and bucket access.

    Returns:
        True if connection successful, False otherwise
    """
    s3_client, bucket, endpoint = get_s3_client()

    if s3_client is None:
        return False

    try:
        # Try to list objects (HEAD bucket)
        s3_client.head_bucket(Bucket=bucket)
        print(f"✅ S3 connection successful")
        print(f"   Endpoint: {endpoint}")
        print(f"   Bucket: {bucket}")
        return True
    except Exception as e:
        print(f"❌ S3 connection failed: {e}")
        return False


# =============================================================================
# Module Initialization
# =============================================================================

# Configuration for plotting
plt.style.use('seaborn-v0_8')
sns.set_palette("husl")

print("✅ Common functions module loaded successfully")
print(f"📁 Data directory: {DATA_DIR}")
print(f"🗃️ Models directory: {MODELS_DIR}")
print(f"⚙️ Configuration directory: {CONFIG_DIR}")
print(f"📊 Quality thresholds: {len(QUALITY_THRESHOLDS)} defined")
print("🔧 Available functions: setup_environment, validate_data_quality, plot_metric_overview")
print("💾 Storage functions: save_processed_data, load_processed_data")
print("📊 Prometheus functions: query_prometheus, test_prometheus_connection")
print("☁️ S3 functions: upload_model_to_s3, download_model_from_s3, save_model_with_s3_backup")
print("🎯 Use setup_environment() to initialize your notebook environment")
print("🔍 Use test_prometheus_connection() to verify Prometheus access")
print("☁️ Use test_s3_connection() to verify S3 model storage access")
