# ADR Implementation TODO

**Generated**: 2026-01-25
**Source**: MCP Comprehensive Review (Manual Analysis)
**Report**: [docs/adrs/audit-reports/mcp-comprehensive-review-2026-01-25.md](docs/adrs/audit-reports/mcp-comprehensive-review-2026-01-25.md)

This document tracks TODO items for partially implemented ADRs with compliance scores between 5.0-7.9/10.

---

## High Priority (Score 7.0-7.9)

### ADR-027: CI/CD Pipeline Automation

**Compliance Score**: 7.5/10
**Current Status**: Partially Implemented
**Category**: MLOps & CI/CD
**Last Updated**: 2026-01-25

#### Overview

GitOps framework operational with ArgoCD and Tekton pipelines, but GitHub webhook automation is missing. This blocks fully automated CI/CD workflows.

#### Current State

✅ **Implemented**:
- ArgoCD GitOps deployment operational (271-line configuration)
- Automated sync policies: prune=true, selfHeal=true
- Makefile CI/CD targets: `install`, `operator-deploy`, `argo-healthcheck`
- Ansible automation: `operator_deploy_prereqs.yml` playbook
- ArgoCD RBAC: ServiceAccount, Role, ClusterRole configured
- Tekton pipelines ready for integration (4 pipelines from ADR-021, ADR-023)

❌ **Missing**:
- GitHub webhook integration
- EventListener and TriggerBinding
- Automated pipeline triggers
- Tekton Dashboard deployment
- Prometheus ServiceMonitors for pipelines

#### Missing Components

##### 1. GitHub Webhook Integration ⚠️ HIGH PRIORITY

**Evidence**: EventListener NOT found in charts/hub/templates/

**Tasks**:
- [ ] Create `charts/hub/templates/tekton-eventlistener.yaml` with github-webhook-listener
- [ ] Create TriggerBinding for GitHub push/PR events
- [ ] Create TriggerTemplate to start deployment-validation-pipeline
- [ ] Configure GitHub webhook in repository settings:
  - URL: `https://<route>/github-webhook`
  - Content type: `application/json`
  - Events: Push, Pull Request
  - Secret: Create and configure webhook secret
- [ ] Test automated pipeline triggering:
  - Push to main branch
  - Verify pipeline starts automatically
  - Check logs: `tkn pipelinerun logs -f`

**Files to Create**:
```yaml
# charts/hub/templates/tekton-eventlistener.yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: github-webhook-listener
  namespace: openshift-pipelines
spec:
  serviceAccountName: tekton-triggers-sa
  triggers:
    - name: github-push
      interceptors:
        - ref:
            name: "github"
          params:
            - name: "secretRef"
              value:
                secretName: github-webhook-secret
                secretKey: secretToken
            - name: "eventTypes"
              value: ["push", "pull_request"]
      bindings:
        - ref: github-push-binding
      template:
        ref: deployment-validation-trigger

---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: github-push-binding
  namespace: openshift-pipelines
spec:
  params:
    - name: git-revision
      value: $(body.head_commit.id)
    - name: git-repo-url
      value: $(body.repository.clone_url)

---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: deployment-validation-trigger
  namespace: openshift-pipelines
spec:
  params:
    - name: git-revision
    - name: git-repo-url
  resourcetemplates:
    - apiVersion: tekton.dev/v1beta1
      kind: PipelineRun
      metadata:
        generateName: deployment-validation-
      spec:
        pipelineRef:
          name: deployment-validation-pipeline
        params:
          - name: git-revision
            value: $(tt.params.git-revision)
          - name: git-repo-url
            value: $(tt.params.git-repo-url)
```

**Implementation Effort**: MEDIUM (3-4 days)
**Dependencies**: GitHub repository access, OpenShift route configuration

##### 2. Tekton Dashboard Deployment ⚠️ MEDIUM PRIORITY

**Evidence**: Tekton Dashboard deployment NOT verified

**Tasks**:
- [ ] Deploy Tekton Dashboard:
  ```bash
  kubectl apply -f https://github.com/tektoncd/dashboard/releases/latest/download/tekton-dashboard-release.yaml
  ```
- [ ] Create OpenShift Route for dashboard access
- [ ] Configure RBAC for dashboard ServiceAccount
- [ ] Access dashboard and verify pipeline visibility
- [ ] Document dashboard URL in deployment guide

**Implementation Effort**: SMALL (1 day)
**Dependencies**: OpenShift Pipelines operator installed

##### 3. Prometheus ServiceMonitors ⚠️ MEDIUM PRIORITY

**Evidence**: Tekton metrics scraping NOT verified

**Tasks**:
- [ ] Create ServiceMonitor for Tekton Pipelines:
  - Metrics endpoint: `tekton-pipelines-controller:9090/metrics`
  - Labels: `app.kubernetes.io/component=tekton-pipelines`
- [ ] Create ServiceMonitor for Tekton Triggers:
  - Metrics endpoint: `tekton-triggers-controller:9000/metrics`
  - Labels: `app.kubernetes.io/component=tekton-triggers`
- [ ] Create PrometheusRule for pipeline failure alerts:
  - Alert when pipeline fails > 3 times in 1 hour
  - Alert when pipeline duration exceeds threshold
- [ ] Verify metrics in Prometheus:
  ```promql
  tekton_pipelines_controller_pipelinerun_count
  tekton_pipelines_controller_pipelinerun_duration_seconds
  ```
- [ ] Create Grafana dashboard for CI/CD metrics

**Files to Create**:
```yaml
# charts/hub/templates/tekton-servicemonitors.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: tekton-pipelines-controller
  namespace: openshift-pipelines
spec:
  selector:
    matchLabels:
      app.kubernetes.io/component: tekton-pipelines
  endpoints:
    - port: metrics
      interval: 30s

---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: tekton-pipeline-alerts
  namespace: openshift-pipelines
spec:
  groups:
    - name: tekton-pipelines
      interval: 30s
      rules:
        - alert: TektonPipelineFailureRate
          expr: |
            sum(rate(tekton_pipelines_controller_pipelinerun_count{status="failed"}[1h]))
            > 3
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High Tekton pipeline failure rate"
```

**Implementation Effort**: SMALL (2 days)
**Dependencies**: Prometheus Operator, Grafana deployment

#### Implementation Roadmap

**Week 1**:
- [ ] Create GitHub webhook configuration
- [ ] Deploy EventListener, TriggerBinding, TriggerTemplate
- [ ] Test manual webhook trigger with curl

**Week 2**:
- [ ] Configure GitHub webhook in repository
- [ ] Test automated pipeline execution
- [ ] Deploy Tekton Dashboard

**Week 3**:
- [ ] Create Prometheus ServiceMonitors
- [ ] Create PrometheusRule for alerts
- [ ] Create Grafana CI/CD dashboard

**Week 4**:
- [ ] Documentation and testing
- [ ] Update ADR-027 status to "Implemented"

#### Verification Checklist

- [ ] GitHub webhook successfully triggers pipelines
- [ ] PipelineRuns created automatically on git push
- [ ] Tekton Dashboard shows pipeline history
- [ ] Prometheus metrics collected for Tekton
- [ ] Alerts fire on pipeline failures
- [ ] Grafana dashboard shows CI/CD metrics
- [ ] Documentation updated with webhook setup instructions

#### Dependencies

- **ADR-021**: Tekton Pipeline Validation (✅ Implemented)
- **ADR-023**: Tekton Configuration Pipeline (✅ Implemented)
- **GitHub Repository**: Write access required for webhook configuration
- **OpenShift Route**: External route for EventListener
- **Prometheus Operator**: For ServiceMonitors

#### Success Criteria

✅ **Completion Criteria** (update status to "Implemented"):
- GitHub webhook triggers deployment-validation-pipeline on push to main
- Tekton Dashboard accessible via OpenShift route
- Prometheus scraping Tekton metrics
- PrometheusRule alerts configured
- Zero manual pipeline triggers required for deployments

---

### ADR-038: Migration from Python to Go Coordination Engine

**Compliance Score**: 7.0/10
**Current Status**: Partially Implemented
**Category**: Coordination & Self-Healing
**Last Updated**: 2026-01-25

#### Overview

Go coordination engine is deployed and responding to health checks, but core coordination features (incident management API, remediation triggering, alert correlation) have not been verified.

#### Current State

✅ **Implemented**:
- Go coordination engine deployed (image: `quay.io/takinosh/openshift-coordination-engine:ocp-4.18-latest`)
- Health check operational: `{"status":"ok","version":"ocp-4.18-93c9718"}`
- Init containers configured (wait-for-prometheus, wait-for-argocd)
- Deployment ready: 1/1 replicas

❌ **Missing Verification**:
- Incident management API endpoints (`/incidents`, `/remediate`)
- Remediation triggering functionality
- Alert correlation logic
- Integration with InferenceServices (anomaly-detector, predictive-analytics)

#### Verification Tasks

- [ ] Test incident creation API:
  ```bash
  oc exec deployment/utilities -n utils -- curl -X POST \
    http://coordination-engine.self-healing-platform.svc:8080/api/v1/incidents \
    -H "Content-Type: application/json" \
    -d '{"title":"Test incident","severity":"low"}'
  ```
- [ ] Verify remediation triggering:
  ```bash
  oc exec deployment/utilities -n utils -- curl -X POST \
    http://coordination-engine.self-healing-platform.svc:8080/api/v1/remediation/trigger \
    -H "Content-Type: application/json" \
    -d '{"incident_id":"test-123","action":"restart"}'
  ```
- [ ] Check alert correlation endpoints:
  ```bash
  oc exec deployment/utilities -n utils -- curl \
    http://coordination-engine.self-healing-platform.svc:8080/api/v1/alerts
  ```
- [ ] Validate integration with InferenceServices:
  ```bash
  oc exec deployment/utilities -n utils -- curl \
    http://coordination-engine.self-healing-platform.svc:8080/api/v1/models/status
  ```

#### Implementation Effort

**SMALL** (1-2 days for verification, no new development needed)

#### Success Criteria

✅ **Completion Criteria** (update status to "Implemented"):
- All API endpoints respond successfully
- Incident management operations work end-to-end
- Remediation actions can be triggered programmatically
- Integration with ML models (InferenceServices) verified
- Alert correlation logic functional

---

## ✅ Completed Items (Removed from TODO)

### ADR-036: Go-Based Standalone MCP Server

**Status**: ✅ **IMPLEMENTED** (2026-01-25)
**Final Compliance Score**: 9.0/10 (was 6.5/10)

**Completion Summary**:
- All documentation updated to reflect 12 tools + 4 resources + 6 prompts
- Production deployment verified: 100% test pass rate, 10+ hours uptime
- See [MCP Server Deployment Verification Report](docs/adrs/audit-reports/mcp-server-deployment-verification-2026-01-25.md) for full details
- Implementation **significantly exceeds** Phase 1.4 scope (600% of plan)

**What Changed**:
- Verified deployment in OpenShift 4.18.21
- Tested all endpoints: health, tools, resources, prompts
- Updated ADR-036 with actual capabilities (12 tools vs. 2 planned for Phase 1.4)
- Updated IMPLEMENTATION-TRACKER.md status to "Implemented"

**Remaining Work** (Future Phases - Not Blocking):
- Phase 1.5: Enhanced Observability (structured logging, tracing)
- Phase 1.6: Advanced Caching (Redis backend, cache metrics)
- Phase 1.7+: WebSocket transport, multi-cluster support

---

## Notes

### Scoring Methodology

**Compliance Score**: 0-10 scale based on implementation completeness
- **10.0**: Fully implemented, all requirements met
- **9.0-9.9**: Implemented with minor gaps
- **8.0-8.9**: Implemented with some verification pending
- **7.0-7.9**: Mostly implemented, major components missing
- **6.0-6.9**: Partially implemented, significant gaps
- **5.0-5.9**: Partially implemented, major work remaining
- **< 5.0**: Architecture defined or not started

**Effort Estimates**:
- **SMALL**: 1-5 days (individual contributor)
- **MEDIUM**: 5-15 days (may require multiple contributors)
- **LARGE**: 15+ days (team effort, multiple sprints)

### Priority Levels

- **HIGH**: Blocks other work, critical path items
- **MEDIUM**: Important but not blocking
- **LOW**: Nice to have, future enhancements

### Update Frequency

This TODO.md should be reviewed and updated:
- **Weekly**: Progress updates on active items
- **Monthly**: Re-prioritization based on business needs
- **Per Release**: Status alignment with ADR tracker

### Related Documents

- **MCP Comprehensive Review**: [docs/adrs/audit-reports/mcp-comprehensive-review-2026-01-25.md](docs/adrs/audit-reports/mcp-comprehensive-review-2026-01-25.md)
- **Implementation Tracker**: [docs/adrs/IMPLEMENTATION-TRACKER.md](docs/adrs/IMPLEMENTATION-TRACKER.md)
- **ADR README**: [docs/adrs/README.md](docs/adrs/README.md)
- **Phase 4 Audit**: [docs/adrs/audit-reports/phase4-mlops-cicd-verification-2026-01-25.md](docs/adrs/audit-reports/phase4-mlops-cicd-verification-2026-01-25.md)
- **Phase 5 Audit**: [docs/adrs/audit-reports/phase5-llm-intelligent-interfaces-verification-2026-01-25.md](docs/adrs/audit-reports/phase5-llm-intelligent-interfaces-verification-2026-01-25.md)

---

**Last Updated**: 2026-01-25
**Maintainer**: Architecture Team
**Next Review**: 2026-02-01 (Weekly sprint review)
