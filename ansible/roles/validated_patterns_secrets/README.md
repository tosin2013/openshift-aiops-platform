# validated_patterns_secrets

Manages secrets and credentials for Validated Patterns.

## Purpose

This role handles secrets management:

- Validates secrets namespace
- Configures sealed secrets (optional)
- Manages credentials
- Configures RBAC for secrets

## Requirements

- Ansible 2.12+
- kubernetes.core collection
- OpenShift cluster access

## Role Variables

```yaml
validated_patterns_secrets_namespace: "validated-patterns-secrets"
validated_patterns_sealed_secrets_enabled: false
validated_patterns_vault_enabled: false
validated_patterns_vault_addr: "https://vault.example.com"
```

## Usage

```yaml
- name: Manage secrets
  hosts: localhost
  gather_facts: no
  roles:
    - validated_patterns_secrets
```

## License

Apache 2.0
