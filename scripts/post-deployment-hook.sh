#!/bin/bash
# Post-Deployment Hook
# Automatically runs validation after Pattern deployment

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_SCRIPT="${SCRIPT_DIR}/post-deployment-validation.sh"

echo "========================================"
echo "Running Post-Deployment Validation"
echo "========================================"
echo ""

# Check if validation script exists
if [ ! -f "$VALIDATION_SCRIPT" ]; then
    echo "ERROR: Validation script not found at $VALIDATION_SCRIPT"
    exit 1
fi

# Make sure it's executable
chmod +x "$VALIDATION_SCRIPT"

# Run validation and capture results
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="validation-report-${TIMESTAMP}.txt"

echo "Running validation (report will be saved to ${REPORT_FILE})..."
echo ""

if "$VALIDATION_SCRIPT" 2>&1 | tee "$REPORT_FILE"; then
    echo ""
    echo "✅ Validation completed successfully"
    echo "📄 Full report: ${REPORT_FILE}"
    exit 0
else
    EXIT_CODE=$?
    echo ""
    echo "⚠️  Validation completed with issues (exit code: ${EXIT_CODE})"
    echo "📄 Full report: ${REPORT_FILE}"
    echo ""
    echo "Review the report above for detailed diagnostics and recommendations."
    exit $EXIT_CODE
fi
