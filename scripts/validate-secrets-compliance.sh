#!/bin/bash
# Secrets Compliance Validation Script
# Validates ADR-026: Secrets Management Automation
# Usage: ./scripts/validate-secrets-compliance.sh [--compliance-standard pci-dss|hipaa|soc2]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE=${NAMESPACE:-self-healing-platform}
COMPLIANCE_STANDARD=${1:-pci-dss}
VERBOSE=${VERBOSE:-false}

# Counters
PASSED=0
FAILED=0
WARNINGS=0

echo "========================================="
echo "Secrets Compliance Validation"
echo "========================================="
echo "Namespace: $NAMESPACE"
echo "Compliance Standard: $COMPLIANCE_STANDARD"
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

    if [ "$VERBOSE" == "true" ] && [ -n "$message" ]; then
        echo "   Details: $message"
    fi
}

# Test 1: External Secrets Operator Installation
echo "Test 1: External Secrets Operator Installation"
if oc get deployment external-secrets -n external-secrets-operator &>/dev/null; then
    ESO_READY=$(oc get deployment external-secrets -n external-secrets-operator -o jsonpath='{.status.readyReplicas}')
    if [ "$ESO_READY" -gt 0 ]; then
        print_result "External Secrets Operator" "PASS" "Deployment ready with $ESO_READY replicas"
    else
        print_result "External Secrets Operator" "FAIL" "Deployment not ready"
    fi
else
    print_result "External Secrets Operator" "FAIL" "Operator not installed"
fi
echo ""

# Test 2: SecretStore Configuration
echo "Test 2: SecretStore Configuration"
if oc get secretstore -n $NAMESPACE &>/dev/null; then
    SECRETSTORE_COUNT=$(oc get secretstore -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$SECRETSTORE_COUNT" -gt 0 ]; then
        print_result "SecretStore Configuration" "PASS" "Found $SECRETSTORE_COUNT SecretStore(s)"

        # Validate SecretStore status
        for store in $(oc get secretstore -n $NAMESPACE -o name); do
            STORE_NAME=$(echo $store | cut -d'/' -f2)
            STORE_STATUS=$(oc get secretstore $STORE_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
            if [ "$STORE_STATUS" == "True" ]; then
                print_result "  SecretStore: $STORE_NAME" "PASS" "Ready"
            else
                print_result "  SecretStore: $STORE_NAME" "FAIL" "Not ready"
            fi
        done
    else
        print_result "SecretStore Configuration" "FAIL" "No SecretStores found"
    fi
else
    print_result "SecretStore Configuration" "FAIL" "SecretStore CRD not available"
fi
echo ""

# Test 3: ExternalSecret Resources
echo "Test 3: ExternalSecret Resources"
if oc get externalsecret -n $NAMESPACE &>/dev/null; then
    EXTERNALSECRET_COUNT=$(oc get externalsecret -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$EXTERNALSECRET_COUNT" -gt 0 ]; then
        print_result "ExternalSecret Resources" "PASS" "Found $EXTERNALSECRET_COUNT ExternalSecret(s)"

        # Validate ExternalSecret sync status
        for es in $(oc get externalsecret -n $NAMESPACE -o name); do
            ES_NAME=$(echo $es | cut -d'/' -f2)
            ES_STATUS=$(oc get externalsecret $ES_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
            ES_REFRESH=$(oc get externalsecret $ES_NAME -n $NAMESPACE -o jsonpath='{.status.refreshTime}')

            if [ "$ES_STATUS" == "True" ]; then
                print_result "  ExternalSecret: $ES_NAME" "PASS" "Synced at $ES_REFRESH"
            else
                print_result "  ExternalSecret: $ES_NAME" "FAIL" "Not synced"
            fi
        done
    else
        print_result "ExternalSecret Resources" "WARN" "No ExternalSecrets found (may be intentional)"
    fi
else
    print_result "ExternalSecret Resources" "FAIL" "ExternalSecret CRD not available"
fi
echo ""

# Test 4: Secret Rotation Configuration
echo "Test 4: Secret Rotation Configuration"
if oc get externalsecret -n $NAMESPACE &>/dev/null; then
    for es in $(oc get externalsecret -n $NAMESPACE -o name); do
        ES_NAME=$(echo $es | cut -d'/' -f2)
        REFRESH_INTERVAL=$(oc get externalsecret $ES_NAME -n $NAMESPACE -o jsonpath='{.spec.refreshInterval}')

        if [ -n "$REFRESH_INTERVAL" ]; then
            # Check if refresh interval is reasonable (not more than 24h)
            if [[ "$REFRESH_INTERVAL" =~ ^[0-9]+h$ ]]; then
                HOURS=$(echo $REFRESH_INTERVAL | sed 's/h//')
                if [ "$HOURS" -le 24 ]; then
                    print_result "  Rotation: $ES_NAME" "PASS" "Refresh interval: $REFRESH_INTERVAL"
                else
                    print_result "  Rotation: $ES_NAME" "WARN" "Refresh interval too long: $REFRESH_INTERVAL"
                fi
            else
                print_result "  Rotation: $ES_NAME" "PASS" "Refresh interval: $REFRESH_INTERVAL"
            fi
        else
            print_result "  Rotation: $ES_NAME" "WARN" "No refresh interval configured"
        fi
    done
else
    print_result "Secret Rotation Configuration" "FAIL" "Cannot validate rotation"
fi
echo ""

# Test 5: Secret Encryption at Rest
echo "Test 5: Secret Encryption at Rest"
# Check if secrets are encrypted (OpenShift encrypts secrets by default)
ETCD_ENCRYPTION=$(oc get apiserver cluster -o jsonpath='{.spec.encryption.type}' 2>/dev/null || echo "unknown")
if [ "$ETCD_ENCRYPTION" == "aescbc" ] || [ "$ETCD_ENCRYPTION" == "aesgcm" ]; then
    print_result "Secret Encryption at Rest" "PASS" "Encryption type: $ETCD_ENCRYPTION"
elif [ "$ETCD_ENCRYPTION" == "identity" ]; then
    print_result "Secret Encryption at Rest" "FAIL" "Encryption disabled (identity)"
else
    print_result "Secret Encryption at Rest" "WARN" "Cannot determine encryption status"
fi
echo ""

# Test 6: RBAC for Secret Access
echo "Test 6: RBAC for Secret Access"
# Check if service account has proper RBAC
SA_NAME="external-secrets-sa"
if oc get sa $SA_NAME -n $NAMESPACE &>/dev/null; then
    print_result "Service Account: $SA_NAME" "PASS" "Service account exists"

    # Check role bindings
    ROLEBINDINGS=$(oc get rolebinding -n $NAMESPACE -o json | jq -r ".items[] | select(.subjects[]?.name==\"$SA_NAME\") | .metadata.name")
    if [ -n "$ROLEBINDINGS" ]; then
        print_result "  RBAC Bindings" "PASS" "Found role bindings for $SA_NAME"
    else
        print_result "  RBAC Bindings" "WARN" "No role bindings found for $SA_NAME"
    fi
else
    print_result "Service Account: $SA_NAME" "FAIL" "Service account not found"
fi
echo ""

# Test 7: Audit Logging
echo "Test 7: Audit Logging"
# Check if ESO has audit logging enabled
ESO_LOGS=$(oc logs -n external-secrets-operator -l app=external-secrets --tail=10 2>/dev/null || echo "")
if [ -n "$ESO_LOGS" ]; then
    print_result "Audit Logging" "PASS" "ESO logs available"

    # Check for recent secret sync events
    SYNC_EVENTS=$(echo "$ESO_LOGS" | grep -i "secret" | wc -l)
    if [ "$SYNC_EVENTS" -gt 0 ]; then
        print_result "  Secret Sync Events" "PASS" "Found $SYNC_EVENTS recent events"
    else
        print_result "  Secret Sync Events" "WARN" "No recent secret sync events"
    fi
else
    print_result "Audit Logging" "FAIL" "Cannot access ESO logs"
fi
echo ""

# Test 8: Compliance-Specific Checks
echo "Test 8: Compliance-Specific Checks ($COMPLIANCE_STANDARD)"
case $COMPLIANCE_STANDARD in
    pci-dss)
        # PCI-DSS requires encryption, access control, and audit logging
        if [ "$ETCD_ENCRYPTION" != "identity" ] && [ "$EXTERNALSECRET_COUNT" -gt 0 ]; then
            print_result "PCI-DSS Compliance" "PASS" "Encryption and secret management configured"
        else
            print_result "PCI-DSS Compliance" "FAIL" "Missing encryption or secret management"
        fi
        ;;
    hipaa)
        # HIPAA requires encryption, access control, and audit trails
        if [ "$ETCD_ENCRYPTION" != "identity" ] && [ -n "$ESO_LOGS" ]; then
            print_result "HIPAA Compliance" "PASS" "Encryption and audit logging configured"
        else
            print_result "HIPAA Compliance" "FAIL" "Missing encryption or audit logging"
        fi
        ;;
    soc2)
        # SOC2 requires access control, monitoring, and change management
        if [ "$EXTERNALSECRET_COUNT" -gt 0 ] && [ -n "$ROLEBINDINGS" ]; then
            print_result "SOC2 Compliance" "PASS" "Access control and monitoring configured"
        else
            print_result "SOC2 Compliance" "FAIL" "Missing access control or monitoring"
        fi
        ;;
    *)
        print_result "Compliance Check" "WARN" "Unknown compliance standard: $COMPLIANCE_STANDARD"
        ;;
esac
echo ""

# Test 9: Secret Backend Connectivity
echo "Test 9: Secret Backend Connectivity"
# Test connectivity to secret backend (Kubernetes API)
if oc auth can-i get secrets -n $NAMESPACE &>/dev/null; then
    print_result "Backend Connectivity" "PASS" "Can access Kubernetes secrets API"
else
    print_result "Backend Connectivity" "FAIL" "Cannot access Kubernetes secrets API"
fi
echo ""

# Test 10: Secret Validation
echo "Test 10: Secret Validation"
# Check if critical secrets exist
CRITICAL_SECRETS=("model-storage-config" "git-credentials")
for secret in "${CRITICAL_SECRETS[@]}"; do
    if oc get secret $secret -n $NAMESPACE &>/dev/null; then
        # Check if secret has data
        SECRET_KEYS=$(oc get secret $secret -n $NAMESPACE -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || echo "")
        if [ -n "$SECRET_KEYS" ]; then
            KEY_COUNT=$(echo "$SECRET_KEYS" | wc -l)
            print_result "  Secret: $secret" "PASS" "Contains $KEY_COUNT key(s)"
        else
            print_result "  Secret: $secret" "WARN" "Secret exists but may be empty"
        fi
    else
        print_result "  Secret: $secret" "WARN" "Secret not found (may not be required)"
    fi
done
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
    echo "All secrets compliance checks passed successfully."
    exit 0
fi
