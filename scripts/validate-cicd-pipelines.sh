#!/bin/bash
# CI/CD Pipeline Validation Script
# Validates ADR-027: CI/CD Pipeline Automation
# Usage: ./scripts/validate-cicd-pipelines.sh [--verbose]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITOPS_NAMESPACE=${GITOPS_NAMESPACE:-openshift-gitops}
TEKTON_NAMESPACE=${TEKTON_NAMESPACE:-openshift-pipelines}
APP_NAMESPACE=${APP_NAMESPACE:-self-healing-platform}
VERBOSE=${1:-false}

# Counters
PASSED=0
FAILED=0
WARNINGS=0

echo "========================================="
echo "CI/CD Pipeline Validation"
echo "========================================="
echo "GitOps Namespace: $GITOPS_NAMESPACE"
echo "Tekton Namespace: $TEKTON_NAMESPACE"
echo "Application Namespace: $APP_NAMESPACE"
echo "Date: $(date)"
echo "========================================="
echo ""

# Function to print test result
print_result() {
    local test_name=$1
    local result=$2
    local message=$3

    if [ "$result" == "PASS" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        ((PASSED++))
    elif [ "$result" == "FAIL" ]; then
        echo -e "${RED}❌ FAIL${NC}: $test_name - $message"
        ((FAILED++))
    elif [ "$result" == "WARN" ]; then
        echo -e "${YELLOW}⚠️  WARN${NC}: $test_name - $message"
        ((WARNINGS++))
    fi

    if [ "$VERBOSE" == "--verbose" ] && [ -n "$message" ]; then
        echo "   Details: $message"
    fi
}

# Test 1: ArgoCD Installation
echo "Test 1: ArgoCD Installation"
if oc get deployment argocd-server -n $GITOPS_NAMESPACE &>/dev/null; then
    ARGOCD_READY=$(oc get deployment argocd-server -n $GITOPS_NAMESPACE -o jsonpath='{.status.readyReplicas}')
    if [ "$ARGOCD_READY" -gt 0 ]; then
        print_result "ArgoCD Server" "PASS" "Deployment ready with $ARGOCD_READY replicas"
    else
        print_result "ArgoCD Server" "FAIL" "Deployment not ready"
    fi
else
    print_result "ArgoCD Server" "FAIL" "ArgoCD not installed"
fi

# Check ArgoCD components
ARGOCD_COMPONENTS=("argocd-application-controller" "argocd-repo-server" "argocd-redis")
for component in "${ARGOCD_COMPONENTS[@]}"; do
    if oc get deployment $component -n $GITOPS_NAMESPACE &>/dev/null; then
        READY=$(oc get deployment $component -n $GITOPS_NAMESPACE -o jsonpath='{.status.readyReplicas}')
        if [ "$READY" -gt 0 ]; then
            print_result "  $component" "PASS" "Ready"
        else
            print_result "  $component" "FAIL" "Not ready"
        fi
    else
        print_result "  $component" "FAIL" "Not found"
    fi
done
echo ""

# Test 2: ArgoCD Applications
echo "Test 2: ArgoCD Applications"
if oc get applications -n $GITOPS_NAMESPACE &>/dev/null; then
    APP_COUNT=$(oc get applications -n $GITOPS_NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$APP_COUNT" -gt 0 ]; then
        print_result "ArgoCD Applications" "PASS" "Found $APP_COUNT application(s)"

        # Check application health
        for app in $(oc get applications -n $GITOPS_NAMESPACE -o name); do
            APP_NAME=$(echo $app | cut -d'/' -f2)
            HEALTH=$(oc get application $APP_NAME -n $GITOPS_NAMESPACE -o jsonpath='{.status.health.status}')
            SYNC=$(oc get application $APP_NAME -n $GITOPS_NAMESPACE -o jsonpath='{.status.sync.status}')

            if [ "$HEALTH" == "Healthy" ] && [ "$SYNC" == "Synced" ]; then
                print_result "  App: $APP_NAME" "PASS" "Healthy and Synced"
            elif [ "$HEALTH" == "Progressing" ]; then
                print_result "  App: $APP_NAME" "WARN" "Health: $HEALTH, Sync: $SYNC"
            else
                print_result "  App: $APP_NAME" "FAIL" "Health: $HEALTH, Sync: $SYNC"
            fi
        done
    else
        print_result "ArgoCD Applications" "WARN" "No applications found"
    fi
else
    print_result "ArgoCD Applications" "FAIL" "Cannot access applications"
fi
echo ""

# Test 3: Tekton Pipelines Installation
echo "Test 3: Tekton Pipelines Installation"
if oc get deployment tekton-pipelines-controller -n openshift-pipelines-operator &>/dev/null; then
    TEKTON_READY=$(oc get deployment tekton-pipelines-controller -n openshift-pipelines-operator -o jsonpath='{.status.readyReplicas}')
    if [ "$TEKTON_READY" -gt 0 ]; then
        print_result "Tekton Pipelines Controller" "PASS" "Deployment ready"
    else
        print_result "Tekton Pipelines Controller" "FAIL" "Deployment not ready"
    fi
else
    print_result "Tekton Pipelines Controller" "FAIL" "Tekton not installed"
fi
echo ""

# Test 4: Tekton Pipelines
echo "Test 4: Tekton Pipelines"
if command -v tkn &>/dev/null; then
    PIPELINE_COUNT=$(tkn pipeline list -n $TEKTON_NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$PIPELINE_COUNT" -gt 0 ]; then
        print_result "Tekton Pipelines" "PASS" "Found $PIPELINE_COUNT pipeline(s)"

        # List pipelines
        for pipeline in $(tkn pipeline list -n $TEKTON_NAMESPACE -o name 2>/dev/null); do
            PIPELINE_NAME=$(echo $pipeline | cut -d'/' -f2)
            print_result "  Pipeline: $PIPELINE_NAME" "PASS" "Available"
        done
    else
        print_result "Tekton Pipelines" "WARN" "No pipelines found"
    fi
else
    # Fallback to oc if tkn not available
    if oc get pipeline -n $TEKTON_NAMESPACE &>/dev/null; then
        PIPELINE_COUNT=$(oc get pipeline -n $TEKTON_NAMESPACE --no-headers 2>/dev/null | wc -l)
        if [ "$PIPELINE_COUNT" -gt 0 ]; then
            print_result "Tekton Pipelines" "PASS" "Found $PIPELINE_COUNT pipeline(s)"
        else
            print_result "Tekton Pipelines" "WARN" "No pipelines found"
        fi
    else
        print_result "Tekton Pipelines" "FAIL" "Cannot access pipelines"
    fi
fi
echo ""

# Test 5: Tekton Tasks
echo "Test 5: Tekton Tasks"
if oc get task -n $TEKTON_NAMESPACE &>/dev/null; then
    TASK_COUNT=$(oc get task -n $TEKTON_NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$TASK_COUNT" -gt 0 ]; then
        print_result "Tekton Tasks" "PASS" "Found $TASK_COUNT task(s)"
    else
        print_result "Tekton Tasks" "WARN" "No tasks found"
    fi
else
    print_result "Tekton Tasks" "FAIL" "Cannot access tasks"
fi
echo ""

# Test 6: Tekton Triggers
echo "Test 6: Tekton Triggers"
if oc get eventlistener -n $TEKTON_NAMESPACE &>/dev/null; then
    EL_COUNT=$(oc get eventlistener -n $TEKTON_NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$EL_COUNT" -gt 0 ]; then
        print_result "EventListeners" "PASS" "Found $EL_COUNT EventListener(s)"

        # Check EventListener status
        for el in $(oc get eventlistener -n $TEKTON_NAMESPACE -o name); do
            EL_NAME=$(echo $el | cut -d'/' -f2)
            EL_READY=$(oc get eventlistener $EL_NAME -n $TEKTON_NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
            if [ "$EL_READY" == "True" ]; then
                print_result "  EventListener: $EL_NAME" "PASS" "Ready"
            else
                print_result "  EventListener: $EL_NAME" "FAIL" "Not ready"
            fi
        done
    else
        print_result "EventListeners" "WARN" "No EventListeners found (webhooks not configured)"
    fi
else
    print_result "EventListeners" "WARN" "Tekton Triggers not installed"
fi
echo ""

# Test 7: Recent Pipeline Runs
echo "Test 7: Recent Pipeline Runs"
if command -v tkn &>/dev/null; then
    RECENT_RUNS=$(tkn pipelinerun list -n $TEKTON_NAMESPACE --limit 5 --no-headers 2>/dev/null | wc -l)
    if [ "$RECENT_RUNS" -gt 0 ]; then
        print_result "Recent Pipeline Runs" "PASS" "Found $RECENT_RUNS recent run(s)"

        # Check run status
        for run in $(tkn pipelinerun list -n $TEKTON_NAMESPACE --limit 5 -o name 2>/dev/null); do
            RUN_NAME=$(echo $run | cut -d'/' -f2)
            RUN_STATUS=$(oc get pipelinerun $RUN_NAME -n $TEKTON_NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}')
            RUN_REASON=$(oc get pipelinerun $RUN_NAME -n $TEKTON_NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].reason}')

            if [ "$RUN_STATUS" == "True" ]; then
                print_result "  Run: $RUN_NAME" "PASS" "Succeeded"
            elif [ "$RUN_STATUS" == "False" ]; then
                print_result "  Run: $RUN_NAME" "FAIL" "Failed: $RUN_REASON"
            else
                print_result "  Run: $RUN_NAME" "WARN" "Running or Unknown"
            fi
        done
    else
        print_result "Recent Pipeline Runs" "WARN" "No recent pipeline runs"
    fi
else
    print_result "Recent Pipeline Runs" "WARN" "tkn CLI not available"
fi
echo ""

# Test 8: GitOps Sync Policy
echo "Test 8: GitOps Sync Policy"
for app in $(oc get applications -n $GITOPS_NAMESPACE -o name 2>/dev/null); do
    APP_NAME=$(echo $app | cut -d'/' -f2)
    AUTO_SYNC=$(oc get application $APP_NAME -n $GITOPS_NAMESPACE -o jsonpath='{.spec.syncPolicy.automated}')

    if [ -n "$AUTO_SYNC" ]; then
        PRUNE=$(echo $AUTO_SYNC | jq -r '.prune' 2>/dev/null || echo "false")
        SELF_HEAL=$(echo $AUTO_SYNC | jq -r '.selfHeal' 2>/dev/null || echo "false")

        if [ "$PRUNE" == "true" ] && [ "$SELF_HEAL" == "true" ]; then
            print_result "  Sync Policy: $APP_NAME" "PASS" "Automated with prune and self-heal"
        else
            print_result "  Sync Policy: $APP_NAME" "WARN" "Automated but missing prune or self-heal"
        fi
    else
        print_result "  Sync Policy: $APP_NAME" "WARN" "Manual sync (not automated)"
    fi
done
echo ""

# Test 9: CI/CD Observability
echo "Test 9: CI/CD Observability"
# Check if Tekton Dashboard is available
if oc get route tekton-dashboard -n $TEKTON_NAMESPACE &>/dev/null; then
    print_result "Tekton Dashboard" "PASS" "Dashboard route available"
else
    print_result "Tekton Dashboard" "WARN" "Dashboard not deployed"
fi

# Check if ArgoCD UI is available
if oc get route argocd-server -n $GITOPS_NAMESPACE &>/dev/null; then
    print_result "ArgoCD UI" "PASS" "ArgoCD UI route available"
else
    print_result "ArgoCD UI" "FAIL" "ArgoCD UI not accessible"
fi
echo ""

# Test 10: Service Accounts and RBAC
echo "Test 10: Service Accounts and RBAC"
# Check Tekton service accounts
TEKTON_SA="pipeline"
if oc get sa $TEKTON_SA -n $TEKTON_NAMESPACE &>/dev/null; then
    print_result "Service Account: $TEKTON_SA" "PASS" "Service account exists"
else
    print_result "Service Account: $TEKTON_SA" "FAIL" "Service account not found"
fi

# Check ArgoCD service accounts
ARGOCD_SA="argocd-application-controller"
if oc get sa $ARGOCD_SA -n $GITOPS_NAMESPACE &>/dev/null; then
    print_result "Service Account: $ARGOCD_SA" "PASS" "Service account exists"
else
    print_result "Service Account: $ARGOCD_SA" "FAIL" "Service account not found"
fi
echo ""

# Summary
echo "========================================="
echo "Validation Summary"
echo "========================================="
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC} $FAILED"
echo "========================================="
echo ""

# Recommendations
if [ "$FAILED" -gt 0 ] || [ "$WARNINGS" -gt 0 ]; then
    echo -e "${BLUE}Recommendations:${NC}"

    if [ "$FAILED" -gt 0 ]; then
        echo "1. Review failed tests and remediate critical issues"
        echo "2. Check operator logs: oc logs -n openshift-gitops-operator -l name=openshift-gitops-operator"
        echo "3. Check Tekton logs: oc logs -n openshift-pipelines-operator -l name=openshift-pipelines-operator"
    fi

    if [ "$WARNINGS" -gt 0 ]; then
        echo "4. Consider deploying Tekton Triggers for webhook automation"
        echo "5. Enable automated sync policies for ArgoCD applications"
        echo "6. Deploy Tekton Dashboard for better observability"
    fi
    echo ""
fi

# Exit code
if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}❌ Validation FAILED${NC}"
    echo "Please review failed tests and remediate issues."
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Validation PASSED with warnings${NC}"
    echo "Review warnings for potential improvements."
    exit 0
else
    echo -e "${GREEN}✅ Validation PASSED${NC}"
    echo "All CI/CD pipeline checks passed successfully."
    exit 0
fi
