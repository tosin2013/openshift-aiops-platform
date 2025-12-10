FROM registry.redhat.io/ubi8/python-39:latest

# Set working directory
WORKDIR /opt/app-root/src

# Copy requirements for predictive analytics
COPY requirements-predictive.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements-predictive.txt

# Copy model source code
COPY predictive_analytics.py .
COPY model_server.py .

# Create non-root user (already exists in UBI image)
USER 1001

# Expose port for model serving
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV MODEL_NAME=predictive-analytics
ENV MODEL_VERSION=1.0.0

# Run the model server
CMD ["python", "model_server.py"]
