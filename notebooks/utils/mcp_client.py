"""
Cluster Health MCP Client for Self-Healing Platform

This module provides integration with the Cluster Health MCP Server for:
- Real-time cluster health monitoring and incident data
- Self-healing capabilities and remediation workflows
- Natural language interaction with platform operations
- Integration with OpenShift Lightspeed conversational AI

References:
- ADR-014: Cluster Health MCP Server for OpenShift Lightspeed Integration
- PRD Section 5.4: Conversational AI Interface
"""

import requests
import json
import os
from datetime import datetime
from typing import Dict, List, Optional, Any
import warnings

class ClusterHealthMCPClient:
    """
    Client for interacting with the Cluster Health MCP Server

    This client provides access to the cluster-native MCP server that integrates
    with OpenShift Lightspeed for conversational AI capabilities.

    Server URL: http://cluster-health-mcp-server.self-healing-platform.svc.cluster.local:3000
    """

    def __init__(self, server_url: str = None):
        """
        Initialize Cluster Health MCP client

        Args:
            server_url: MCP server URL (defaults to cluster service)
        """
        self.server_url = server_url or "http://cluster-health-mcp-server.self-healing-platform.svc.cluster.local:3000"
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'Self-Healing-Platform-Notebook/1.0'
        })
        self.available = self._check_server_availability()

        if self.available:
            print("✅ Cluster Health MCP Server connected")
            print(f"🔗 Server URL: {self.server_url}")
            print("🤖 OpenShift Lightspeed integration ready")
        else:
            print("⚠️ Cluster Health MCP server not available - using simulation mode")

    def _check_server_availability(self) -> bool:
        """
        Check if Cluster Health MCP server is available

        Returns:
            True if MCP server is available, False otherwise
        """
        try:
            response = self.session.get(
                f"{self.server_url}/health",
                timeout=5
            )
            return response.status_code == 200
        except Exception as e:
            print(f"⚠️ Cluster Health MCP server check failed: {e}")
            return False

    def suggest_adr(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Get ADR suggestions based on development context

        Args:
            context: Development context including code changes, issues, etc.

        Returns:
            Dictionary with ADR suggestions and recommendations
        """
        if not self.available:
            return self._simulate_adr_suggestions(context)

        try:
            # In a real implementation, this would call the MCP server directly
            # For now, we'll simulate the response based on the context
            print("🔍 Analyzing development context for ADR suggestions...")

            suggestions = []

            # Analyze context and generate relevant suggestions
            if "anomaly" in str(context).lower():
                suggestions.append({
                    "title": "Anomaly Detection Model Architecture",
                    "rationale": "Document model selection and architecture decisions",
                    "priority": "high"
                })

            if "deployment" in str(context).lower():
                suggestions.append({
                    "title": "Deployment Strategy for ML Models",
                    "rationale": "Define deployment patterns and rollback strategies",
                    "priority": "medium"
                })

            return {
                "suggestions": suggestions,
                "context_analyzed": context,
                "timestamp": datetime.now().isoformat()
            }

        except Exception as e:
            print(f"❌ Failed to get ADR suggestions: {e}")
            return {"error": str(e), "suggestions": []}

    def get_cluster_health(self) -> Dict[str, Any]:
        """
        Get current cluster health status and incidents

        Returns:
            Dictionary with cluster health information
        """
        if not self.available:
            return self._simulate_cluster_health()

        try:
            response = self.session.get(
                f"{self.server_url}/mcp/resources/cluster-health",
                timeout=10
            )

            if response.status_code == 200:
                return response.json()
            else:
                return {"error": f"HTTP {response.status_code}", "health": "unknown"}

        except Exception as e:
            print(f"❌ Failed to get cluster health: {e}")
            return {"error": str(e), "health": "unknown"}

    def get_active_incidents(self) -> Dict[str, Any]:
        """
        Get active incidents and alerts from the platform

        Returns:
            Dictionary with active incidents
        """
        if not self.available:
            return self._simulate_incidents()

        try:
            response = self.session.get(
                f"{self.server_url}/mcp/resources/incidents",
                timeout=10
            )

            if response.status_code == 200:
                return response.json()
            else:
                return {"error": f"HTTP {response.status_code}", "incidents": []}

        except Exception as e:
            print(f"❌ Failed to get incidents: {e}")
            return {"error": str(e), "incidents": []}

    def trigger_self_healing(self, incident_id: str, action: str) -> Dict[str, Any]:
        """
        Trigger self-healing action for a specific incident

        Args:
            incident_id: ID of the incident to remediate
            action: Remediation action to take

        Returns:
            Dictionary with remediation result
        """
        if not self.available:
            return self._simulate_remediation(incident_id, action)

        try:
            response = self.session.post(
                f"{self.server_url}/mcp/tools/trigger-remediation",
                json={
                    "incident_id": incident_id,
                    "action": action,
                    "timestamp": datetime.now().isoformat()
                },
                timeout=30
            )

            if response.status_code == 200:
                return response.json()
            else:
                return {"error": f"HTTP {response.status_code}", "success": False}

        except Exception as e:
            print(f"❌ Failed to trigger self-healing: {e}")
            return {"error": str(e), "success": False}

    def query_anomaly_patterns(self, metrics_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Query anomaly detection patterns using MCP server intelligence

        Args:
            metrics_data: Metrics data to analyze

        Returns:
            Dictionary with anomaly analysis results
        """
        if not self.available:
            return self._simulate_anomaly_analysis(metrics_data)

        try:
            response = self.session.post(
                f"{self.server_url}/mcp/tools/analyze-anomalies",
                json={
                    "metrics": metrics_data,
                    "timestamp": datetime.now().isoformat()
                },
                timeout=20
            )

            if response.status_code == 200:
                return response.json()
            else:
                return {"error": f"HTTP {response.status_code}", "anomalies": []}

        except Exception as e:
            print(f"❌ Failed to analyze anomalies: {e}")
            return {"error": str(e), "anomalies": []}

    def validate_deployment(self, deployment_config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Validate deployment readiness with comprehensive checks

        Args:
            deployment_config: Deployment configuration and context

        Returns:
            Validation results with readiness status and recommendations
        """
        try:
            payload = {
                "tool": "deployment_readiness",
                "parameters": {
                    "operation": "check_readiness",
                    "targetEnvironment": deployment_config.get("environment", "development"),
                    "strictMode": deployment_config.get("strict_mode", True),
                    "projectPath": "/workspace/openshift-aiops-platform"
                }
            }

            response = self.session.post(
                f"{self.base_url}/api/mcp/tools",
                json=payload,
                timeout=self.timeout
            )

            if response.status_code == 200:
                return response.json()
            else:
                return {"ready": False, "error": f"HTTP {response.status_code}"}

        except Exception as e:
            print(f"❌ Deployment validation failed: {e}")
            return {"ready": False, "error": str(e)}

    def perform_research(self, question: str, context: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Perform research-driven analysis using cascading sources

        Args:
            question: Research question to investigate
            context: Additional context for research

        Returns:
            Research results with findings and recommendations
        """
        try:
            payload = {
                "tool": "perform_research",
                "parameters": {
                    "question": question,
                    "projectPath": "/workspace/openshift-aiops-platform",
                    "adrDirectory": "docs/adrs"
                }
            }

            if context:
                payload["parameters"]["context"] = context

            response = self.session.post(
                f"{self.base_url}/api/mcp/tools",
                json=payload,
                timeout=self.timeout * 2  # Research may take longer
            )

            if response.status_code == 200:
                return response.json()
            else:
                return {"findings": [], "error": f"HTTP {response.status_code}"}

        except Exception as e:
            print(f"❌ Research request failed: {e}")
            return {"findings": [], "error": str(e)}

    def analyze_notebook_context(self, notebook_path: str, cell_content: str) -> Dict[str, Any]:
        """
        Analyze notebook context for intelligent suggestions

        Args:
            notebook_path: Path to the current notebook
            cell_content: Content of the current cell being developed

        Returns:
            Analysis results with suggestions and recommendations
        """
        context = {
            "type": "notebook_development",
            "notebook_path": notebook_path,
            "cell_content": cell_content,
            "timestamp": datetime.now().isoformat(),
            "goals": ["develop anomaly detection models", "integrate with self-healing platform"],
            "focus_areas": ["machine learning", "anomaly detection", "self-healing"]
        }

        # Get ADR suggestions based on notebook context
        adr_suggestions = self.suggest_adr(context)

        # Perform research if needed
        research_results = None
        if "anomaly" in cell_content.lower() or "model" in cell_content.lower():
            research_question = f"Best practices for {self._extract_key_concepts(cell_content)} in self-healing systems"
            research_results = self.perform_research(research_question, context)

        return {
            "adr_suggestions": adr_suggestions,
            "research_results": research_results,
            "context": context,
            "timestamp": datetime.now().isoformat()
        }

    def smart_git_validation(self, changes: List[str], commit_message: str) -> Dict[str, Any]:
        """
        Validate git changes before commit using MCP smart git push

        Args:
            changes: List of changed files
            commit_message: Proposed commit message

        Returns:
            Validation results with security and quality checks
        """
        try:
            payload = {
                "tool": "smart_git_push",
                "parameters": {
                    "message": commit_message,
                    "dryRun": True,  # Just validate, don't actually push
                    "projectPath": "/workspace/openshift-aiops-platform"
                }
            }

            response = self.session.post(
                f"{self.base_url}/api/mcp/tools",
                json=payload,
                timeout=self.timeout
            )

            if response.status_code == 200:
                return response.json()
            else:
                return {"safe": False, "error": f"HTTP {response.status_code}"}

        except Exception as e:
            print(f"❌ Git validation failed: {e}")
            return {"safe": False, "error": str(e)}

    def get_memory_context(self, session_id: str = None) -> Dict[str, Any]:
        """
        Get preserved memory context for development session

        Args:
            session_id: Optional session ID for context retrieval

        Returns:
            Memory context with conversation history and insights
        """
        try:
            payload = {
                "tool": "get_conversation_snapshot",
                "parameters": {
                    "recentTurnCount": 10
                }
            }

            response = self.session.post(
                f"{self.base_url}/api/mcp/tools",
                json=payload,
                timeout=self.timeout
            )

            if response.status_code == 200:
                return response.json()
            else:
                return {"context": {}, "error": f"HTTP {response.status_code}"}

        except Exception as e:
            print(f"❌ Memory context retrieval failed: {e}")
            return {"context": {}, "error": str(e)}

    def _extract_key_concepts(self, text: str) -> str:
        """
        Extract key concepts from text for research queries

        Args:
            text: Text to analyze

        Returns:
            Key concepts string
        """
        # Simple keyword extraction
        ml_keywords = ["isolation forest", "anomaly detection", "machine learning",
                      "neural network", "clustering", "classification"]

        platform_keywords = ["openshift", "kubernetes", "prometheus", "self-healing",
                            "coordination engine", "remediation"]

        found_concepts = []
        text_lower = text.lower()

        for keyword in ml_keywords + platform_keywords:
            if keyword in text_lower:
                found_concepts.append(keyword)

        return ", ".join(found_concepts[:3]) if found_concepts else "machine learning"

    def _simulate_adr_suggestions(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Simulate ADR suggestions when MCP server is not available

        Args:
            context: Development context

        Returns:
            Simulated ADR suggestions
        """
        print("🎭 Simulating ADR suggestions (MCP server not available)")

        # Generate realistic suggestions based on context
        suggestions = [
            {
                "title": "Notebook Development Standards",
                "rationale": "Establish standards for notebook development in self-healing platform",
                "priority": "medium",
                "category": "development"
            },
            {
                "title": "Model Validation and Testing Framework",
                "rationale": "Define validation requirements for anomaly detection models",
                "priority": "high",
                "category": "ai-ml"
            }
        ]

        return {
            "suggestions": suggestions,
            "simulated": True,
            "context_analyzed": context,
            "timestamp": datetime.now().isoformat()
        }

    def _simulate_cluster_health(self) -> Dict[str, Any]:
        """Simulate cluster health data when MCP server is not available"""
        print("🎭 Simulating cluster health (MCP server not available)")

        return {
            "health": "healthy",
            "nodes": {
                "total": 3,
                "ready": 3,
                "not_ready": 0
            },
            "pods": {
                "total": 45,
                "running": 42,
                "pending": 2,
                "failed": 1
            },
            "incidents": {
                "critical": 0,
                "warning": 2,
                "info": 3
            },
            "simulated": True,
            "timestamp": datetime.now().isoformat()
        }

    def _simulate_incidents(self) -> Dict[str, Any]:
        """Simulate incident data when MCP server is not available"""
        print("🎭 Simulating incidents (MCP server not available)")

        return {
            "incidents": [
                {
                    "id": "inc-001",
                    "title": "High CPU usage on worker node",
                    "severity": "warning",
                    "status": "active",
                    "created": datetime.now().isoformat(),
                    "description": "Worker node showing sustained high CPU usage"
                },
                {
                    "id": "inc-002",
                    "title": "Pod restart loop detected",
                    "severity": "warning",
                    "status": "investigating",
                    "created": datetime.now().isoformat(),
                    "description": "Application pod restarting frequently"
                }
            ],
            "simulated": True,
            "timestamp": datetime.now().isoformat()
        }

    def _simulate_remediation(self, incident_id: str, action: str) -> Dict[str, Any]:
        """Simulate remediation action when MCP server is not available"""
        print(f"🎭 Simulating remediation for {incident_id}: {action}")

        return {
            "success": True,
            "incident_id": incident_id,
            "action": action,
            "result": "Remediation action simulated successfully",
            "simulated": True,
            "timestamp": datetime.now().isoformat()
        }

    def _simulate_anomaly_analysis(self, metrics_data: Dict[str, Any]) -> Dict[str, Any]:
        """Simulate anomaly analysis when MCP server is not available"""
        print("🎭 Simulating anomaly analysis (MCP server not available)")

        return {
            "anomalies": [
                {
                    "type": "cpu_spike",
                    "severity": "medium",
                    "confidence": 0.85,
                    "description": "Unusual CPU usage pattern detected"
                }
            ],
            "patterns": [
                {
                    "pattern": "daily_cycle",
                    "confidence": 0.92,
                    "description": "Normal daily usage cycle"
                }
            ],
            "simulated": True,
            "timestamp": datetime.now().isoformat()
        }

# Convenience functions for notebook use
def get_cluster_health_client() -> ClusterHealthMCPClient:
    """
    Get configured Cluster Health MCP client instance

    Returns:
        Configured ClusterHealthMCPClient instance
    """
    client = ClusterHealthMCPClient()

    if client.available:
        print("✅ Cluster Health MCP server integration ready")
        print("🤖 Connected to OpenShift Lightspeed backend")
    else:
        print("⚠️ Cluster Health MCP server not available - using simulation mode")

    return client

def analyze_current_notebook(notebook_name: str, current_cell: str) -> Dict[str, Any]:
    """
    Analyze current notebook context for intelligent suggestions

    Args:
        notebook_name: Name of the current notebook
        current_cell: Content of the current cell

    Returns:
        Analysis results with suggestions
    """
    client = get_mcp_client()
    return client.analyze_notebook_context(notebook_name, current_cell)

def validate_before_commit(files: List[str], message: str) -> bool:
    """
    Validate changes before git commit

    Args:
        files: List of files to commit
        message: Commit message

    Returns:
        True if safe to commit, False otherwise
    """
    client = get_mcp_client()
    result = client.smart_git_validation(files, message)

    if result.get("safe", False):
        print("✅ Changes validated - safe to commit")
        return True
    else:
        print(f"❌ Validation failed: {result.get('error', 'Unknown error')}")
        return False

# Example usage functions
def demo_cluster_health_integration():
    """
    Demonstrate Cluster Health MCP integration capabilities
    """
    print("🔧 Cluster Health MCP Integration Demo")
    print("=" * 50)

    client = get_cluster_health_client()

    # Demo 1: Cluster health status
    print("\n🏥 Getting cluster health status...")
    health = client.get_cluster_health()
    if "health" in health:
        print(f"  Cluster Status: {health.get('health', 'unknown')}")
        if "nodes" in health:
            nodes = health["nodes"]
            print(f"  Nodes: {nodes.get('ready', 0)}/{nodes.get('total', 0)} ready")

    # Demo 2: Active incidents
    print("\n🚨 Getting active incidents...")
    incidents = client.get_active_incidents()
    if "incidents" in incidents:
        incident_list = incidents.get("incidents", [])
        print(f"  Found {len(incident_list)} active incidents")
        for incident in incident_list[:2]:  # Show first 2
            print(f"    - {incident.get('title', 'Unknown')}: {incident.get('severity', 'unknown')}")

    # Demo 3: Anomaly analysis
    print("\n🔍 Analyzing anomaly patterns...")
    sample_metrics = {
        "cpu_usage": [0.2, 0.3, 0.8, 0.9, 0.4],
        "memory_usage": [0.5, 0.6, 0.7, 0.8, 0.6],
        "timestamp": datetime.now().isoformat()
    }

    anomalies = client.query_anomaly_patterns(sample_metrics)
    if "anomalies" in anomalies:
        anomaly_list = anomalies.get("anomalies", [])
        print(f"  Found {len(anomaly_list)} anomaly patterns")

    # Demo 4: Self-healing trigger (simulation)
    print("\n🔧 Testing self-healing capabilities...")
    if "incidents" in incidents and incidents.get("incidents"):
        first_incident = incidents["incidents"][0]
        remediation = client.trigger_self_healing(
            first_incident.get("id", "test-001"),
            "restart_pod"
        )
        print(f"  Remediation result: {remediation.get('success', False)}")

    print("\n🎉 Cluster Health MCP integration demo completed!")
    print("💡 This MCP server integrates with OpenShift Lightspeed for conversational AI")

if __name__ == "__main__":
    demo_cluster_health_integration()

print("✅ Cluster Health MCP client module loaded successfully")
print("🔗 Use get_cluster_health_client() to start using Cluster Health MCP server")
print("🤖 Integrates with OpenShift Lightspeed for conversational AI capabilities")
