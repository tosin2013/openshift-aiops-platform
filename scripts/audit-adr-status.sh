#!/bin/bash
# ADR Status Scanner
# Scans all ADRs and extracts status information

set -euo pipefail

ADR_DIR="/home/lab-user/openshift-aiops-platform/docs/adrs"
OUTPUT_DIR="$ADR_DIR/audit-reports"
OUTPUT="$OUTPUT_DIR/status-scan-$(date +%Y-%m-%d).md"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

echo "# ADR Status Scan - $(date '+%Y-%m-%d %H:%M:%S')" > "$OUTPUT"
echo "" >> "$OUTPUT"
echo "Automated scan of all Architectural Decision Records" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Initialize counters
total_adrs=0
implemented=0
in_progress=0
accepted=0
deprecated=0
superseded=0

echo "## Summary Statistics" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Scan each ADR file
echo "## Detailed Status" >> "$OUTPUT"
echo "" >> "$OUTPUT"

for adr in "$ADR_DIR"/[0-9][0-9][0-9]-*.md; do
  if [[ -f "$adr" ]]; then
    adr_num=$(basename "$adr" | grep -oE '^[0-9]{3}')
    adr_title=$(basename "$adr" .md | sed 's/^[0-9]\{3\}-//')

    # Extract status information
    status_line=$(grep -i "^\*\*Status\*\*\|^## Status" "$adr" | head -n 1 || echo "Status: Unknown")

    # Extract implementation status if present
    impl_status=$(grep -i "^\*\*Implementation Status\*\*" "$adr" | head -n 1 || echo "")

    # Categorize ADR based on status keywords
    status_text=$(cat "$adr" | grep -A 5 "^## Status\|^\*\*Status\*\*" | head -n 10)

    category="Unknown"
    if echo "$status_text" | grep -qi "implemented"; then
      category="✅ Implemented"
      ((implemented++))
    elif echo "$status_text" | grep -qi "deprecated"; then
      category="⚠️ Deprecated"
      ((deprecated++))
    elif echo "$status_text" | grep -qi "superseded"; then
      category="⚠️ Superseded"
      ((superseded++))
    elif echo "$status_text" | grep -qi "in progress\|partially"; then
      category="🚧 In Progress"
      ((in_progress++))
    elif echo "$status_text" | grep -qi "accepted"; then
      category="📋 Accepted"
      ((accepted++))
    fi

    echo "### ADR-$adr_num: $adr_title" >> "$OUTPUT"
    echo "- **Category**: $category" >> "$OUTPUT"
    echo "- **Status**: $status_line" >> "$OUTPUT"
    if [[ -n "$impl_status" ]]; then
      echo "- **Implementation**: $impl_status" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"

    ((total_adrs++))
  fi
done

# Update summary statistics at the top
sed -i "/## Summary Statistics/a\\
\\
| Status Category | Count | Percentage |\\
|-----------------|-------|------------|\\
| ✅ Implemented | $implemented | $(awk "BEGIN {printf \"%.1f\", ($implemented/$total_adrs)*100}")% |\\
| 🚧 In Progress | $in_progress | $(awk "BEGIN {printf \"%.1f\", ($in_progress/$total_adrs)*100}")% |\\
| 📋 Accepted (Not Started) | $accepted | $(awk "BEGIN {printf \"%.1f\", ($accepted/$total_adrs)*100}")% |\\
| ⚠️ Deprecated | $deprecated | $(awk "BEGIN {printf \"%.1f\", ($deprecated/$total_adrs)*100}")% |\\
| ⚠️ Superseded | $superseded | $(awk "BEGIN {printf \"%.1f\", ($superseded/$total_adrs)*100}")% |\\
| **Total ADRs** | **$total_adrs** | **100%** |\\
" "$OUTPUT"

echo ""
echo "✅ Status scan complete!"
echo "📊 Total ADRs scanned: $total_adrs"
echo "📝 Report generated: $OUTPUT"
echo ""
echo "Summary:"
echo "  ✅ Implemented: $implemented"
echo "  🚧 In Progress: $in_progress"
echo "  📋 Accepted: $accepted"
echo "  ⚠️ Deprecated: $deprecated"
echo "  ⚠️ Superseded: $superseded"
