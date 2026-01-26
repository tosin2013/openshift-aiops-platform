#!/bin/bash
# ADR Implementation Verifier
# Verifies specific ADR implementation with code evidence

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <ADR_NUMBER> [--detailed]"
  echo "Example: $0 4"
  echo "Example: $0 36 --detailed"
  exit 1
fi

ADR_NUM=$(printf "%03d" "$1")
DETAILED=false
if [ $# -eq 2 ] && [ "$2" == "--detailed" ]; then
  DETAILED=true
fi

ADR_DIR="/home/lab-user/openshift-aiops-platform/docs/adrs"
PROJECT_ROOT="/home/lab-user/openshift-aiops-platform"
ADR_FILE=$(ls "$ADR_DIR"/${ADR_NUM}-*.md 2>/dev/null | head -n 1)

if [ ! -f "$ADR_FILE" ]; then
  echo "❌ Error: ADR-$ADR_NUM not found"
  exit 1
fi

ADR_TITLE=$(basename "$ADR_FILE" .md | sed 's/^[0-9]\{3\}-//')

echo "========================================"
echo "ADR-$ADR_NUM Implementation Verification"
echo "========================================"
echo "Title: $ADR_TITLE"
echo "File: $ADR_FILE"
echo ""

# Extract status from ADR
echo "## Current ADR Status"
grep -A 3 "^## Status\|^\*\*Status\*\*" "$ADR_FILE" | head -n 5 || echo "Status not found in ADR"
echo ""

# Search for implementation evidence in codebase
echo "## Implementation Evidence Search"
echo ""

# Extract key terms from ADR title for searching
search_terms=$(echo "$ADR_TITLE" | tr '[:upper:]' '[:lower:]' | tr '-' ' ')

echo "### Code References"
cd "$PROJECT_ROOT"

# Search in Helm charts
echo "Searching Helm charts..."
chart_matches=$(grep -r -i "$search_terms" charts/ --include="*.yaml" --include="*.yml" -l 2>/dev/null | wc -l || echo 0)
echo "  Found $chart_matches chart file(s) with potential references"

if [ "$DETAILED" = true ] && [ "$chart_matches" -gt 0 ]; then
  grep -r -i "$search_terms" charts/ --include="*.yaml" --include="*.yml" -l 2>/dev/null | head -n 5
fi

# Search in scripts
echo "Searching scripts..."
script_matches=$(grep -r -i "$search_terms" scripts/ --include="*.sh" --include="*.py" -l 2>/dev/null | wc -l || echo 0)
echo "  Found $script_matches script(s) with potential references"

if [ "$DETAILED" = true ] && [ "$script_matches" -gt 0 ]; then
  grep -r -i "$search_terms" scripts/ --include="*.sh" --include="*.py" -l 2>/dev/null | head -n 5
fi

# Search in notebooks
echo "Searching notebooks..."
notebook_matches=$(find charts/hub/source/notebooks -name "*.ipynb" -type f 2>/dev/null | wc -l || echo 0)
echo "  Found $notebook_matches total notebook(s)"

# ADR-specific verification logic
echo ""
echo "### ADR-Specific Verification"

case "$ADR_NUM" in
  "004")
    echo "ADR-004: KServe Model Serving"
    echo "Checking for InferenceService definitions..."
    find charts/ -name "*.yaml" -type f -exec grep -l "kind: InferenceService" {} \; 2>/dev/null || echo "  No InferenceService found"
    ;;
  "007")
    echo "ADR-007: Prometheus Monitoring"
    echo "Checking for Prometheus configurations..."
    find charts/ -name "*.yaml" -type f -exec grep -l "prometheus\|ServiceMonitor" {} \; 2>/dev/null | head -n 3 || echo "  No Prometheus config found"
    ;;
  "029")
    echo "ADR-029: Jupyter Notebook Validator Operator"
    echo "Checking for validator operator references..."
    grep -r "validator\|validation" charts/ --include="*.yaml" -l 2>/dev/null | head -n 3 || echo "  No validator references found"
    ;;
  "036")
    echo "ADR-036: Go-Based MCP Server"
    echo "Checking for Go MCP server code..."
    find . -name "go.mod" -o -name "main.go" 2>/dev/null | grep -i mcp || echo "  No Go MCP server found"
    ;;
  "043")
    echo "ADR-043: Deployment Stability Health Checks"
    echo "Checking for health check configurations..."
    grep -r "livenessProbe\|readinessProbe\|healthz" charts/ --include="*.yaml" -l 2>/dev/null | head -n 5 || echo "  No health checks found"
    ;;
  *)
    echo "No specific verification logic for ADR-$ADR_NUM"
    echo "Performing generic search..."
    ;;
esac

echo ""
echo "## Verification Summary"
echo "- Chart files: $chart_matches"
echo "- Script files: $script_matches"
echo "- Total notebooks: $notebook_matches"
echo ""
echo "✅ Verification complete for ADR-$ADR_NUM"
echo ""
echo "Note: This is an automated scan. Manual code review recommended for complete verification."
