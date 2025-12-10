# validated_patterns_deploy

Deploys selected Validated Pattern via ArgoCD.

## Purpose

This role handles deployment of Validated Patterns using ArgoCD:

- Validates pattern configuration
- Configures ArgoCD
- Deploys pattern via ArgoCD Application
- Verifies deployment health

## Requirements

- Ansible 2.12+
- kubernetes.core collection
- OpenShift cluster with ArgoCD installed
- kubeconfig configured

## Role Variables

```yaml
validated_patterns_pattern_name: "common"
validated_patterns_pattern_path: "patterns/common"
validated_patterns_namespace: "validated-patterns"
validated_patterns_repo_url: "https://github.com/validatedpatterns/patterns.git"
validated_patterns_target_revision: "main"
validated_patterns_sync_timeout: 300
validated_patterns_auto_sync: true
```

## Usage

```yaml
- name: Deploy pattern
  hosts: localhost
  gather_facts: no
  roles:
    - validated_patterns_deploy
```

## License

Apache 2.0
