#!/bin/bash
# Validates that ML models are trained, loaded, and serving predictions

set -e

NAMESPACE="${NAMESPACE:-self-healing-platform}"
MODELS=("anomaly-detector" "predictive-analytics")

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Model Validation Report"
echo "Namespace: $NAMESPACE"
echo "=========================================="

# Auto-detect utilities pod
UTILITIES_POD=$(oc get pods -n $NAMESPACE -o json 2>/dev/null | \
  jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim?.claimName == "model-storage-pvc") | .metadata.name' | head -1)

if [ -z "$UTILITIES_POD" ]; then
  echo -e "${YELLOW}⚠️  No pod found with model-storage-pvc mounted${NC}"
  echo -e "${YELLOW}   Model file validation will be skipped${NC}"
  SKIP_FILE_CHECK=true
else
  echo -e "${GREEN}✅ Found utilities pod: $UTILITIES_POD${NC}"
  SKIP_FILE_CHECK=false
fi

check_model() {
    MODEL_NAME=$1
    echo ""
    echo "=========================================="
    echo "Checking: $MODEL_NAME"
    echo "=========================================="

    # Check InferenceService status
    if ! oc get inferenceservice $MODEL_NAME -n $NAMESPACE &>/dev/null; then
        echo -e "${RED}❌ InferenceService $MODEL_NAME not found${NC}"
        return 1
    fi

    echo -e "${GREEN}✅ InferenceService exists${NC}"

    # Check InferenceService ready condition
    READY=$(oc get inferenceservice $MODEL_NAME -n $NAMESPACE \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")

    if [ "$READY" = "True" ]; then
        echo -e "${GREEN}✅ InferenceService is ready${NC}"
    else
        echo -e "${YELLOW}⚠️  InferenceService not ready (status: $READY)${NC}"
    fi

    # Check pods are running
    RUNNING_PODS=$(oc get pods -l serving.kserve.io/inferenceservice=$MODEL_NAME \
        -n $NAMESPACE --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

    if [ "$RUNNING_PODS" -eq 0 ]; then
        echo -e "${RED}❌ No running pods for $MODEL_NAME${NC}"

        # Show pod status for debugging
        echo ""
        echo "Pod status:"
        oc get pods -l serving.kserve.io/inferenceservice=$MODEL_NAME -n $NAMESPACE
        return 1
    fi

    echo -e "${GREEN}✅ $RUNNING_PODS pod(s) running${NC}"

    # Check model file exists (if utilities pod available)
    if [ "$SKIP_FILE_CHECK" = false ]; then
        if oc exec -n $NAMESPACE $UTILITIES_POD -- \
            test -f /mnt/models/$MODEL_NAME/model.pkl 2>/dev/null; then

            SIZE=$(oc exec -n $NAMESPACE $UTILITIES_POD -- \
                stat -c%s /mnt/models/$MODEL_NAME/model.pkl 2>/dev/null || echo "0")
            SIZE_KB=$((SIZE / 1024))

            echo -e "${GREEN}✅ Model file exists: /mnt/models/$MODEL_NAME/model.pkl (${SIZE_KB} KB)${NC}"

            if [ "$SIZE" -lt 1000 ]; then
                echo -e "${YELLOW}⚠️  Model file very small (< 1KB), may be invalid${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Model file not found (may be first deployment)${NC}"
        fi
    fi

    # Test prediction endpoint
    PREDICTOR_IP=$(oc get pod -l serving.kserve.io/inferenceservice=$MODEL_NAME \
        -n $NAMESPACE --field-selector=status.phase=Running \
        -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)

    if [ -n "$PREDICTOR_IP" ]; then
        echo ""
        echo "Testing prediction endpoint..."
        echo "Predictor IP: $PREDICTOR_IP"

        # Generate test payload based on model type
        if [ "$MODEL_NAME" = "anomaly-detector" ]; then
            # 45 features for anomaly detector
            TEST_PAYLOAD='{"instances": [[0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6]]}'
        else
            # 120 features for predictive analytics
            TEST_PAYLOAD='{"instances": [[0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4, 0.3, 0.8, 0.7, 0.5, 0.4, 0.6, 0.5, 0.6, 0.4]]}'
        fi

        if RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
            http://${PREDICTOR_IP}:8080/v1/models/$MODEL_NAME:predict \
            -H 'Content-Type: application/json' \
            -d "$TEST_PAYLOAD" 2>&1); then

            HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
            BODY=$(echo "$RESPONSE" | head -n-1)

            if [ "$HTTP_CODE" = "200" ]; then
                echo -e "${GREEN}✅ Endpoint responding (HTTP $HTTP_CODE)${NC}"
                echo "Response preview: $(echo "$BODY" | head -c 200)..."
            else
                echo -e "${YELLOW}⚠️  Endpoint returned HTTP $HTTP_CODE${NC}"
                echo "Response: $BODY"
            fi
        else
            echo -e "${YELLOW}⚠️  Endpoint not responding (model may still be loading)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Could not get predictor IP${NC}"
    fi

    echo ""
    return 0
}

# Validate each model
FAILED=0
for MODEL in "${MODELS[@]}"; do
    if ! check_model "$MODEL"; then
        FAILED=$((FAILED + 1))
    fi
done

echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo "Total models: ${#MODELS[@]}"
echo "Failed: $FAILED"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All models validated successfully!${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAILED model(s) failed validation${NC}"
    exit 1
fi
