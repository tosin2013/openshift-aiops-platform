# Multi-stage build for Model Serving
FROM registry.redhat.io/ubi8/python-39:latest AS builder

# Set working directory
WORKDIR /app

# Copy requirements files
COPY requirements-anomaly.txt requirements-predictive.txt ./

# Install dependencies
RUN pip install --no-cache-dir -r requirements-anomaly.txt -r requirements-predictive.txt

# Production stage
FROM registry.redhat.io/ubi8/python-39:latest

# Create directories with proper permissions for OpenShift
WORKDIR /app

# Copy requirements files
COPY requirements-anomaly.txt requirements-predictive.txt ./

# Install only production dependencies
RUN pip install --no-cache-dir -r requirements-anomaly.txt -r requirements-predictive.txt

# Copy model files
COPY anomaly_detector.py predictive_analytics.py model_server.py ./

# OpenShift will run as a random non-root user
# No explicit USER directive needed

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8080/health')" || exit 1

# Expose port for model serving
EXPOSE 8080

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV LOG_LEVEL=info

# Start the model server
CMD ["python", "model_server.py"]
