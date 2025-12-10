---
title: OpenShift AIOps Platform Documentation
---

# OpenShift AIOps Platform

Welcome to the **OpenShift AIOps Platform** - a Self-Healing Platform with AI/ML-driven anomaly detection and automated remediation for OpenShift environments.

This documentation follows the [Diataxis](https://diataxis.fr/) framework to provide clear, well-organized documentation.

## Documentation Structure

Our documentation is organized into four distinct sections:

### 📚 [Tutorials](./tutorials/)
Learning-oriented guides that take you through a process step by step. Perfect for newcomers who want to get started.

### 🔧 [How-To Guides](./how-to/)
Task-oriented recipes that help you accomplish specific goals. Ideal when you know what you want to do.

### 📖 [Reference](./reference/)
Information-oriented technical descriptions of the system. Essential when you need to look up specific details.

### 💡 [Explanation](./explanation/)
Understanding-oriented discussions that clarify and illuminate topics. Great for deepening your knowledge.

## 🚀 Quick Start

New to the platform? Start here:

1. **[Access the Workbench](how-to/access-workbench.md)** - Get started with the AI/ML development environment
2. **[Workbench Development Guide](tutorials/workbench-development-guide.md)** - Complete tutorial for developing self-healing algorithms
3. **[Architecture Overview](explanation/architecture-overview.md)** - Understand the platform design

## 🏗️ Platform Components

- **Coordination Engine**: Orchestrates self-healing actions
- **AI/ML Workbench**: PyTorch-based development environment with GPU support
- **Model Serving**: KServe integration for production model deployment
- **Monitoring**: Prometheus-based observability and alerting
- **Storage**: OpenShift Data Foundation for persistent data and models

## 📋 Current Status

- ✅ **Infrastructure**: OpenShift cluster with ODF storage
- ✅ **Development Environment**: PyTorch workbench operational
- ✅ **Coordination Engine**: Basic framework implemented
- ✅ **Bootstrap Automation**: Deployment and validation complete
- 🚧 **Model Serving**: KServe integration in progress
- 🚧 **Advanced AI**: Anomaly detection models in development

## 🤝 Contributing

This platform is documented through Architectural Decision Records (ADRs). See the [ADR Reference](reference/adrs.md) for all architectural decisions and their rationale.
