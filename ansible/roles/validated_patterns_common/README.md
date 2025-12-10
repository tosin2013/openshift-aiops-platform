# validated_patterns_common

Deploys validatedpatterns/common with multisource architecture.

## Purpose

This role handles deployment of the validatedpatterns/common repository components:

- Installs rhvp.cluster_utils Ansible collection
- Configures Helm repositories
- Deploys clustergroup-chart v0.9.*
- Enables multisource configuration

## Requirements

- Ansible 2.12+
- kubernetes.core collection
- helm command-line tool
- OpenShift cluster access

## Role Variables

```yaml
validated_patterns_rhvp_collection_version: "1.0.0"
validated_patterns_clustergroup_chart_version: "0.9.*"
validated_patterns_pattern_name: "common"
validated_patterns_target_revision: "main"
validated_patterns_multisource_enabled: true
```

## Usage

```yaml
- name: Deploy validatedpatterns/common
  hosts: localhost
  gather_facts: no
  roles:
    - validated_patterns_common
```

## Helm Repositories Configured

- validatedpatterns: https://charts.validatedpatterns.io
- jetstack: https://charts.jetstack.io
- external-secrets: https://external-secrets.github.io/external-secrets

## License

Apache 2.0
