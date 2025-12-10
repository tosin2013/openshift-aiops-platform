# Bootstrap Architecture Diagrams

This document contains visual diagrams for the Self-Healing Platform Bootstrap Architecture (ADR-009).

## System Overview

```mermaid
graph TB
    subgraph "Developer Workstation"
        A[Developer] --> B[build-images.sh]
        A --> C[bootstrap.sh]
        A --> D[validate_bootstrap.sh]
    end

    subgraph "Container Registry"
        E[coordination-engine:latest]
        F[anomaly-detector:latest]
        G[predictive-analytics:latest]
    end

    subgraph "OpenShift Cluster"
        H[self-healing-platform namespace]
        I[self-healing-platform-dev namespace]
        J[self-healing-platform-prod namespace]
    end

    subgraph "Kustomize Configuration"
        K[k8s/base/]
        L[k8s/overlays/development/]
        M[k8s/overlays/production/]
    end

    B --> E
    B --> F
    B --> G

    C --> K
    C --> L
    C --> M

    K --> H
    L --> I
    M --> J

    D --> H
    D --> I
    D --> J
```

## Bootstrap Execution Flow

```mermaid
sequenceDiagram
    participant U as User
    participant B as bootstrap.sh
    participant K as Kustomize
    participant OC as OpenShift Cluster
    participant V as validate_bootstrap.sh

    U->>B: ./bootstrap.sh --environment development

    Note over B: Phase 1: Prerequisites
    B->>B: check_prerequisites()
    B->>OC: oc whoami
    B->>OC: oc get csv -A
    B->>B: determine_environment()

    Note over B: Phase 2: Kustomize Deployment
    B->>K: validate_kustomize_config()
    K-->>B: Configuration valid
    B->>K: kustomize build k8s/overlays/development
    K-->>B: Generated manifest
    B->>OC: oc apply -f manifest
    OC-->>B: Resources created

    Note over B: Phase 3: Post-Deployment
    B->>OC: Verify resource creation
    B->>OC: Check service readiness
    B->>B: configure_gitea_integration()
    B->>OC: oc get all -n gitea

    Note over B: Phase 4: Validation
    B->>V: ./validate_bootstrap.sh
    V->>OC: Run validation checks
    OC-->>V: Validation results
    V-->>U: Deployment report
```

## Component Deployment Architecture

```mermaid
graph TD
    subgraph "Namespace: self-healing-platform-dev"
        subgraph "Core Components"
            A[Coordination Engine Pod]
            B[Coordination Engine Service]
            A --> B
        end

        subgraph "AI/ML Components"
            C[Jupyter Notebook Pod]
            D[Anomaly Detector InferenceService]
            E[Predictive Analytics InferenceService]
        end

        subgraph "Storage"
            F[Data PVC - 5Gi]
            G[Model Artifacts PVC - 10Gi]
            C --> F
            C --> G
            D --> G
            E --> G
        end

        subgraph "Monitoring"
            H[ServiceMonitor]
            I[PrometheusRule]
            B --> H
            H --> J[Prometheus]
            I --> J
        end

        subgraph "Configuration"
            K[ConfigMap: platform-config]
            L[Secret: model-storage-config]
            A --> K
            A --> L
            C --> K
        end
    end

    subgraph "External Dependencies"
        M[OpenShift AI Operator]
        N[KServe Operator]
        O[Prometheus Operator]
        P[NVIDIA GPU Operator]
    end

    C -.-> M
    D -.-> N
    E -.-> N
    J -.-> O
    C -.-> P
    E -.-> P
```

## Kustomize Overlay Strategy

```mermaid
graph LR
    subgraph "Base Configuration"
        A[kustomization.yaml]
        B[namespace.yaml]
        C[rbac.yaml]
        D[storage.yaml]
        E[monitoring.yaml]
        F[coordination-engine.yaml]
        G[ai-ml-workbench.yaml]
        H[model-serving.yaml]
    end

    subgraph "Development Overlay"
        I[kustomization.yaml]
        I --> J[Resource Patches]
        J --> K[CPU: 100m-500m]
        J --> L[Memory: 128Mi-1Gi]
        J --> M[Storage: 5Gi-10Gi]
        J --> N[Replicas: 1]
        J --> O[GPU: Disabled]
    end

    subgraph "Production Overlay"
        P[kustomization.yaml]
        P --> Q[Resource Patches]
        Q --> R[CPU: 500m-2]
        Q --> S[Memory: 512Mi-4Gi]
        Q --> T[Storage: 50Gi-200Gi]
        Q --> U[Replicas: 3]
        Q --> V[GPU: Enabled]
    end

    A --> I
    A --> P

    style I fill:#e1f5fe
    style P fill:#fff3e0
```

## Validation Framework Architecture

```mermaid
graph TD
    A[validate_bootstrap.sh] --> B[Infrastructure Validation]
    A --> C[Component Validation]
    A --> D[Integration Validation]
    A --> E[Security Validation]

    B --> B1[Namespace Exists]
    B --> B2[RBAC Configured]
    B --> B3[Storage Available]
    B --> B4[Operators Running]

    C --> C1[Coordination Engine Health]
    C --> C2[Jupyter Notebook Ready]
    C --> C3[Model Serving Active]
    C --> C4[Monitoring Configured]

    D --> D1[Prometheus Integration]
    D --> D2[Gitea Integration]
    D --> D3[Storage Integration]
    D --> D4[Network Connectivity]

    E --> E1[Secrets Configured]
    E --> E2[RBAC Compliance]
    E --> E3[Network Policies]
    E --> E4[Pod Security]

    B1 --> F[Validation Report]
    B2 --> F
    B3 --> F
    B4 --> F
    C1 --> F
    C2 --> F
    C3 --> F
    C4 --> F
    D1 --> F
    D2 --> F
    D3 --> F
    D4 --> F
    E1 --> F
    E2 --> F
    E3 --> F
    E4 --> F

    F --> G{All Checks Pass?}
    G -->|Yes| H[✅ Deployment Ready]
    G -->|No| I[❌ Issues Found]
    I --> J[Remediation Guide]
```

## Container Image Build Pipeline

```mermaid
graph TD
    A[build-images.sh] --> B{Container Runtime?}
    B -->|Podman| C[Use Podman]
    B -->|Docker| D[Use Docker]
    B -->|None| E[❌ Error: No Runtime]

    C --> F[Build Coordination Engine]
    D --> F

    F --> G[Build Model Containers]
    G --> H[Build Additional Components]

    H --> I{Registry Configured?}
    I -->|Yes| J[Tag for Registry]
    I -->|No| K[Keep Local Only]

    J --> L[Push to Registry]
    L --> M{Push Success?}
    M -->|Yes| N[Update Kustomize Images]
    M -->|No| O[⚠️ Warning: Push Failed]

    K --> P[✅ Build Complete]
    N --> P
    O --> P

    P --> Q[Generate Build Report]
    Q --> R[Ready for Bootstrap]
```

## Environment Configuration Matrix

```mermaid
graph TD
    subgraph "Development Environment"
        A[Namespace: self-healing-platform-dev]
        B[Resources: Minimal]
        C[Storage: Standard Classes]
        D[GPU: Disabled]
        E[Logging: DEBUG]
        F[Replicas: 1]
        G[Security: Basic]
    end

    subgraph "Production Environment"
        H[Namespace: self-healing-platform]
        I[Resources: High Performance]
        J[Storage: Premium Classes]
        K[GPU: Enabled]
        L[Logging: INFO]
        M[Replicas: 3 (HA)]
        N[Security: Enhanced]
    end

    subgraph "Base Configuration"
        O[Common Resources]
        P[Shared Labels]
        Q[Standard Configurations]
    end

    O --> A
    O --> H
    P --> A
    P --> H
    Q --> A
    Q --> H

    style A fill:#e8f5e8
    style H fill:#fff5f5
```

## Integration Points

```mermaid
graph TD
    subgraph "Self-Healing Platform"
        A[Coordination Engine]
        B[AI/ML Workbench]
        C[Model Serving]
        D[Monitoring]
    end

    subgraph "OpenShift Platform"
        E[OpenShift AI]
        F[KServe]
        G[Prometheus]
        H[Machine Config Operator]
        I[NVIDIA GPU Operator]
    end

    subgraph "External Integrations"
        J[Gitea Repository]
        K[External Registries]
        L[Backup Systems]
        M[External Monitoring]
    end

    A --> H
    A --> G
    B --> E
    B --> I
    C --> F
    D --> G

    A -.-> J
    B -.-> J
    C -.-> K
    D -.-> M

    style A fill:#ffeb3b
    style B fill:#4caf50
    style C fill:#2196f3
    style D fill:#ff9800
```

## Deployment Timeline

```mermaid
gantt
    title Bootstrap Deployment Timeline
    dateFormat  X
    axisFormat %s

    section Prerequisites
    Check Cluster Access    :0, 10
    Validate Operators      :10, 20
    Build Images           :20, 60

    section Phase 1
    Kustomize Build        :60, 70
    Resource Deployment    :70, 120
    Initial Verification   :120, 140

    section Phase 2
    Service Readiness      :140, 180
    Health Checks         :180, 200
    Integration Setup     :200, 240

    section Phase 3
    Environment Config     :240, 280
    Gitea Integration     :280, 300
    Final Validation      :300, 360

    section Completion
    Validation Report     :360, 380
    Documentation        :380, 400
```

## Error Handling Flow

```mermaid
graph TD
    A[Bootstrap Execution] --> B{Prerequisites OK?}
    B -->|No| C[❌ Prerequisite Error]
    B -->|Yes| D[Kustomize Build]

    D --> E{Build Success?}
    E -->|No| F[❌ Configuration Error]
    E -->|Yes| G[Deploy to Cluster]

    G --> H{Deployment Success?}
    H -->|No| I[❌ Deployment Error]
    H -->|Yes| J[Post-Deployment Setup]

    J --> K{Services Ready?}
    K -->|No| L[⚠️ Service Warning]
    K -->|Yes| M[Environment Configuration]

    M --> N{Integration Success?}
    N -->|No| O[⚠️ Integration Warning]
    N -->|Yes| P[✅ Deployment Complete]

    C --> Q[Error Report & Exit]
    F --> Q
    I --> Q
    L --> R[Continue with Warnings]
    O --> R
    R --> S[Partial Success Report]
    P --> T[Success Report]

    style C fill:#ffcdd2
    style F fill:#ffcdd2
    style I fill:#ffcdd2
    style L fill:#fff3e0
    style O fill:#fff3e0
    style P fill:#c8e6c9
```

These diagrams provide comprehensive visual documentation of the Bootstrap Deployment Automation Architecture, supporting ADR-009 with clear illustrations of the system design, execution flow, and component relationships.
