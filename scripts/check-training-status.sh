#!/bin/bash
# Check the status of model training jobs and pipelines

set -e

NAMESPACE="${NAMESPACE:-self-healing-platform}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Model Training Status Report"
echo "Namespace: $NAMESPACE"
echo "=========================================="

# Check if Tekton CLI is available
if ! command -v tkn &> /dev/null; then
    echo -e "${YELLOW}⚠️  Tekton CLI (tkn) not found. Using oc commands only.${NC}"
    USE_TKN=false
else
    USE_TKN=true
fi

# Check recent PipelineRuns
echo ""
echo -e "${BLUE}Recent Pipeline Runs (last 5):${NC}"
echo ""

if [ "$USE_TKN" = true ]; then
    tkn pipelinerun list -n $NAMESPACE -o wide | head -n 6
else
    oc get pipelineruns -n $NAMESPACE \
        --sort-by=.metadata.creationTimestamp \
        -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[0].reason,STARTED:.metadata.creationTimestamp \
        | tail -n 6
fi

# Check anomaly-detector training
echo ""
echo "=========================================="
echo -e "${BLUE}Anomaly Detector Training${NC}"
echo "=========================================="

LATEST_AD=$(oc get pipelineruns -n $NAMESPACE -l model-name=anomaly-detector \
    --sort-by=.metadata.creationTimestamp -o name 2>/dev/null | tail -1)

if [ -z "$LATEST_AD" ]; then
    echo -e "${YELLOW}⚠️  No training runs found for anomaly-detector${NC}"
else
    echo "Latest run: $(basename $LATEST_AD)"

    if [ "$USE_TKN" = true ]; then
        tkn pipelinerun describe $(basename $LATEST_AD) -n $NAMESPACE
    else
        oc get $(basename $LATEST_AD) -n $NAMESPACE -o yaml | grep -A 5 "status:"
    fi

    # Check for failures
    FAILED=$(oc get $LATEST_AD -n $NAMESPACE \
        -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)

    if [ "$FAILED" = "False" ]; then
        echo ""
        echo -e "${RED}❌ Latest training failed${NC}"
        echo ""
        echo "View logs with: tkn pipelinerun logs $(basename $LATEST_AD) -n $NAMESPACE"
    elif [ "$FAILED" = "True" ]; then
        echo ""
        echo -e "${GREEN}✅ Latest training succeeded${NC}"
    else
        echo ""
        echo -e "${YELLOW}⏳ Training in progress or unknown status${NC}"
    fi
fi

# Check predictive-analytics training
echo ""
echo "=========================================="
echo -e "${BLUE}Predictive Analytics Training${NC}"
echo "=========================================="

LATEST_PA=$(oc get pipelineruns -n $NAMESPACE -l model-name=predictive-analytics \
    --sort-by=.metadata.creationTimestamp -o name 2>/dev/null | tail -1)

if [ -z "$LATEST_PA" ]; then
    echo -e "${YELLOW}⚠️  No training runs found for predictive-analytics${NC}"
else
    echo "Latest run: $(basename $LATEST_PA)"

    if [ "$USE_TKN" = true ]; then
        tkn pipelinerun describe $(basename $LATEST_PA) -n $NAMESPACE
    else
        oc get $(basename $LATEST_PA) -n $NAMESPACE -o yaml | grep -A 5 "status:"
    fi

    # Check for failures
    FAILED=$(oc get $LATEST_PA -n $NAMESPACE \
        -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)

    if [ "$FAILED" = "False" ]; then
        echo ""
        echo -e "${RED}❌ Latest training failed${NC}"
        echo ""
        echo "View logs with: tkn pipelinerun logs $(basename $LATEST_PA) -n $NAMESPACE"
    elif [ "$FAILED" = "True" ]; then
        echo ""
        echo -e "${GREEN}✅ Latest training succeeded${NC}"
    else
        echo ""
        echo -e "${YELLOW}⏳ Training in progress or unknown status${NC}"
    fi
fi

# Check NotebookValidationJobs
echo ""
echo "=========================================="
echo -e "${BLUE}Recent Notebook Validation Jobs:${NC}"
echo "=========================================="

oc get notebookvalidationjobs -n $NAMESPACE \
    --sort-by=.metadata.creationTimestamp \
    -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CREATED:.metadata.creationTimestamp \
    2>/dev/null | tail -n 6 || echo -e "${YELLOW}No NotebookValidationJobs found${NC}"

# Check CronJobs
echo ""
echo "=========================================="
echo -e "${BLUE}Scheduled Training CronJobs:${NC}"
echo "=========================================="

oc get cronjobs -n $NAMESPACE -l app.kubernetes.io/part-of=model-training \
    -o custom-columns=NAME:.metadata.name,SCHEDULE:.spec.schedule,SUSPEND:.spec.suspend,ACTIVE:.status.active,LAST-SCHEDULE:.status.lastScheduleTime \
    2>/dev/null || echo -e "${YELLOW}No training CronJobs found${NC}"

# Summary
echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="

TOTAL_RUNS=$(oc get pipelineruns -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
SUCCEEDED_RUNS=$(oc get pipelineruns -n $NAMESPACE \
    -o jsonpath='{.items[?(@.status.conditions[0].reason=="Succeeded")].metadata.name}' 2>/dev/null | wc -w)
FAILED_RUNS=$(oc get pipelineruns -n $NAMESPACE \
    -o jsonpath='{.items[?(@.status.conditions[0].reason=="Failed")].metadata.name}' 2>/dev/null | wc -w)
RUNNING_RUNS=$(oc get pipelineruns -n $NAMESPACE \
    -o jsonpath='{.items[?(@.status.conditions[0].reason=="Running")].metadata.name}' 2>/dev/null | wc -w)

echo "Total pipeline runs: $TOTAL_RUNS"
echo -e "  ${GREEN}Succeeded: $SUCCEEDED_RUNS${NC}"
echo -e "  ${RED}Failed: $FAILED_RUNS${NC}"
echo -e "  ${YELLOW}Running: $RUNNING_RUNS${NC}"

echo ""
echo "Useful commands:"
echo "  List all runs:       tkn pipelinerun list -n $NAMESPACE"
echo "  View run logs:       tkn pipelinerun logs <name> -f -n $NAMESPACE"
echo "  Trigger training:    ./scripts/trigger-model-training.sh <model-name> [hours]"
echo "  Validate models:     ./scripts/validate-models.sh"
