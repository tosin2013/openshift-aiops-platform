# Ansible Role: validated_patterns_validate

Comprehensive validation framework for Validated Patterns deployments.

## Description

This role provides comprehensive validation for Validated Patterns deployments, including pre-deployment checks, deployment monitoring, post-deployment validation, health checks, and notebook validation via the Jupyter Notebook Validator Operator.

**Updated**: 2025-11-18 - Added NotebookValidationJob CRD validation support (ADR-029)

## Requirements

- OpenShift 4.18+ or Kubernetes 1.31+
- Ansible 2.9+
- `kubernetes.core` Ansible collection

## Role Variables

### Validation Configuration

```yaml
# Enable notebook validation (default: true)
validate_notebooks_enabled: true

# Target namespace for validation
validation_namespace: "self-healing-platform"
```

## Tasks

### Pre-deployment Validation (`validate_pre_deployment.yml`)

Validates prerequisites before deployment:
- Cluster connectivity
- Required operators
- Storage configuration
- Network policies
- RBAC permissions

### Deployment Validation (`validate_deployment.yml`)

Monitors deployment process:
- ArgoCD application sync status
- Resource creation progress
- Deployment rollouts

### Post-deployment Validation (`validate_post_deployment.yml`)

Validates platform after deployment:
- All pods running
- Services accessible
- Routes configured correctly

### Health Checks (`validate_health.yml`)

Validates component health:
- Coordination engine health endpoints
- Model serving endpoints
- Monitoring stack

### Notebook Validation (`validate_notebooks.yml`) **NEW**

Validates Jupyter notebooks via CRD:
- NotebookValidationJob CRD status
- Notebook execution success/failure
- Validation summary report

## Example Playbook

```yaml
- name: Validate Deployment
  hosts: localhost
  roles:
    - role: validated_patterns_validate
      vars:
        validate_notebooks_enabled: true
        validation_namespace: "self-healing-platform"
```

## License

GNU General Public License v3.0

## Author Information

OpenShift AIOps Platform Team
