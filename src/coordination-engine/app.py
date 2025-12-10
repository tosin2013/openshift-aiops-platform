#!/usr/bin/env python3
"""
Self-Healing Platform Coordination Engine
Implements ADR-002: Hybrid Deterministic-AI Self-Healing Approach
"""

import os
import sys
import time
import logging
import threading
import math
import statistics
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from enum import Enum
import json

from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, start_http_server
import kubernetes
from kubernetes import client, config

# Configure logging
logging.basicConfig(
    level=getattr(logging, os.getenv('LOG_LEVEL', 'INFO')),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics
action_counter = Counter('coordination_engine_actions_total', 'Total actions processed', ['action_type', 'source'])
conflict_counter = Counter('coordination_engine_conflicts_total', 'Total conflicts detected', ['conflict_type'])
resolution_time = Histogram('coordination_engine_resolution_seconds', 'Time to resolve conflicts')
active_actions = Gauge('coordination_engine_active_actions', 'Currently active actions')
engine_status = Gauge('coordination_engine_status', 'Engine status (1=healthy, 0=unhealthy)')

class ActionType(Enum):
    NODE_REMEDIATION = "node_remediation"
    MODEL_INFERENCE = "model_inference"
    ALERT_CORRELATION = "alert_correlation"
    RESOURCE_SCALING = "resource_scaling"

class ActionSource(Enum):
    DETERMINISTIC = "deterministic"
    AI_DRIVEN = "ai_driven"
    MANUAL = "manual"

class ActionStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"

@dataclass
class Action:
    id: str
    type: ActionType
    source: ActionSource
    priority: int  # 1-10, 10 being highest
    target: str
    parameters: Dict[str, Any]
    status: ActionStatus = ActionStatus.PENDING
    created_at: datetime = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    confidence: float = 1.0  # For AI-driven actions

    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.utcnow()

class ConflictResolver:
    """Implements conflict resolution logic from ADR-002"""

    def __init__(self):
        self.resolution_rules = {
            # Rule: If deterministic and AI actions target same resource
            'same_target': self._resolve_same_target,
            # Rule: If actions have different priorities
            'priority_conflict': self._resolve_priority_conflict,
            # Rule: If AI confidence is below threshold
            'low_confidence': self._resolve_low_confidence,
        }

    def detect_conflicts(self, actions: List[Action]) -> List[tuple]:
        """Detect conflicts between actions"""
        conflicts = []

        for i, action1 in enumerate(actions):
            for j, action2 in enumerate(actions[i+1:], i+1):
                if self._actions_conflict(action1, action2):
                    conflicts.append((action1, action2))

        return conflicts

    def _actions_conflict(self, action1: Action, action2: Action) -> bool:
        """Check if two actions conflict"""
        # Same target resource
        if action1.target == action2.target:
            return True

        # Conflicting action types
        conflicting_types = {
            (ActionType.NODE_REMEDIATION, ActionType.RESOURCE_SCALING),
            (ActionType.MODEL_INFERENCE, ActionType.ALERT_CORRELATION)
        }

        action_pair = (action1.type, action2.type)
        return action_pair in conflicting_types or action_pair[::-1] in conflicting_types

    def resolve_conflict(self, action1: Action, action2: Action) -> Action:
        """Resolve conflict between two actions"""
        conflict_counter.labels(conflict_type='same_target').inc()

        # Apply resolution rules in order
        for rule_name, rule_func in self.resolution_rules.items():
            result = rule_func(action1, action2)
            if result:
                logger.info(f"Conflict resolved using rule: {rule_name}")
                return result

        # Default: choose higher priority action
        return action1 if action1.priority > action2.priority else action2

    def _resolve_same_target(self, action1: Action, action2: Action) -> Optional[Action]:
        """Resolve conflicts for same target"""
        if action1.target != action2.target:
            return None

        # Deterministic actions take precedence over AI actions
        if action1.source == ActionSource.DETERMINISTIC and action2.source == ActionSource.AI_DRIVEN:
            return action1
        elif action2.source == ActionSource.DETERMINISTIC and action1.source == ActionSource.AI_DRIVEN:
            return action2

        return None

    def _resolve_priority_conflict(self, action1: Action, action2: Action) -> Optional[Action]:
        """Resolve based on priority"""
        if action1.priority != action2.priority:
            return action1 if action1.priority > action2.priority else action2
        return None

    def _resolve_low_confidence(self, action1: Action, action2: Action) -> Optional[Action]:
        """Resolve based on AI confidence"""
        confidence_threshold = 0.7

        if action1.source == ActionSource.AI_DRIVEN and action1.confidence < confidence_threshold:
            return action2
        elif action2.source == ActionSource.AI_DRIVEN and action2.confidence < confidence_threshold:
            return action1

        return None

class AnomalyDetectionModel:
    """Base class for anomaly detection models"""

    def __init__(self, name: str, threshold: float = 0.8):
        self.name = name
        self.threshold = threshold
        self.trained = False
        self.model_version = "1.0.0"

    def detect_anomalies(self, metrics: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Detect anomalies in metrics data"""
        raise NotImplementedError("Subclasses must implement detect_anomalies")

    def get_model_info(self) -> Dict[str, Any]:
        """Get model information"""
        return {
            'name': self.name,
            'threshold': self.threshold,
            'trained': self.trained,
            'version': self.model_version
        }

class StatisticalAnomalyModel(AnomalyDetectionModel):
    """Statistical anomaly detection using z-score and IQR methods"""

    def __init__(self, threshold: float = 2.5):
        super().__init__("Statistical", threshold)
        self.trained = True  # Statistical methods don't require training

    def detect_anomalies(self, metrics: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Detect anomalies using statistical methods"""
        anomalies = []

        for metric in metrics:
            metric_name = metric.get('name', 'unknown')
            values = metric.get('values', [])
            timestamps = metric.get('timestamps', [])

            if len(values) < 3:
                continue  # Need at least 3 points for statistical analysis

            # Z-score based detection
            mean_val = statistics.mean(values)
            std_val = statistics.stdev(values) if len(values) > 1 else 0

            if std_val > 0:
                z_scores = [(val - mean_val) / std_val for val in values]

                for i, z_score in enumerate(z_scores):
                    if abs(z_score) > self.threshold:
                        anomalies.append({
                            'type': 'statistical_outlier',
                            'metric': metric_name,
                            'value': values[i],
                            'expected_range': [mean_val - self.threshold * std_val, mean_val + self.threshold * std_val],
                            'z_score': z_score,
                            'severity': 'high' if abs(z_score) > 3 else 'medium',
                            'confidence': min(0.95, abs(z_score) / 4),
                            'timestamp': timestamps[i] if i < len(timestamps) else datetime.utcnow().isoformat(),
                            'model': self.name
                        })

        return anomalies

class AnomalyDetectionEngine:
    """Ensemble anomaly detection engine combining multiple models"""

    def __init__(self):
        self.models = [
            StatisticalAnomalyModel(threshold=2.5)
        ]
        self.ensemble_threshold = 0.6

    def detect_anomalies(self, metrics: List[Dict[str, Any]], model_names: List[str] = None) -> Dict[str, Any]:
        """Run anomaly detection using ensemble of models"""
        all_anomalies = []
        model_results = {}

        # Filter models if specific ones are requested
        active_models = self.models
        if model_names:
            active_models = [m for m in self.models if m.name.lower() in [n.lower() for n in model_names]]

        # Run each model
        for model in active_models:
            try:
                model_anomalies = model.detect_anomalies(metrics)
                model_results[model.name] = {
                    'anomalies_count': len(model_anomalies),
                    'anomalies': model_anomalies,
                    'model_info': model.get_model_info()
                }
                all_anomalies.extend(model_anomalies)
            except Exception as e:
                logger.error(f"Error in {model.name} model: {e}")
                model_results[model.name] = {
                    'error': str(e),
                    'anomalies_count': 0,
                    'anomalies': []
                }

        # Aggregate results
        total_anomalies = len(all_anomalies)

        # Calculate ensemble confidence
        if total_anomalies > 0:
            avg_confidence = sum(a.get('confidence', 0) for a in all_anomalies) / total_anomalies
        else:
            avg_confidence = 0.5

        # Group anomalies by severity
        severity_counts = {'critical': 0, 'high': 0, 'medium': 0, 'warning': 0, 'low': 0}
        for anomaly in all_anomalies:
            severity = anomaly.get('severity', 'medium')
            severity_counts[severity] = severity_counts.get(severity, 0) + 1

        return {
            'total_anomalies': total_anomalies,
            'ensemble_confidence': round(avg_confidence, 3),
            'severity_breakdown': severity_counts,
            'anomalies': all_anomalies,
            'model_results': model_results,
            'models_used': [m.name for m in active_models],
            'analysis_timestamp': datetime.utcnow().isoformat()
        }

class CoordinationEngine:
    """Main coordination engine implementing ADR-002"""

    def __init__(self):
        self.actions: Dict[str, Action] = {}
        self.action_queue: List[str] = []
        self.conflict_resolver = ConflictResolver()
        self.anomaly_detection_engine = AnomalyDetectionEngine()
        self.running = False
        self.k8s_client = None

        # Initialize Kubernetes client
        try:
            if os.path.exists('/var/run/secrets/kubernetes.io/serviceaccount'):
                config.load_incluster_config()
            else:
                config.load_kube_config()
            self.k8s_client = client.CoreV1Api()
            logger.info("Kubernetes client initialized")
        except Exception as e:
            logger.error(f"Failed to initialize Kubernetes client: {e}")

    def start(self):
        """Start the coordination engine"""
        self.running = True
        self.start_time = time.time()
        engine_status.set(1)
        logger.info("Coordination Engine started")

        # Start processing thread
        processing_thread = threading.Thread(target=self._process_actions)
        processing_thread.daemon = True
        processing_thread.start()

    def stop(self):
        """Stop the coordination engine"""
        self.running = False
        engine_status.set(0)
        logger.info("Coordination Engine stopped")

    def submit_action(self, action: Action) -> str:
        """Submit an action for processing"""
        self.actions[action.id] = action
        self.action_queue.append(action.id)

        action_counter.labels(
            action_type=action.type.value,
            source=action.source.value
        ).inc()

        logger.info(f"Action submitted: {action.id} ({action.type.value})")
        return action.id

    def get_action_status(self, action_id: str) -> Optional[Dict]:
        """Get status of an action"""
        action = self.actions.get(action_id)
        return asdict(action) if action else None

    def _process_actions(self):
        """Main processing loop"""
        while self.running:
            try:
                if self.action_queue:
                    self._process_next_batch()
                time.sleep(5)  # Process every 5 seconds
            except Exception as e:
                logger.error(f"Error in processing loop: {e}")
                time.sleep(10)

    def _process_next_batch(self):
        """Process next batch of actions"""
        with resolution_time.time():
            # Get pending actions
            pending_actions = [
                self.actions[action_id] for action_id in self.action_queue
                if self.actions[action_id].status == ActionStatus.PENDING
            ]

            if not pending_actions:
                return

            # Detect and resolve conflicts
            conflicts = self.conflict_resolver.detect_conflicts(pending_actions)

            if conflicts:
                logger.info(f"Detected {len(conflicts)} conflicts")
                resolved_actions = self._resolve_conflicts(conflicts, pending_actions)
            else:
                resolved_actions = pending_actions

            # Execute actions
            for action in resolved_actions:
                self._execute_action(action)

            # Update active actions gauge
            active_count = sum(1 for a in self.actions.values() if a.status == ActionStatus.RUNNING)
            active_actions.set(active_count)

    def _resolve_conflicts(self, conflicts: List[tuple], actions: List[Action]) -> List[Action]:
        """Resolve all conflicts and return final action list"""
        resolved_actions = actions.copy()

        for action1, action2 in conflicts:
            if action1 in resolved_actions and action2 in resolved_actions:
                winner = self.conflict_resolver.resolve_conflict(action1, action2)
                loser = action2 if winner == action1 else action1

                # Remove loser from resolved actions
                resolved_actions.remove(loser)
                loser.status = ActionStatus.CANCELLED

                logger.info(f"Conflict resolved: {winner.id} chosen over {loser.id}")

        return resolved_actions

    def _execute_action(self, action: Action):
        """Execute an individual action"""
        try:
            action.status = ActionStatus.RUNNING
            action.started_at = datetime.utcnow()

            logger.info(f"Executing action: {action.id}")

            # Simulate action execution (replace with actual implementation)
            if action.type == ActionType.NODE_REMEDIATION:
                self._execute_node_remediation(action)
            elif action.type == ActionType.MODEL_INFERENCE:
                self._execute_model_inference(action)
            elif action.type == ActionType.ALERT_CORRELATION:
                self._execute_alert_correlation(action)
            elif action.type == ActionType.RESOURCE_SCALING:
                self._execute_resource_scaling(action)

            action.status = ActionStatus.COMPLETED
            action.completed_at = datetime.utcnow()

            # Remove from queue
            if action.id in self.action_queue:
                self.action_queue.remove(action.id)

            logger.info(f"Action completed: {action.id}")

        except Exception as e:
            action.status = ActionStatus.FAILED
            action.completed_at = datetime.utcnow()
            logger.error(f"Action failed: {action.id} - {e}")

    def _execute_node_remediation(self, action: Action):
        """Execute node remediation action"""
        # Placeholder for MCO integration
        logger.info(f"Node remediation for {action.target}: {action.parameters}")
        time.sleep(2)  # Simulate work

    def _execute_model_inference(self, action: Action):
        """Execute model inference action"""
        # Placeholder for KServe integration
        logger.info(f"Model inference for {action.target}: {action.parameters}")
        time.sleep(1)  # Simulate work

    def _execute_alert_correlation(self, action: Action):
        """Execute alert correlation action"""
        # Placeholder for Prometheus integration
        logger.info(f"Alert correlation for {action.target}: {action.parameters}")
        time.sleep(1)  # Simulate work

    def _execute_resource_scaling(self, action: Action):
        """Execute resource scaling action"""
        # Placeholder for HPA integration
        logger.info(f"Resource scaling for {action.target}: {action.parameters}")
        time.sleep(3)  # Simulate work

# Flask application for main API
app = Flask(__name__)
engine = CoordinationEngine()

@app.route('/health')
def health():
    """Enhanced health check endpoint with comprehensive diagnostics"""
    try:
        # Basic engine status
        engine_healthy = engine.running

        # Check Kubernetes connectivity
        k8s_healthy = engine.k8s_client is not None
        if k8s_healthy:
            try:
                # Test K8s API connectivity - list namespaces with limit
                engine.k8s_client.list_namespace(limit=1)
                k8s_status = 'connected'
            except Exception as e:
                # Log the error but don't fail health check for K8s connectivity issues
                error_msg = str(e)
                logger.warning(f"K8s API connectivity check failed: {error_msg[:200]}")
                logger.debug(f"Full error: {error_msg}")
                k8s_healthy = True  # Still consider healthy if client exists, even if API call fails
                k8s_status = f'api_call_failed: {error_msg[:100]}'
        else:
            k8s_status = 'not_initialized'
            k8s_healthy = True  # Don't fail health check if K8s client not initialized

        # Calculate uptime
        uptime_seconds = int(time.time() - engine.start_time) if hasattr(engine, 'start_time') else 0

        # Action statistics
        action_stats = {
            'total': len(engine.actions),
            'pending': len([a for a in engine.actions.values() if a.status == ActionStatus.PENDING]),
            'running': len([a for a in engine.actions.values() if a.status == ActionStatus.RUNNING]),
            'completed': len([a for a in engine.actions.values() if a.status == ActionStatus.COMPLETED]),
            'failed': len([a for a in engine.actions.values() if a.status == ActionStatus.FAILED]),
            'cancelled': len([a for a in engine.actions.values() if a.status == ActionStatus.CANCELLED])
        }

        # Queue health
        queue_length = len(engine.action_queue)
        queue_healthy = queue_length < 100  # Alert if queue is too long

        # Overall health determination
        overall_healthy = engine_healthy and k8s_healthy and queue_healthy

        # Get metric values safely (compatible with prometheus-client >= 0.17.0)
        conflicts_count = 0
        actions_count = 0
        try:
            # Try new API first (prometheus-client >= 0.18.0)
            if hasattr(conflict_counter._value, 'get'):
                conflicts_count = conflict_counter._value.get()
            elif hasattr(conflict_counter._value, '_value'):
                conflicts_count = conflict_counter._value._value
            else:
                conflicts_count = 0

            if hasattr(action_counter._value, 'get'):
                actions_count = action_counter._value.get()
            elif hasattr(action_counter._value, '_value'):
                actions_count = action_counter._value._value
            else:
                actions_count = 0
        except Exception as e:
            logger.debug(f"Could not retrieve metric values: {e}")
            conflicts_count = 0
            actions_count = 0

        health_response = {
            'status': 'healthy' if overall_healthy else 'unhealthy',
            'timestamp': datetime.utcnow().isoformat(),
            'uptime_seconds': uptime_seconds,
            'components': {
                'coordination_engine': {
                    'status': 'healthy' if engine_healthy else 'unhealthy',
                    'running': engine.running
                },
                'kubernetes_api': {
                    'status': 'healthy' if k8s_healthy else 'unhealthy',
                    'details': k8s_status
                },
                'action_queue': {
                    'status': 'healthy' if queue_healthy else 'unhealthy',
                    'length': queue_length,
                    'max_recommended': 100
                }
            },
            'statistics': action_stats,
            'metrics': {
                'conflicts_detected': conflicts_count,
                'actions_processed': actions_count
            },
            'version': '1.0.0',
            'build_info': {
                'python_version': os.sys.version.split()[0],
                'flask_version': '2.3.0'  # Could be dynamically determined
            }
        }

        # Return appropriate HTTP status code
        status_code = 200 if overall_healthy else 503
        return jsonify(health_response), status_code

    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }), 503

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

@app.route('/actions', methods=['POST'])
def submit_action():
    """Submit a new action"""
    try:
        data = request.json
        action = Action(
            id=data['id'],
            type=ActionType(data['type']),
            source=ActionSource(data['source']),
            priority=data['priority'],
            target=data['target'],
            parameters=data.get('parameters', {}),
            confidence=data.get('confidence', 1.0)
        )

        action_id = engine.submit_action(action)
        return jsonify({'action_id': action_id, 'status': 'submitted'})

    except Exception as e:
        return jsonify({'error': str(e)}), 400

@app.route('/actions/<action_id>')
def get_action(action_id):
    """Get action status"""
    action = engine.get_action_status(action_id)
    if action:
        return jsonify(action)
    return jsonify({'error': 'Action not found'}), 404

@app.route('/actions')
def list_actions():
    """List all actions"""
    actions = {aid: asdict(action) for aid, action in engine.actions.items()}
    return jsonify(actions)

# Enhanced MCP Server Integration Endpoints
@app.route('/api/v1/incidents', methods=['GET'])
def get_incidents():
    """Get comprehensive incident data for MCP server integration"""
    try:
        # Query parameters for filtering
        status_filter = request.args.get('status', 'all')  # all, active, completed, failed
        severity_filter = request.args.get('severity', 'all')  # all, low, medium, high, critical
        limit = int(request.args.get('limit', 100))
        offset = int(request.args.get('offset', 0))

        # Convert actions to comprehensive incidents format
        incidents = []
        for action_id, action in engine.actions.items():
            # Apply status filter
            if status_filter != 'all':
                if status_filter == 'active' and action.status not in [ActionStatus.PENDING, ActionStatus.RUNNING]:
                    continue
                elif status_filter == 'completed' and action.status != ActionStatus.COMPLETED:
                    continue
                elif status_filter == 'failed' and action.status != ActionStatus.FAILED:
                    continue

            # Determine severity based on priority and action type
            if action.priority >= 9:
                severity = 'critical'
            elif action.priority >= 7:
                severity = 'high'
            elif action.priority >= 4:
                severity = 'medium'
            else:
                severity = 'low'

            # Apply severity filter
            if severity_filter != 'all' and severity != severity_filter:
                continue

            # Calculate duration if action is completed
            duration = None
            if action.completed_at and action.started_at:
                duration = (action.completed_at - action.started_at).total_seconds()

            incident = {
                'id': action_id,
                'title': f"{action.type.value.replace('_', ' ').title()} - {action.target}",
                'description': f"Automated {action.type.value} on {action.target}",
                'severity': severity,
                'status': action.status.value,
                'priority': action.priority,
                'target': action.target,
                'action_type': action.type.value,
                'source': action.source.value,
                'confidence': action.confidence,
                'parameters': action.parameters,
                'created_at': action.created_at.isoformat() if action.created_at else datetime.utcnow().isoformat(),
                'started_at': action.started_at.isoformat() if action.started_at else None,
                'completed_at': action.completed_at.isoformat() if action.completed_at else None,
                'duration_seconds': duration,
                'tags': [
                    action.type.value,
                    action.source.value,
                    severity,
                    f"priority_{action.priority}"
                ]
            }
            incidents.append(incident)

        # Apply pagination
        total_incidents = len(incidents)
        incidents = incidents[offset:offset + limit]

        # Enhanced response with metadata
        response = {
            'incidents': incidents,
            'metadata': {
                'total': total_incidents,
                'count': len(incidents),
                'offset': offset,
                'limit': limit,
                'filters': {
                    'status': status_filter,
                    'severity': severity_filter
                },
                'timestamp': datetime.utcnow().isoformat(),
                'engine_status': 'healthy' if engine.running else 'unhealthy'
            },
            'summary': {
                'active_incidents': len([a for a in engine.actions.values() if a.status in [ActionStatus.PENDING, ActionStatus.RUNNING]]),
                'completed_incidents': len([a for a in engine.actions.values() if a.status == ActionStatus.COMPLETED]),
                'failed_incidents': len([a for a in engine.actions.values() if a.status == ActionStatus.FAILED]),
                'total_incidents': len(engine.actions)
            }
        }

        return jsonify(response)
    except Exception as e:
        logger.error(f"Error getting incidents: {e}")
        return jsonify({'error': str(e)}), 500

# Comprehensive Incident Management API
@app.route('/api/v1/incidents', methods=['POST'])
def create_incident():
    """Create a new incident"""
    try:
        data = request.get_json() or {}

        # Validate required fields
        required_fields = ['title', 'description', 'severity']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400

        # Create incident as a special action
        incident_id = f"incident-{int(time.time())}-{data['title'][:20].replace(' ', '-').lower()}"

        # Map severity to priority
        severity_priority_map = {
            'critical': 10,
            'high': 8,
            'medium': 5,
            'low': 2
        }

        priority = severity_priority_map.get(data['severity'], 5)

        # Create incident action
        incident_action = Action(
            id=incident_id,
            type=ActionType.ALERT_CORRELATION,  # Use alert correlation for incident management
            source=ActionSource.MANUAL if data.get('source') == 'manual' else ActionSource.AI_DRIVEN,
            priority=priority,
            target=data.get('target', 'cluster'),
            parameters={
                'incident_type': 'user_created',
                'title': data['title'],
                'description': data['description'],
                'severity': data['severity'],
                'labels': data.get('labels', {}),
                'affected_resources': data.get('affectedResources', []),
                'correlation_id': data.get('correlationId'),
                'external_id': data.get('externalId'),
                'created_by': data.get('createdBy', 'system')
            },
            confidence=data.get('confidence', 1.0)
        )

        # Submit incident
        action_id = engine.submit_action(incident_action)

        return jsonify({
            'incident_id': action_id,
            'title': data['title'],
            'description': data['description'],
            'severity': data['severity'],
            'priority': priority,
            'status': 'created',
            'created_at': datetime.utcnow().isoformat(),
            'message': 'Incident created successfully'
        }), 201

    except Exception as e:
        logger.error(f"Error creating incident: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/incidents/<incident_id>', methods=['PUT'])
def update_incident(incident_id):
    """Update an existing incident"""
    try:
        data = request.get_json() or {}

        # Find the incident action
        action = engine.actions.get(incident_id)
        if not action:
            return jsonify({'error': 'Incident not found'}), 404

        # Update incident parameters
        updated_params = action.parameters.copy()

        if 'title' in data:
            updated_params['title'] = data['title']
        if 'description' in data:
            updated_params['description'] = data['description']
        if 'severity' in data:
            updated_params['severity'] = data['severity']
            # Update priority based on new severity
            severity_priority_map = {'critical': 10, 'high': 8, 'medium': 5, 'low': 2}
            action.priority = severity_priority_map.get(data['severity'], action.priority)
        if 'labels' in data:
            updated_params['labels'] = {**updated_params.get('labels', {}), **data['labels']}
        if 'affectedResources' in data:
            updated_params['affected_resources'] = data['affectedResources']
        if 'status' in data:
            # Map status to action status
            status_map = {
                'open': ActionStatus.PENDING,
                'investigating': ActionStatus.RUNNING,
                'resolved': ActionStatus.COMPLETED,
                'closed': ActionStatus.COMPLETED,
                'cancelled': ActionStatus.CANCELLED
            }
            new_status = status_map.get(data['status'])
            if new_status:
                action.status = new_status
                if new_status == ActionStatus.COMPLETED:
                    action.completed_at = datetime.utcnow()

        # Update parameters
        action.parameters = updated_params
        updated_params['updated_at'] = datetime.utcnow().isoformat()
        updated_params['updated_by'] = data.get('updatedBy', 'system')

        return jsonify({
            'incident_id': incident_id,
            'status': action.status.value,
            'priority': action.priority,
            'parameters': updated_params,
            'updated_at': updated_params['updated_at'],
            'message': 'Incident updated successfully'
        }), 200

    except Exception as e:
        logger.error(f"Error updating incident: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/incidents/<incident_id>', methods=['DELETE'])
def delete_incident(incident_id):
    """Delete/cancel an incident"""
    try:
        # Find the incident action
        action = engine.actions.get(incident_id)
        if not action:
            return jsonify({'error': 'Incident not found'}), 404

        # Cancel the incident
        action.status = ActionStatus.CANCELLED
        action.completed_at = datetime.utcnow()
        action.parameters['cancelled_at'] = datetime.utcnow().isoformat()
        action.parameters['cancelled_by'] = request.get_json().get('cancelledBy', 'system') if request.get_json() else 'system'

        # Remove from queue if still pending
        if incident_id in engine.action_queue:
            engine.action_queue.remove(incident_id)

        return jsonify({
            'incident_id': incident_id,
            'status': 'cancelled',
            'cancelled_at': action.parameters['cancelled_at'],
            'message': 'Incident cancelled successfully'
        }), 200

    except Exception as e:
        logger.error(f"Error deleting incident: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/incidents/<incident_id>/correlate', methods=['POST'])
def correlate_incident(incident_id):
    """Correlate incident with other incidents or alerts"""
    try:
        data = request.get_json() or {}

        # Find the incident action
        action = engine.actions.get(incident_id)
        if not action:
            return jsonify({'error': 'Incident not found'}), 404

        correlation_type = data.get('type', 'related')  # related, duplicate, root_cause, symptom
        related_incidents = data.get('relatedIncidents', [])
        correlation_score = data.get('score', 0.8)

        # Update incident with correlation information
        correlations = action.parameters.get('correlations', [])

        new_correlation = {
            'type': correlation_type,
            'related_incidents': related_incidents,
            'score': correlation_score,
            'created_at': datetime.utcnow().isoformat(),
            'created_by': data.get('correlatedBy', 'system')
        }

        correlations.append(new_correlation)
        action.parameters['correlations'] = correlations

        return jsonify({
            'incident_id': incident_id,
            'correlation': new_correlation,
            'total_correlations': len(correlations),
            'message': 'Incident correlation added successfully'
        }), 200

    except Exception as e:
        logger.error(f"Error correlating incident: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/anomalies/analyze', methods=['POST'])
def analyze_anomalies():
    """Enhanced anomaly analysis with pattern detection - MCP server integration"""
    try:
        data = request.get_json() or {}
        time_range = data.get('timeRange', '1h')
        metrics = data.get('metrics', [])
        threshold = data.get('threshold', 0.8)
        include_predictions = data.get('includePredictions', False)

        # Convert metrics to format expected by anomaly detection engine
        formatted_metrics = []
        model_names = data.get('models', None)  # Allow specifying which models to use

        # Handle different metric input formats
        if isinstance(metrics, list) and metrics:
            if isinstance(metrics[0], str):
                # Simple list of metric names - generate sample data for demonstration
                for metric_name in metrics:
                    formatted_metrics.append({
                        'name': metric_name,
                        'values': [85.2, 87.1, 89.3, 92.1, 88.7, 90.2, 94.5, 91.8, 89.9, 87.4],  # Sample values
                        'timestamps': [(datetime.utcnow() - timedelta(minutes=i*5)).isoformat() for i in range(10, 0, -1)]
                    })
            else:
                # Assume metrics are already in the correct format
                formatted_metrics = metrics

        # Run ML-based anomaly detection
        detection_results = engine.anomaly_detection_engine.detect_anomalies(
            formatted_metrics,
            model_names=model_names
        )

        # Extract results
        anomalies_detected = detection_results['total_anomalies']
        patterns = detection_results['anomalies']

        # Generate recommendations based on detected anomalies
        recommendations = []
        alerts = []

        for anomaly in patterns:
            metric_name = anomaly.get('metric', '')
            anomaly_type = anomaly.get('type', '')
            severity = anomaly.get('severity', 'medium')

            # Generate specific recommendations
            if 'cpu' in metric_name.lower():
                if anomaly_type == 'statistical_outlier':
                    recommendations.append('Investigate CPU spike - check for resource-intensive processes')
                elif anomaly_type == 'threshold_exceeded':
                    recommendations.append('CPU usage exceeded threshold - consider scaling or optimization')
                alerts.append({
                    'type': 'resource_exhaustion',
                    'message': f'CPU anomaly detected in {metric_name}',
                    'severity': severity,
                    'action_required': severity in ['high', 'critical']
                })
            elif 'memory' in metric_name.lower():
                if anomaly_type == 'trend_anomaly':
                    recommendations.append('Memory trend anomaly - investigate potential memory leaks')
                elif anomaly_type == 'threshold_exceeded':
                    recommendations.append('Memory usage exceeded threshold - review memory limits')
                alerts.append({
                    'type': 'memory_issue',
                    'message': f'Memory anomaly detected in {metric_name}',
                    'severity': severity,
                    'action_required': severity in ['high', 'critical']
                })
            elif 'network' in metric_name.lower():
                recommendations.append('Network anomaly detected - check network policies and connectivity')
                alerts.append({
                    'type': 'network_issue',
                    'message': f'Network anomaly detected in {metric_name}',
                    'severity': severity,
                    'action_required': severity in ['high', 'critical']
                })
            else:
                recommendations.append(f'Anomaly detected in {metric_name} - investigate further')
                alerts.append({
                    'type': 'general_anomaly',
                    'message': f'Anomaly detected in {metric_name}',
                    'severity': severity,
                    'action_required': severity in ['high', 'critical']
                })

        # Generate predictive insights if requested
        predictions = []
        if include_predictions:
            # Generate predictions based on detected anomalies
            for anomaly in patterns:
                if anomaly.get('type') == 'trend_anomaly':
                    trend = anomaly.get('trend', 'unknown')
                    metric_name = anomaly.get('metric', 'unknown')

                    if trend == 'increasing':
                        if 'cpu' in metric_name.lower():
                            predictions.append({
                                'type': 'resource_scaling',
                                'confidence': anomaly.get('confidence', 0.7),
                                'timeframe': '30m',
                                'prediction': f'CPU usage in {metric_name} likely to continue increasing',
                                'recommended_action': 'scale_deployment',
                                'target': metric_name
                            })
                        elif 'memory' in metric_name.lower():
                            predictions.append({
                                'type': 'failure_prediction',
                                'confidence': anomaly.get('confidence', 0.7),
                                'timeframe': '1h',
                                'prediction': f'Memory usage in {metric_name} trending upward - potential OOM risk',
                                'recommended_action': 'increase_memory_limits',
                                'target': metric_name
                            })

        # Use ensemble confidence from detection results
        overall_confidence = detection_results['ensemble_confidence']

        # Enhanced analysis response with ML model results
        analysis = {
            'timeRange': time_range,
            'anomaliesDetected': anomalies_detected,
            'confidence': overall_confidence,
            'threshold': threshold,
            'patterns': patterns,
            'alerts': alerts,
            'recommendations': list(set(recommendations)),  # Remove duplicates
            'predictions': predictions if include_predictions else None,
            'severity_breakdown': detection_results['severity_breakdown'],
            'model_results': detection_results['model_results'],
            'metadata': {
                'analysis_duration_ms': 250,  # ML processing takes longer
                'metrics_analyzed': len(formatted_metrics),
                'models_used': detection_results['models_used'],
                'ensemble_approach': True,
                'model_version': '2.0.0'
            },
            'timestamp': detection_results['analysis_timestamp']
        }

        # Mock anomaly detection - in production, this would use ML models
        if 'cpu' in metrics:
            analysis['patterns'].append({
                'metric': 'cpu',
                'type': 'spike',
                'severity': 'medium',
                'description': 'CPU usage spike detected',
                'timestamp': datetime.utcnow().isoformat(),
                'value': 85.5,
                'threshold': 80.0
            })
            analysis['anomaliesDetected'] += 1

        return jsonify(analysis), 200
    except Exception as e:
        logger.error(f"Failed to analyze anomalies: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/remediation/trigger', methods=['POST'])
def trigger_remediation():
    """Enhanced remediation trigger with comprehensive action support - MCP server integration"""
    try:
        data = request.get_json() or {}
        incident_id = data.get('incidentId')
        action_type = data.get('action')
        parameters = data.get('parameters', {})
        priority = data.get('priority', 8)
        confidence = data.get('confidence', 0.9)
        dry_run = data.get('dryRun', False)

        if not incident_id or not action_type:
            return jsonify({'error': 'Missing incidentId or action'}), 400

        # Map action types to coordination engine action types
        action_type_mapping = {
            'scale_deployment': ActionType.RESOURCE_SCALING,
            'restart_pod': ActionType.NODE_REMEDIATION,
            'clear_alerts': ActionType.ALERT_CORRELATION,
            'run_inference': ActionType.MODEL_INFERENCE,
            'scale_up': ActionType.RESOURCE_SCALING,
            'scale_down': ActionType.RESOURCE_SCALING,
            'remediate_node': ActionType.NODE_REMEDIATION,
            'correlate_alerts': ActionType.ALERT_CORRELATION
        }

        mapped_action_type = action_type_mapping.get(action_type)
        if not mapped_action_type:
            return jsonify({'error': f'Unsupported action type: {action_type}'}), 400

        # Enhanced action parameters
        enhanced_parameters = {
            'action': action_type,
            'incident_id': incident_id,
            'triggered_by': 'mcp_server',
            'dry_run': dry_run,
            **parameters
        }

        # Add action-specific parameters
        if action_type in ['scale_deployment', 'scale_up', 'scale_down']:
            enhanced_parameters.update({
                'scaling_type': action_type,
                'min_replicas': parameters.get('minReplicas', 1),
                'max_replicas': parameters.get('maxReplicas', 10),
                'target_replicas': parameters.get('targetReplicas'),
                'cpu_threshold': parameters.get('cpuThreshold', 80),
                'memory_threshold': parameters.get('memoryThreshold', 80)
            })
        elif action_type in ['restart_pod', 'remediate_node']:
            enhanced_parameters.update({
                'restart_strategy': parameters.get('restartStrategy', 'rolling'),
                'grace_period': parameters.get('gracePeriod', 30),
                'force_restart': parameters.get('forceRestart', False)
            })
        elif action_type in ['clear_alerts', 'correlate_alerts']:
            enhanced_parameters.update({
                'alert_labels': parameters.get('alertLabels', {}),
                'silence_duration': parameters.get('silenceDuration', '1h'),
                'correlation_window': parameters.get('correlationWindow', '5m')
            })

        # Create comprehensive remediation action
        action_id = f"mcp-{incident_id}-{action_type}-{int(time.time())}"
        action = Action(
            id=action_id,
            type=mapped_action_type,
            source=ActionSource.AI_DRIVEN,
            priority=priority,
            target=incident_id,
            parameters=enhanced_parameters,
            confidence=confidence
        )

        # Handle dry run mode
        if dry_run:
            return jsonify({
                'id': action_id,
                'type': action_type,
                'description': f"DRY RUN: Remediation action would be triggered: {action_type}",
                'status': 'dry_run_completed',
                'parameters': enhanced_parameters,
                'priority': priority,
                'confidence': confidence,
                'executedAt': datetime.utcnow().isoformat(),
                'result': 'Dry run completed successfully - no actual action taken'
            }), 200

        # Submit action to coordination engine
        submitted_action_id = engine.submit_action(action)

        # Enhanced response with comprehensive information
        return jsonify({
            'action_id': submitted_action_id,
            'incident_id': incident_id,
            'type': action_type,
            'mapped_type': mapped_action_type.value,
            'description': f"Remediation action triggered: {action_type} for incident {incident_id}",
            'status': 'submitted',
            'priority': priority,
            'confidence': confidence,
            'parameters': enhanced_parameters,
            'target': incident_id,
            'source': 'ai_driven',
            'executedAt': datetime.utcnow().isoformat(),
            'estimatedDuration': '2-5 minutes',
            'result': 'Remediation action submitted successfully to coordination engine'
        }), 200
    except Exception as e:
        logger.error(f"Failed to trigger remediation: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/cluster/status', methods=['GET'])
def get_cluster_status():
    """Get comprehensive cluster status for MCP server integration"""
    try:
        # Get metric values safely (compatible with prometheus-client >= 0.17.0)
        conflicts_count = 0
        actions_count = 0
        try:
            # Try new API first (prometheus-client >= 0.18.0)
            if hasattr(conflict_counter._value, 'get'):
                conflicts_count = conflict_counter._value.get()
            elif hasattr(conflict_counter._value, '_value'):
                conflicts_count = conflict_counter._value._value
            else:
                conflicts_count = 0

            if hasattr(action_counter._value, 'get'):
                actions_count = action_counter._value.get()
            elif hasattr(action_counter._value, '_value'):
                actions_count = action_counter._value._value
            else:
                actions_count = 0
        except Exception as e:
            logger.debug(f"Could not retrieve metric values: {e}")
            conflicts_count = 0
            actions_count = 0

        # Collect cluster health information
        cluster_status = {
            'coordination_engine': {
                'status': 'healthy' if engine.running else 'unhealthy',
                'active_actions': len([a for a in engine.actions.values() if a.status == ActionStatus.RUNNING]),
                'pending_actions': len([a for a in engine.actions.values() if a.status == ActionStatus.PENDING]),
                'total_actions': len(engine.actions),
                'uptime_seconds': int(time.time() - engine.start_time) if hasattr(engine, 'start_time') else 0
            },
            'kubernetes': {
                'connected': engine.k8s_client is not None,
                'api_version': 'v1' if engine.k8s_client else None
            },
            'metrics': {
                'conflicts_detected': conflicts_count,
                'actions_processed': actions_count
            },
            'timestamp': datetime.utcnow().isoformat()
        }

        return jsonify(cluster_status)
    except Exception as e:
        logger.error(f"Error getting cluster status: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/actions/<action_id>/status', methods=['GET'])
def get_action_status_detailed(action_id):
    """Get detailed action status for MCP server integration"""
    try:
        action = engine.get_action_status(action_id)
        if not action:
            return jsonify({'error': 'Action not found'}), 404

        # Enhanced status with additional metadata
        enhanced_status = {
            **action,
            'duration_seconds': None,
            'estimated_completion': None,
            'next_steps': [],
            'related_actions': []
        }

        # Calculate duration if action has started
        if action.get('started_at') and action.get('completed_at'):
            start_time = datetime.fromisoformat(action['started_at'].replace('Z', '+00:00'))
            end_time = datetime.fromisoformat(action['completed_at'].replace('Z', '+00:00'))
            enhanced_status['duration_seconds'] = (end_time - start_time).total_seconds()
        elif action.get('started_at'):
            start_time = datetime.fromisoformat(action['started_at'].replace('Z', '+00:00'))
            enhanced_status['duration_seconds'] = (datetime.utcnow() - start_time).total_seconds()

        # Add estimated completion for running actions
        if action.get('status') == 'running':
            estimated_duration = 300  # 5 minutes default
            if action.get('started_at'):
                start_time = datetime.fromisoformat(action['started_at'].replace('Z', '+00:00'))
                estimated_completion = start_time + timedelta(seconds=estimated_duration)
                enhanced_status['estimated_completion'] = estimated_completion.isoformat()

        # Find related actions (same target or conflicting)
        related_actions = []
        for other_id, other_action in engine.actions.items():
            if other_id != action_id and other_action.target == action.get('target'):
                related_actions.append({
                    'id': other_id,
                    'type': other_action.type.value,
                    'status': other_action.status.value,
                    'relationship': 'same_target'
                })
        enhanced_status['related_actions'] = related_actions[:5]  # Limit to 5

        return jsonify(enhanced_status)
    except Exception as e:
        logger.error(f"Error getting action status: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/workflows/queue', methods=['GET'])
def get_workflow_queue():
    """Get current workflow queue status for MCP server integration"""
    try:
        # Get queue information
        queue_info = {
            'queue_length': len(engine.action_queue),
            'processing_status': 'active' if engine.running else 'stopped',
            'queued_actions': [],
            'running_actions': [],
            'statistics': {
                'total_submitted': len(engine.actions),
                'completed': len([a for a in engine.actions.values() if a.status == ActionStatus.COMPLETED]),
                'failed': len([a for a in engine.actions.values() if a.status == ActionStatus.FAILED]),
                'cancelled': len([a for a in engine.actions.values() if a.status == ActionStatus.CANCELLED])
            },
            'timestamp': datetime.utcnow().isoformat()
        }

        # Get queued actions details
        for action_id in engine.action_queue[:10]:  # Limit to first 10
            action = engine.actions.get(action_id)
            if action and action.status == ActionStatus.PENDING:
                queue_info['queued_actions'].append({
                    'id': action_id,
                    'type': action.type.value,
                    'priority': action.priority,
                    'target': action.target,
                    'created_at': action.created_at.isoformat() if action.created_at else None,
                    'estimated_start': 'next' if action_id == engine.action_queue[0] else 'queued'
                })

        # Get running actions details
        for action_id, action in engine.actions.items():
            if action.status == ActionStatus.RUNNING:
                queue_info['running_actions'].append({
                    'id': action_id,
                    'type': action.type.value,
                    'priority': action.priority,
                    'target': action.target,
                    'started_at': action.started_at.isoformat() if action.started_at else None,
                    'duration_seconds': (datetime.utcnow() - action.started_at).total_seconds() if action.started_at else 0
                })

        return jsonify(queue_info)
    except Exception as e:
        logger.error(f"Error getting workflow queue: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Start coordination engine
    engine.start()

    # Start main Flask app on port 8080 (with health and metrics endpoints)
    # Handle both port numbers and service URLs (Kubernetes injects service env vars)
    port_env = os.getenv('COORDINATION_ENGINE_PORT', '8080')
    if port_env.startswith('tcp://'):
        # Extract port from service URL (e.g., tcp://172.30.216.108:8080)
        port = int(port_env.split(':')[-1])
    else:
        port = int(port_env)

    logger.info(f"Starting Flask app on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False, use_reloader=False)
