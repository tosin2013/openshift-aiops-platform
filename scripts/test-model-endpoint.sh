#!/bin/bash
# Test a specific model endpoint with detailed diagnostics

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <model-name> [namespace]"
    echo "Example: $0 anomaly-detector self-healing-platform"
    exit 1
fi

MODEL_NAME=$1
NAMESPACE="${2:-self-healing-platform}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Model Endpoint Test: $MODEL_NAME"
echo "Namespace: $NAMESPACE"
echo "=========================================="

# Check InferenceService exists
if ! oc get inferenceservice $MODEL_NAME -n $NAMESPACE &>/dev/null; then
    echo -e "${RED}❌ InferenceService '$MODEL_NAME' not found in namespace '$NAMESPACE'${NC}"
    exit 1
fi

echo -e "${GREEN}✅ InferenceService found${NC}"

# Get InferenceService details
echo ""
echo -e "${BLUE}InferenceService Status:${NC}"
oc get inferenceservice $MODEL_NAME -n $NAMESPACE

# Get predictor pod
echo ""
echo -e "${BLUE}Predictor Pods:${NC}"
oc get pods -l serving.kserve.io/inferenceservice=$MODEL_NAME -n $NAMESPACE

# Get pod IP
PREDICTOR_IP=$(oc get pod -l serving.kserve.io/inferenceservice=$MODEL_NAME \
    -n $NAMESPACE --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)

if [ -z "$PREDICTOR_IP" ]; then
    echo -e "${RED}❌ No running predictor pod found${NC}"
    echo ""
    echo "Troubleshooting tips:"
    echo "1. Check pod logs: oc logs -n $NAMESPACE -l serving.kserve.io/inferenceservice=$MODEL_NAME"
    echo "2. Describe pod: oc describe pod -n $NAMESPACE -l serving.kserve.io/inferenceservice=$MODEL_NAME"
    echo "3. Check InferenceService events: oc describe inferenceservice $MODEL_NAME -n $NAMESPACE"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Predictor pod running${NC}"
echo "Pod IP: $PREDICTOR_IP"

# Test /v1/models endpoint (list models)
echo ""
echo "=========================================="
echo "Test 1: List Models"
echo "=========================================="
echo "GET http://${PREDICTOR_IP}:8080/v1/models"
echo ""

if RESPONSE=$(curl -s -w "\n%{http_code}" http://${PREDICTOR_IP}:8080/v1/models 2>&1); then
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)

    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ Success (HTTP $HTTP_CODE)${NC}"
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"

        # Check if model name matches
        REGISTERED_MODEL=$(echo "$BODY" | jq -r '.models[0]' 2>/dev/null || echo "")
        if [ "$REGISTERED_MODEL" = "$MODEL_NAME" ]; then
            echo -e "${GREEN}✅ Model registered as: '$REGISTERED_MODEL'${NC}"
        else
            echo -e "${YELLOW}⚠️  Model registered as: '$REGISTERED_MODEL' (expected: '$MODEL_NAME')${NC}"
        fi
    else
        echo -e "${RED}❌ Failed (HTTP $HTTP_CODE)${NC}"
        echo "$BODY"
    fi
else
    echo -e "${RED}❌ Connection failed${NC}"
fi

# Test /v1/models/<model> endpoint (model metadata)
echo ""
echo "=========================================="
echo "Test 2: Model Metadata"
echo "=========================================="
echo "GET http://${PREDICTOR_IP}:8080/v1/models/$MODEL_NAME"
echo ""

if RESPONSE=$(curl -s -w "\n%{http_code}" http://${PREDICTOR_IP}:8080/v1/models/$MODEL_NAME 2>&1); then
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)

    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ Success (HTTP $HTTP_CODE)${NC}"
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    else
        echo -e "${RED}❌ Failed (HTTP $HTTP_CODE)${NC}"
        echo "$BODY"
    fi
else
    echo -e "${RED}❌ Connection failed${NC}"
fi

# Test prediction endpoint
echo ""
echo "=========================================="
echo "Test 3: Make Prediction"
echo "=========================================="
echo "POST http://${PREDICTOR_IP}:8080/v1/models/$MODEL_NAME:predict"
echo ""

# Generate test payload based on model type
if [ "$MODEL_NAME" = "anomaly-detector" ]; then
    echo "Using anomaly-detector test payload (45 features)..."
    TEST_PAYLOAD='{"instances": [[0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6]]}'
elif [ "$MODEL_NAME" = "predictive-analytics" ]; then
    echo "Using predictive-analytics test payload (120 features)..."
    TEST_PAYLOAD='{"instances": [[0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4]]}'
else
    echo "Using generic test payload (10 features)..."
    TEST_PAYLOAD='{"instances": [[0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5]]}'
fi

if RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    http://${PREDICTOR_IP}:8080/v1/models/$MODEL_NAME:predict \
    -H 'Content-Type: application/json' \
    -d "$TEST_PAYLOAD" 2>&1); then

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)

    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ Success (HTTP $HTTP_CODE)${NC}"
        echo ""
        echo "Prediction response:"
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"

        # Extract prediction value if available
        PREDICTION=$(echo "$BODY" | jq -r '.predictions[0]' 2>/dev/null || echo "")
        if [ -n "$PREDICTION" ] && [ "$PREDICTION" != "null" ]; then
            echo ""
            echo -e "${GREEN}✅ Model is serving predictions${NC}"
        fi
    else
        echo -e "${RED}❌ Failed (HTTP $HTTP_CODE)${NC}"
        echo "$BODY"
    fi
else
    echo -e "${RED}❌ Connection failed${NC}"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Model: $MODEL_NAME"
echo "Namespace: $NAMESPACE"
echo "Pod IP: $PREDICTOR_IP"
echo ""
echo "Useful commands:"
echo "  View logs:    oc logs -n $NAMESPACE -l serving.kserve.io/inferenceservice=$MODEL_NAME"
echo "  Describe pod: oc describe pod -n $NAMESPACE -l serving.kserve.io/inferenceservice=$MODEL_NAME"
echo "  Shell access: oc exec -it -n $NAMESPACE deployment/model-troubleshooting-utilities -- /bin/bash"
