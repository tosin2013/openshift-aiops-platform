#!/usr/bin/env python3
"""
Generic Model Server for Self-Healing Platform Models
Serves both anomaly detection and predictive analytics models
"""

import os
import json
import logging
from flask import Flask, request, jsonify
from prometheus_client import Counter, Histogram, generate_latest
import pandas as pd

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics
prediction_counter = Counter('model_predictions_total', 'Total predictions made', ['model_name', 'status'])
prediction_duration = Histogram('model_prediction_duration_seconds', 'Time spent on predictions', ['model_name'])

app = Flask(__name__)

# Global model instance
model = None
model_name = os.getenv('MODEL_NAME', 'unknown')

def load_model():
    """Load the appropriate model based on MODEL_NAME environment variable"""
    global model

    try:
        if model_name == 'anomaly-detector':
            from anomaly_detector import AnomalyDetector
            model = AnomalyDetector()
            # In production, load pre-trained model
            # model.load_model('/opt/models/anomaly_model.pkl', '/opt/models/scaler.pkl')
            logger.info("Anomaly detector model loaded")

        elif model_name == 'predictive-analytics':
            from predictive_analytics import PredictiveAnalytics
            model = PredictiveAnalytics()
            # In production, load pre-trained models
            # model.load_models('/opt/models/predictive_models/')
            logger.info("Predictive analytics model loaded")

        else:
            raise ValueError(f"Unknown model name: {model_name}")

    except Exception as e:
        logger.error(f"Failed to load model {model_name}: {e}")
        raise

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'model_name': model_name,
        'model_loaded': model is not None,
        'version': os.getenv('MODEL_VERSION', '1.0.0')
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

@app.route('/v1/models/<model_id>:predict', methods=['POST'])
def predict(model_id):
    """KServe-compatible prediction endpoint"""
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 500

    try:
        with prediction_duration.labels(model_name=model_name).time():
            data = request.json

            if 'instances' not in data:
                return jsonify({'error': 'Missing instances in request'}), 400

            # Convert instances to DataFrame
            instances = data['instances']
            if isinstance(instances[0], list):
                # Numeric data
                df = pd.DataFrame(instances)
            else:
                # Dictionary data
                df = pd.DataFrame(instances)

            # Make predictions based on model type
            if model_name == 'anomaly-detector':
                results = model.predict(df)
                predictions = results['is_anomaly']

            elif model_name == 'predictive-analytics':
                results = model.predict(df)
                predictions = results['predictions']

            else:
                return jsonify({'error': f'Unknown model: {model_name}'}), 400

            prediction_counter.labels(model_name=model_name, status='success').inc()

            return jsonify({
                'predictions': predictions,
                'model_name': model_name,
                'model_version': os.getenv('MODEL_VERSION', '1.0.0')
            })

    except Exception as e:
        prediction_counter.labels(model_name=model_name, status='error').inc()
        logger.error(f"Prediction error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/v1/models/<model_id>', methods=['GET'])
def model_info(model_id):
    """Get model information"""
    return jsonify({
        'name': model_name,
        'version': os.getenv('MODEL_VERSION', '1.0.0'),
        'ready': model is not None,
        'inputs': [
            {
                'name': 'instances',
                'datatype': 'ARRAY',
                'shape': [-1, -1]
            }
        ],
        'outputs': [
            {
                'name': 'predictions',
                'datatype': 'ARRAY',
                'shape': [-1]
            }
        ]
    })

@app.route('/v1/models', methods=['GET'])
def list_models():
    """List available models"""
    return jsonify({
        'models': [
            {
                'name': model_name,
                'version': os.getenv('MODEL_VERSION', '1.0.0'),
                'ready': model is not None
            }
        ]
    })

if __name__ == '__main__':
    # Load model on startup
    load_model()

    # Start Flask app
    port = int(os.getenv('MODEL_SERVER_PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
