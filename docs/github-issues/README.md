# GitHub Issue Templates for jupyter-notebook-validator-operator

This directory contains comprehensive GitHub issue templates to propose enhancements to the [jupyter-notebook-validator-operator](https://github.com/tosin2013/jupyter-notebook-validator-operator).

## Background

The openshift-aiops-platform is **one user** of the jupyter-notebook-validator-operator among many potential users. These issue recommendations consider broad value across:
- Data science teams
- MLOps engineers
- Platform teams
- Research organizations
- Any Kubernetes/OpenShift environment running Jupyter notebook validation

## Recommended Issues

### Issue #1: Init Container Support (P1 - High Priority)
**File**: `jupyter-notebook-validator-operator-issue-1-init-containers.md`

**Summary**: Add support for Kubernetes init containers in NotebookValidationJob pod configuration.

**Why This Matters**:
- Enables notebooks to wait for dependencies (databases, APIs, storage)
- Critical for cluster restart resilience
- Kubernetes-native pattern applicable to any user
- Simple implementation (pass-through to pod spec)

**Value**:
- **Broad**: Benefits any organization with multi-component environments
- **Cluster Reboot Ready**: Aligns with openshift-aiops-platform ADR-043 patterns
- **Low Cost**: ~3-5 days implementation effort

**How to Submit**:
1. Review the full issue content in the file
2. Copy the markdown content
3. Create new issue at: https://github.com/tosin2013/jupyter-notebook-validator-operator/issues/new
4. Paste content and submit

---

### Issue #2: Prometheus Metrics Implementation (P1 - High Priority)
**File**: `jupyter-notebook-validator-operator-issue-2-prometheus-metrics.md`

**Summary**: Implement Prometheus metrics endpoint as specified in ADR-010.

**Why This Matters**:
- ADR-010 is ACCEPTED but not yet implemented
- Essential for production fleet management (30+ notebooks)
- Enables SLO/SLA monitoring, alerting, capacity planning
- Industry standard for Kubernetes operators

**Value**:
- **Operational Visibility**: Monitor notebook success rates, execution times
- **Proactive Alerting**: Detect issues before users report them
- **Capacity Planning**: Historical data informs scaling decisions

**How to Submit**:
1. Review the full issue content in the file
2. Copy the markdown content
3. Create new issue at: https://github.com/tosin2013/jupyter-notebook-validator-operator/issues/new
4. Paste content and submit

---

### Issue #3: Model-Aware Validation (P2 - Medium Priority) ⚠️ DEPENDS ON ADR-020
**File**: `jupyter-notebook-validator-operator-issue-3-model-validation.md`

**Summary**: Implement native operator support for validating trained models against serving platforms (KServe, vLLM, etc.).

**Why This Matters**:
- Catch model deployment issues during training, not production
- Validates models are compatible with KServe/vLLM/TorchServe
- Reduces failed deployments from format mismatches

**Important Notes**:
- ⚠️ **Depends on ADR-020 status**: If ADR-020 is still PROPOSED (not ACCEPTED), architectural review needed first
- **P2 Priority**: Optional feature, higher implementation cost (3-6 weeks)
- **Complementary to Init Containers**: Post-execution validation vs pre-execution dependency management

**Recommendation**:
1. Check ADR-020 status: https://github.com/tosin2013/jupyter-notebook-validator-operator/blob/main/docs/adrs/020-model-aware-validation.md
2. If ADR-020 is ACCEPTED, submit this issue
3. If ADR-020 is still PROPOSED, wait for architectural review

**How to Submit** (if ADR-020 is ACCEPTED):
1. Review the full issue content in the file
2. Copy the markdown content
3. Create new issue at: https://github.com/tosin2013/jupyter-notebook-validator-operator/issues/new
4. Paste content and submit

---

## Issue Priority Rationale

### Why P1 for Issues #1 and #2

Both issues are **high priority** because they:
1. **Broadly Applicable**: Benefit any user of the operator, not just openshift-aiops-platform
2. **Production Necessity**: Essential for reliable operations at scale
3. **Low Implementation Cost**: Straightforward implementations (3-7 days each)
4. **Kubernetes-Native**: Use standard patterns (init containers, Prometheus metrics)
5. **High User Value**: Significantly improve reliability and observability

### Why P2 for Issue #3

Issue #3 is **medium priority** because:
1. **Depends on ADR-020**: Architectural decision not yet finalized
2. **Platform-Specific**: Primarily benefits users deploying to model serving platforms
3. **Higher Implementation Cost**: Requires platform-specific validators (3-6 weeks)
4. **Optional Feature**: Not required for core operator functionality

## Relationship to openshift-aiops-platform

The openshift-aiops-platform serves as **one example use case** for these features:

| Feature | openshift-aiops-platform Benefit | General Benefit |
|---------|----------------------------------|-----------------|
| **Init Containers** | Wait for Prometheus/ArgoCD before metrics notebooks | Any multi-service dependency (databases, APIs, storage) |
| **Prometheus Metrics** | Monitor 32 notebooks across 11 sync waves | Fleet management for 5-100+ notebooks |
| **Model Validation** | Validate KServe compatibility for 2 models | Any MLOps workflow with model serving |

**Key Point**: These issues provide value **beyond** openshift-aiops-platform to the broader community.

## How to Use These Templates

### Option 1: Submit Directly to GitHub

1. Navigate to: https://github.com/tosin2013/jupyter-notebook-validator-operator/issues/new
2. Copy content from the issue file (e.g., `jupyter-notebook-validator-operator-issue-1-init-containers.md`)
3. Paste into GitHub issue description
4. Add appropriate labels: `enhancement`, `high-priority` (or `medium-priority`)
5. Submit

### Option 2: Discuss with Operator Maintainers First

If you want to gauge interest before creating issues:

1. Start a discussion: https://github.com/tosin2013/jupyter-notebook-validator-operator/discussions
2. Reference these issue templates
3. Ask if the features align with operator roadmap
4. Create issues after discussion consensus

### Option 3: Open Pull Request with Issue

For highly motivated contributors:

1. Create issue using template
2. Implement the feature (follow issue acceptance criteria)
3. Open PR referencing the issue
4. Collaborate with maintainers on review

## What NOT to Include in Issues

When submitting these issues, **avoid**:
- ❌ Claiming volume support is broken (it's not - ADR-045 implemented it)
- ❌ Requesting features specific only to openshift-aiops-platform
- ❌ Demanding urgent timelines or priority changes
- ❌ Duplicating existing issues (search first: https://github.com/tosin2013/jupyter-notebook-validator-operator/issues)

## Verification Before Submission

Before submitting any issue, verify:

1. **Search existing issues**: Ensure feature not already requested
2. **Check latest operator version**: Confirm feature not already implemented
3. **Review relevant ADRs**: Understand architectural context
4. **Test current behavior**: Verify issue description matches reality

## Critical Finding: Volume Support Already Works

**DO NOT create an issue claiming volume support is broken.**

**Facts**:
- ✅ Volume support IMPLEMENTED via ADR-045 (November 29, 2025)
- ✅ Current operator version: 1.0.7 (supports OCP 4.18, 4.19, 4.20)
- ✅ All 32 notebooks in openshift-aiops-platform successfully use PVC volumes
- ✅ E2E tests passing (Tier 5)

The outdated document `docs/VOLUME-SUPPORT-ISSUE.md` (dated December 1, 2025, referencing v1.0.4) has been **removed** because it contained false information.

## Related Documentation

### In openshift-aiops-platform
- **ADR-043**: Deployment Stability and Cross-Namespace Health Check Patterns
  - Documents init container patterns for cluster restart resilience
  - Rationale for Issue #1 (init containers)
  - Location: `docs/adrs/043-deployment-stability-health-checks.md`

### In jupyter-notebook-validator-operator (External)
- **ADR-010**: Observability and Monitoring Strategy (Accepted, not implemented)
  - Specifies Prometheus metrics design
  - Rationale for Issue #2 (metrics)
- **ADR-020**: Model-Aware Validation (Proposed, status TBD)
  - Proposes model validation feature
  - Rationale for Issue #3 (model validation)
- **ADR-045**: Volume and PVC Support (Implemented, Nov 29, 2025)
  - Volume support already working
  - No issue needed

## Questions or Feedback

If you have questions about these issue templates:

1. **About the templates**: Open discussion in openshift-aiops-platform repository
2. **About the operator**: Open discussion in jupyter-notebook-validator-operator repository
3. **About ADR-043**: Review `docs/adrs/043-deployment-stability-health-checks.md` in this repository

## Summary

These issue templates represent **high-value enhancements** that benefit the broader community:

1. **Issue #1 (Init Containers)**: Kubernetes-native dependency management - **SUBMIT NOW**
2. **Issue #2 (Prometheus Metrics)**: Production observability - **SUBMIT NOW**
3. **Issue #3 (Model Validation)**: MLOps workflow automation - **WAIT FOR ADR-020 ACCEPTANCE**

**Estimated Total Value**: 10-15 days implementation effort for issues #1 and #2, delivering significant improvements in reliability and observability for all operator users.
