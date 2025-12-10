# validated_patterns_prerequisites

Validates that an OpenShift cluster meets all prerequisites for deploying Validated Patterns.

## Purpose

This role performs comprehensive prerequisite checks:

- OpenShift version validation (4.12+)
- Required operators verification
- Cluster resource availability
- Network connectivity
- RBAC permissions
- Storage configuration

## Requirements

- Ansible 2.12+
- kubernetes.core collection
- OpenShift cluster access
- kubeconfig configured

## Role Variables

```yaml
validated_patterns_min_openshift_version: "4.12"
validated_patterns_min_nodes: 3
validated_patterns_min_cpu: 8  # cores
validated_patterns_min_memory: 16  # GB
validated_patterns_required_operators:
  - openshift-gitops-operator
```

## Usage

```yaml
- name: Validate prerequisites
  hosts: localhost
  gather_facts: no
  roles:
    - validated_patterns_prerequisites
```

## License

Apache 2.0
