#!/bin/bash
# Gitea Deployment Validation Script
# Validates ADR-028: Gitea Local Git Repository
# Usage: ./scripts/validate-gitea-deployment.sh [--verbose]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITEA_NAMESPACE=${GITEA_NAMESPACE:-gitea}
GITEA_OPERATOR_NAMESPACE=${GITEA_OPERATOR_NAMESPACE:-gitea-operator}
VERBOSE=${1:-false}

# Counters
PASSED=0
FAILED=0
WARNINGS=0

echo "========================================="
echo "Gitea Deployment Validation"
echo "========================================="
echo "Gitea Namespace: $GITEA_NAMESPACE"
echo "Operator Namespace: $GITEA_OPERATOR_NAMESPACE"
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

# Test 1: Gitea Operator Installation
echo "Test 1: Gitea Operator Installation"
if oc get namespace $GITEA_OPERATOR_NAMESPACE &>/dev/null; then
    print_result "Gitea Operator Namespace" "PASS" "Namespace exists"

    # Check operator deployment
    if oc get deployment -n $GITEA_OPERATOR_NAMESPACE | grep -q "gitea-operator-controller-manager"; then
        OPERATOR_READY=$(oc get deployment -n $GITEA_OPERATOR_NAMESPACE -l control-plane=controller-manager -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null || echo "0")
        if [ "$OPERATOR_READY" -gt 0 ]; then
            print_result "Gitea Operator Deployment" "PASS" "Operator ready with $OPERATOR_READY replicas"
        else
            print_result "Gitea Operator Deployment" "FAIL" "Operator not ready"
        fi
    else
        print_result "Gitea Operator Deployment" "FAIL" "Operator deployment not found"
    fi
else
    print_result "Gitea Operator Namespace" "FAIL" "Namespace not found"
fi
echo ""

# Test 2: Gitea Namespace and Resources
echo "Test 2: Gitea Namespace and Resources"
if oc get namespace $GITEA_NAMESPACE &>/dev/null; then
    print_result "Gitea Namespace" "PASS" "Namespace exists"

    # Check Gitea CR
    if oc get gitea -n $GITEA_NAMESPACE &>/dev/null; then
        GITEA_COUNT=$(oc get gitea -n $GITEA_NAMESPACE --no-headers 2>/dev/null | wc -l)
        print_result "Gitea Custom Resource" "PASS" "Found $GITEA_COUNT Gitea instance(s)"

        # Check Gitea status
        for gitea in $(oc get gitea -n $GITEA_NAMESPACE -o name); do
            GITEA_NAME=$(echo $gitea | cut -d'/' -f2)
            GITEA_STATUS=$(oc get gitea $GITEA_NAME -n $GITEA_NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Running")].status}' 2>/dev/null || echo "Unknown")
            if [ "$GITEA_STATUS" == "True" ]; then
                print_result "  Gitea: $GITEA_NAME" "PASS" "Running"
            else
                print_result "  Gitea: $GITEA_NAME" "WARN" "Status: $GITEA_STATUS (may still be deploying)"
            fi
        done
    else
        print_result "Gitea Custom Resource" "FAIL" "No Gitea instances found"
    fi
else
    print_result "Gitea Namespace" "FAIL" "Namespace not found"
fi
echo ""

# Test 3: Gitea Pods
echo "Test 3: Gitea Pods"
if oc get pods -n $GITEA_NAMESPACE &>/dev/null; then
    POD_COUNT=$(oc get pods -n $GITEA_NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$POD_COUNT" -gt 0 ]; then
        print_result "Gitea Pods" "PASS" "Found $POD_COUNT pod(s)"

        # Check pod status
        RUNNING_PODS=$(oc get pods -n $GITEA_NAMESPACE --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        if [ "$RUNNING_PODS" -eq "$POD_COUNT" ]; then
            print_result "  Pod Status" "PASS" "All $RUNNING_PODS pods running"
        else
            print_result "  Pod Status" "WARN" "$RUNNING_PODS/$POD_COUNT pods running"
        fi

        # List pods
        if [ "$VERBOSE" == "--verbose" ]; then
            echo "   Pod Details:"
            oc get pods -n $GITEA_NAMESPACE -o wide | sed 's/^/   /'
        fi
    else
        print_result "Gitea Pods" "FAIL" "No pods found"
    fi
else
    print_result "Gitea Pods" "FAIL" "Cannot access pods"
fi
echo ""

# Test 4: PostgreSQL Database
echo "Test 4: PostgreSQL Database"
if oc get pods -n $GITEA_NAMESPACE -l app=postgresql 2>/dev/null | grep -q "Running"; then
    print_result "PostgreSQL Pod" "PASS" "Database pod running"

    # Check PostgreSQL service
    if oc get service -n $GITEA_NAMESPACE | grep -q "postgresql"; then
        print_result "PostgreSQL Service" "PASS" "Database service exists"
    else
        print_result "PostgreSQL Service" "WARN" "Database service not found"
    fi
else
    print_result "PostgreSQL Pod" "WARN" "Database pod not running (may still be deploying)"
fi
echo ""

# Test 5: Gitea Route
echo "Test 5: Gitea Route"
if oc get route -n $GITEA_NAMESPACE &>/dev/null; then
    ROUTE_COUNT=$(oc get route -n $GITEA_NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$ROUTE_COUNT" -gt 0 ]; then
        print_result "Gitea Route" "PASS" "Found $ROUTE_COUNT route(s)"

        # Get route URL
        GITEA_ROUTE=$(oc get route -n $GITEA_NAMESPACE -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")
        if [ -n "$GITEA_ROUTE" ]; then
            GITEA_URL="https://$GITEA_ROUTE"
            print_result "  Route URL" "PASS" "$GITEA_URL"

            # Test route accessibility
            if curl -k -s -o /dev/null -w "%{http_code}" "$GITEA_URL" | grep -q "200\|302"; then
                print_result "  Route Accessibility" "PASS" "Route is accessible"
            else
                print_result "  Route Accessibility" "WARN" "Route may not be ready yet"
            fi
        else
            print_result "  Route URL" "FAIL" "Cannot determine route URL"
        fi
    else
        print_result "Gitea Route" "WARN" "No routes found (may still be creating)"
    fi
else
    print_result "Gitea Route" "FAIL" "Cannot access routes"
fi
echo ""

# Test 6: Gitea API
echo "Test 6: Gitea API"
if [ -n "$GITEA_ROUTE" ]; then
    API_URL="https://$GITEA_ROUTE/api/v1/version"
    API_RESPONSE=$(curl -k -s "$API_URL" 2>/dev/null || echo "")

    if echo "$API_RESPONSE" | grep -q "version"; then
        GITEA_VERSION=$(echo "$API_RESPONSE" | jq -r '.version' 2>/dev/null || echo "unknown")
        print_result "Gitea API" "PASS" "API accessible (version: $GITEA_VERSION)"
    else
        print_result "Gitea API" "WARN" "API not yet accessible (Gitea may still be starting)"
    fi
else
    print_result "Gitea API" "WARN" "Cannot test API (route not available)"
fi
echo ""

# Test 7: Admin Credentials
echo "Test 7: Admin Credentials"
ADMIN_SECRET=$(oc get secret -n $GITEA_NAMESPACE -o name 2>/dev/null | grep "admin-credentials" | head -1)
if [ -n "$ADMIN_SECRET" ]; then
    SECRET_NAME=$(echo $ADMIN_SECRET | cut -d'/' -f2)
    print_result "Admin Credentials Secret" "PASS" "Secret: $SECRET_NAME"

    # Extract credentials
    ADMIN_USER=$(oc get secret $SECRET_NAME -n $GITEA_NAMESPACE -o jsonpath='{.data.username}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
    ADMIN_PASSWORD=$(oc get secret $SECRET_NAME -n $GITEA_NAMESPACE -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

    if [ -n "$ADMIN_USER" ] && [ -n "$ADMIN_PASSWORD" ]; then
        print_result "  Credentials Extraction" "PASS" "Username: $ADMIN_USER"
        echo -e "   ${BLUE}ℹ️  Admin Password:${NC} $ADMIN_PASSWORD"
    else
        print_result "  Credentials Extraction" "WARN" "Cannot extract credentials"
    fi
else
    print_result "Admin Credentials Secret" "WARN" "Admin credentials not yet created"
fi
echo ""

# Test 8: User Credentials
echo "Test 8: User Credentials"
USER_SECRET=$(oc get secret -n $GITEA_NAMESPACE -o name 2>/dev/null | grep "user-credentials" | head -1)
if [ -n "$USER_SECRET" ]; then
    SECRET_NAME=$(echo $USER_SECRET | cut -d'/' -f2)
    print_result "User Credentials Secret" "PASS" "Secret: $SECRET_NAME"

    # Extract user credentials
    USER_NAME=$(oc get secret $SECRET_NAME -n $GITEA_NAMESPACE -o jsonpath='{.data.username}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
    USER_PASSWORD=$(oc get secret $SECRET_NAME -n $GITEA_NAMESPACE -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

    if [ -n "$USER_NAME" ] && [ -n "$USER_PASSWORD" ]; then
        print_result "  User Credentials" "PASS" "Username: $USER_NAME"
        echo -e "   ${BLUE}ℹ️  User Password:${NC} $USER_PASSWORD"
    else
        print_result "  User Credentials" "WARN" "Cannot extract user credentials"
    fi
else
    print_result "User Credentials Secret" "WARN" "User credentials not yet created"
fi
echo ""

# Test 9: Persistent Storage
echo "Test 9: Persistent Storage"
if oc get pvc -n $GITEA_NAMESPACE &>/dev/null; then
    PVC_COUNT=$(oc get pvc -n $GITEA_NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$PVC_COUNT" -gt 0 ]; then
        print_result "Persistent Volume Claims" "PASS" "Found $PVC_COUNT PVC(s)"

        # Check PVC status
        for pvc in $(oc get pvc -n $GITEA_NAMESPACE -o name); do
            PVC_NAME=$(echo $pvc | cut -d'/' -f2)
            PVC_STATUS=$(oc get pvc $PVC_NAME -n $GITEA_NAMESPACE -o jsonpath='{.status.phase}')
            PVC_SIZE=$(oc get pvc $PVC_NAME -n $GITEA_NAMESPACE -o jsonpath='{.spec.resources.requests.storage}')

            if [ "$PVC_STATUS" == "Bound" ]; then
                print_result "  PVC: $PVC_NAME" "PASS" "Bound ($PVC_SIZE)"
            else
                print_result "  PVC: $PVC_NAME" "WARN" "Status: $PVC_STATUS"
            fi
        done
    else
        print_result "Persistent Volume Claims" "WARN" "No PVCs found"
    fi
else
    print_result "Persistent Volume Claims" "FAIL" "Cannot access PVCs"
fi
echo ""

# Test 10: Service Accounts and RBAC
echo "Test 10: Service Accounts and RBAC"
if oc get sa -n $GITEA_NAMESPACE &>/dev/null; then
    SA_COUNT=$(oc get sa -n $GITEA_NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$SA_COUNT" -gt 0 ]; then
        print_result "Service Accounts" "PASS" "Found $SA_COUNT service account(s)"
    else
        print_result "Service Accounts" "WARN" "No service accounts found"
    fi
else
    print_result "Service Accounts" "FAIL" "Cannot access service accounts"
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

# Access Information
if [ -n "$GITEA_ROUTE" ] && [ -n "$ADMIN_USER" ]; then
    echo -e "${BLUE}📋 Gitea Access Information:${NC}"
    echo "   URL: https://$GITEA_ROUTE"
    echo "   Admin Username: $ADMIN_USER"
    echo "   Admin Password: $ADMIN_PASSWORD"
    if [ -n "$USER_NAME" ]; then
        echo "   User Username: $USER_NAME"
        echo "   User Password: $USER_PASSWORD"
    fi
    echo ""
fi

# Recommendations
if [ "$FAILED" -gt 0 ] || [ "$WARNINGS" -gt 0 ]; then
    echo -e "${BLUE}Recommendations:${NC}"

    if [ "$WARNINGS" -gt 0 ]; then
        echo "1. Gitea may still be deploying. Wait 2-3 minutes and re-run validation"
        echo "2. Check operator logs: oc logs -n $GITEA_OPERATOR_NAMESPACE -l control-plane=controller-manager"
        echo "3. Check Gitea pod logs: oc logs -n $GITEA_NAMESPACE -l app=gitea"
    fi

    if [ "$FAILED" -gt 0 ]; then
        echo "4. Review failed tests and check pod events: oc get events -n $GITEA_NAMESPACE"
        echo "5. Verify operator installation: oc get csv -n $GITEA_OPERATOR_NAMESPACE"
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
    echo "Gitea may still be deploying. Re-run validation in a few minutes."
    exit 0
else
    echo -e "${GREEN}✅ Validation PASSED${NC}"
    echo "Gitea is fully deployed and operational!"
    exit 0
fi
