# ADR-014: Cluster Health MCP Server for OpenShift Lightspeed Integration

## Status
**SUPERSEDED** - 2025-12-09 by [ADR-036: Go-Based Standalone MCP Server](036-go-based-standalone-mcp-server.md)

**Previous Status**:
- ~~ACCEPTED - 2025-10-13~~
- ~~IMPLEMENTED - 2025-10-13 (Core MCP server with stdio transport)~~

## Supersession Notice

This ADR documented the original **TypeScript-based MCP server** embedded within the `openshift-aiops-platform` repository (`src/mcp-server/`).

**This implementation has been replaced** by a standalone Go-based MCP server documented in [ADR-036](036-go-based-standalone-mcp-server.md).

**Key Changes in New Implementation**:
| Aspect | ADR-014 (Old) | ADR-036 (New) |
|--------|---------------|---------------|
| **Language** | TypeScript/Node.js | Go 1.21+ |
| **Architecture** | Embedded in platform repo | Standalone repository |
| **Location** | `src/mcp-server/` | `/home/lab-user/openshift-cluster-health-mcp` |
| **SDK** | `@modelcontextprotocol/sdk` (TypeScript) | `modelcontextprotocol/go-sdk` (official Go SDK) |
| **Integration** | Direct coupling | HTTP REST APIs |
| **Deployment** | Part of platform | Independent |
| **Database** | PostgreSQL (optional) | None (stateless) |
| **Transport** | stdio/HTTP | HTTP (primary) |
| **Status** | Removed (commit: 9c2dc301) | ✅ **Phase 1.4 completed** |

**Migration Path**:
- TypeScript implementation removed from `openshift-aiops-platform` on 2025-12-09
- New Go implementation tracked in standalone repository
- Integration maintained via HTTP REST APIs to Coordination Engine and KServe
- See [ADR-036](036-go-based-standalone-mcp-server.md) for current architecture

**Current Status** (Standalone Project):
- ✅ Deployed on OpenShift 4.18.21
- ✅ 2 MCP tools operational (`get-cluster-health`, `list-pods`)
- ✅ 10 architectural decisions documented
- 🚧 Phase 1.5 in progress (Stateless Cache)

---

**Historical Documentation Below** (for archival purposes only)

## Context

According to the **Product Requirements Document (PRD)**, the OpenShift AIOps Self-Healing Platform requires a **Cluster Health MCP server** that integrates with **OpenShift Lightspeed** to provide conversational AI capabilities. This is a core requirement from Section 5.4:

> **Conversational AI Interface:** The conversational AI interface will be powered by OpenShift Lightspeed and a custom Cluster Health MCP server. This will allow users to interact with the Self-Healing Platform using natural language.

> **Cluster Health MCP Server:** A custom MCP server will be developed using the TypeScript SDK to expose the self-healing capabilities and incident data to OpenShift Lightspeed.

The platform requires intelligent operational capabilities that can:

1. **Expose self-healing capabilities** to OpenShift Lightspeed via MCP protocol
2. **Provide incident data and cluster health information** through natural language interface
3. **Enable conversational interaction** with the Self-Healing Platform
4. **Integrate with anomaly detection models** and coordination engine
5. **Support real-time cluster health monitoring** and remediation workflows

Based on the PRD requirements and MCP best practices, we need a **cluster-native Cluster Health MCP server** that serves as the bridge between OpenShift Lightspeed and our self-healing platform architecture.

### Research Findings

**MCP Server Best Practices**:
- MCP provides standardized protocol for AI applications to connect to external data and tools
- Supports both local and remote deployment patterns with HTTP/WebSocket APIs
- Security considerations include "Excessive Agency" risks requiring careful tool scoping
- OpenAI and Google announced MCP support in 2024, indicating industry adoption

**MCP Integration Requirements (from PRD)**:
- **TypeScript SDK**: Custom MCP server developed using TypeScript SDK
- **OpenShift Lightspeed Integration**: Direct integration with existing Lightspeed infrastructure
- **LLM Support**: Compatible with GPT-4.1-mini or fine-tuned Granite models
- **MCP Concepts**: Implement Resources, Tools, and Prompts for comprehensive platform access

## Decision

**Deploy the `cluster-health-mcp-server` as a cluster-native service** that integrates with OpenShift Lightspeed, consisting of:

1. **Cluster Health MCP Server**: TypeScript-based MCP server exposing self-healing capabilities
2. **OpenShift Lightspeed Integration**: Direct MCP protocol connection to existing Lightspeed
3. **Self-Healing Platform Bridge**: API integration with coordination engine and anomaly detection
4. **Persistent Storage**: Incident data, cluster health history, and conversation context

## Rationale

### **Why Cluster-Native MCP Server**
- **PRD Compliance**: Directly implements PRD requirement for "custom Cluster Health MCP server"
- **OpenShift Lightspeed Integration**: Native MCP protocol support for conversational AI
- **Real-time Cluster Access**: Direct access to cluster resources, monitoring, and coordination engine
- **Security**: Network isolation within cluster, secure MCP protocol communication
- **Scalability**: Kubernetes-native scaling and resource management

### **Why TypeScript SDK**
- **PRD Requirement**: PRD specifically calls for "TypeScript SDK" implementation
- **MCP Ecosystem**: Official MCP TypeScript SDK provides robust protocol implementation
- **OpenShift Lightspeed Compatibility**: Proven integration patterns with Lightspeed
- **Performance**: Efficient async/await patterns for real-time cluster operations
- **Maintainability**: Strong typing and modern JavaScript ecosystem

### **Why Direct Lightspeed Integration**
- **User Experience**: Leverages existing OpenShift Lightspeed interface familiar to operators
- **Natural Language**: Enables PRD requirement for "natural language interaction"
- **Unified Interface**: Single conversational interface for all platform operations
- **Enterprise Ready**: Built-in authentication, authorization, and audit capabilities

## Architecture

### **Component Overview**
```
OpenShift AIOps Platform with Cluster Health MCP Server:
┌─────────────────────────────────────────────────────────────┐
│                 OpenShift Lightspeed                       │
│  ┌─────────────────┐    ┌──────────────────┐              │
│  │   Chat UI       │◄───│  LLM Engine      │              │
│  │   (Existing)    │    │  (GPT-4/Granite) │              │
│  └─────────────────┘    └──────────────────┘              │
│           │                        ▲                       │
│           ▼                        │                       │
│  ┌─────────────────────────────────┴───────────────────┐  │
│  │              MCP Protocol                           │  │
│  └─────────────────────────────────┬───────────────────┘  │
└─────────────────────────────────────┼─────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────┐
│                self-healing-platform                       │
│  ┌─────────────────┐    ┌──────────────────┐              │
│  │  Cluster Health │◄───│  Coordination    │              │
│  │  MCP Server     │    │  Engine          │              │
│  │  (TypeScript)   │    │  Integration     │              │
│  └─────────────────┘    └──────────────────┘              │
│           │                        │                       │
│           ▼                        ▼                       │
│  ┌─────────────────┐    ┌──────────────────┐              │
│  │   Incident      │    │  Anomaly         │              │
│  │   Management    │    │  Detection       │              │
│  └─────────────────┘    └──────────────────┘              │
│           │                        │                       │
│           ▼                        ▼                       │
│  ┌─────────────────┐    ┌──────────────────┐              │
│  │   Prometheus    │    │  KServe Models   │              │
│  │   Monitoring    │    │  (ML Inference)  │              │
│  └─────────────────┘    └──────────────────┘              │
└─────────────────────────────────────────────────────────────┘
```

### **Conversational AI Flow (Per PRD Requirements)**
```
Natural Language Interaction Flow:
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   SRE/Operator  │───▶│  OpenShift       │───▶│  LLM Engine     │
│   Natural Lang. │    │  Lightspeed UI   │    │  (GPT-4/Granite)│
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                       │
         ▼                        ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   "Show cluster │    │  MCP Protocol    │    │  Intent         │
│    health"      │    │  Communication   │    │  Understanding  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                       │
         ▼                        ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Cluster       │◄───│  MCP Tools       │◄───│  Tool           │
│   Operations    │    │  Execution       │    │  Selection      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                       │
         ▼                        ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Self-Healing  │    │  Incident Data   │    │  Natural Lang.  │
│   Actions       │    │  & Metrics       │    │  Response       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Implementation

### Transport Protocol

**Primary**: stdio transport for direct OpenShift Lightspeed integration
**Alternative**: HTTP transport available for debugging and development

The MCP server uses **stdio transport by default** (via `MCP_TRANSPORT=stdio` environment variable) for seamless integration with OpenShift Lightspeed's MCP protocol support. This is the recommended approach for production deployments as it provides:

- **Direct process communication**: No network overhead
- **Security**: No exposed HTTP endpoints for MCP protocol
- **Simplicity**: Single connection between Lightspeed and MCP server

HTTP transport can be enabled (`MCP_TRANSPORT=http`) for:
- Development and testing with external MCP clients
- Debugging MCP protocol interactions
- Integration with non-Lightspeed MCP consumers

**Production Deployment** uses stdio transport as configured in `k8s/mcp-server/base/deployment.yaml` and `charts/hub/templates/mcp-server-deployment.yaml`.

### **Phase 1: Cluster Health MCP Server Deployment (Week 1)**

#### **1.1 TypeScript MCP Server Container**
```yaml
# k8s/base/cluster-health-mcp-server.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-health-mcp-server
  namespace: self-healing-platform
  labels:
    app: cluster-health-mcp-server
    component: mcp-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-health-mcp-server
  template:
    metadata:
      labels:
        app: cluster-health-mcp-server
        component: mcp-server
    spec:
      serviceAccountName: cluster-health-mcp-server
      containers:
      - name: mcp-server
        image: cluster-health-mcp-server:latest
        ports:
        - containerPort: 3000
          name: mcp-api
        env:
        - name: NODE_ENV
          value: "production"
        - name: MCP_SERVER_NAME
          value: "cluster-health"
        - name: MCP_SERVER_VERSION
          value: "1.0.0"
        - name: OPENSHIFT_API_URL
          value: "https://kubernetes.default.svc"
        - name: PROMETHEUS_URL
          value: "https://thanos-querier.openshift-monitoring.svc:9091"
        - name: COORDINATION_ENGINE_URL
          value: "http://coordination-engine.self-healing-platform.svc:8080"
        - name: KSERVE_MODELS_NAMESPACE
          value: "self-healing-platform"
        volumeMounts:
        - name: incident-storage
          mountPath: /app/data/incidents
        - name: cluster-health-history
          mountPath: /app/data/history
        - name: conversation-context
          mountPath: /app/data/context
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /mcp/capabilities
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
      volumes:
      - name: incident-storage
        persistentVolumeClaim:
          claimName: cluster-health-incidents
      - name: cluster-health-history
        persistentVolumeClaim:
          claimName: cluster-health-history
      - name: conversation-context
        persistentVolumeClaim:
          claimName: cluster-health-context
```

#### **1.2 MCP Server Service**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: openshift-aiops-platform-mcp-service
  namespace: self-healing-platform
  labels:
    app: openshift-aiops-platform-mcp
    component: intelligence
spec:
  selector:
    app: openshift-aiops-platform-mcp
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
    name: mcp-api
  type: ClusterIP
```

### **Phase 2: Chat Frontend Deployment (Week 2)**

#### **2.1 Streamlit Chat Interface**
```yaml
# k8s/base/mcp-chat-frontend.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openshift-aiops-platform-mcp-chat
  namespace: self-healing-platform
  labels:
    app: openshift-aiops-platform-mcp-chat
    component: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openshift-aiops-platform-mcp-chat
  template:
    metadata:
      labels:
        app: openshift-aiops-platform-mcp-chat
        component: frontend
    spec:
      containers:
      - name: streamlit-chat
        image: openshift-aiops-platform-mcp-chat:latest
        ports:
        - containerPort: 8501
          name: streamlit
        env:
        - name: MCP_SERVER_URL
          value: "http://openshift-aiops-platform-mcp-service:3000"
        - name: STREAMLIT_SERVER_PORT
          value: "8501"
        - name: STREAMLIT_SERVER_ADDRESS
          value: "0.0.0.0"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8501
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8501
          initialDelaySeconds: 10
          periodSeconds: 5
```

#### **2.2 Chat Frontend Service & Route**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: openshift-aiops-platform-mcp-chat-service
  namespace: self-healing-platform
  labels:
    app: openshift-aiops-platform-mcp-chat
    component: frontend
spec:
  selector:
    app: openshift-aiops-platform-mcp-chat
  ports:
  - port: 8501
    targetPort: 8501
    protocol: TCP
    name: streamlit
  type: ClusterIP
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: openshift-aiops-platform-mcp-chat
  namespace: self-healing-platform
  labels:
    app: openshift-aiops-platform-mcp-chat
    component: frontend
spec:
  to:
    kind: Service
    name: openshift-aiops-platform-mcp-chat-service
  port:
    targetPort: streamlit
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

### **Phase 3: Storage Configuration**

#### **3.1 Persistent Volume Claims**
```yaml
# k8s/base/mcp-storage.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mcp-workspace
  namespace: self-healing-platform
  labels:
    app: openshift-aiops-platform-mcp
    component: storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ocs-storagecluster-ceph-rbd
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mcp-memory-storage
  namespace: self-healing-platform
  labels:
    app: openshift-aiops-platform-mcp
    component: storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ocs-storagecluster-ceph-rbd
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mcp-knowledge-graph
  namespace: self-healing-platform
  labels:
    app: openshift-aiops-platform-mcp
    component: storage
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ocs-storagecluster-cephfs
  resources:
    requests:
      storage: 5Gi
```

## Related ADRs

- **ADR-015**: Service Separation - MCP Server vs REST API Service
  - Establishes pure MCP server architecture (stdio-only communication)
  - Defines separation of concerns between MCP and potential REST API services
  - Ensures compliance with MCP protocol best practices
- **ADR-019**: Validated Patterns Framework Adoption
  - MCP server deployment via Helm charts and ArgoCD
  - Integration with Validated Patterns framework for consistent deployment
  - E2E testing using role-based approach
- **ADR-DEVELOPMENT-RULES**: Development rules and E2E testing best practices
  - Guides MCP server testing and deployment validation

## SDK Standards Compliance

**Updated 2025-10-14**: MCP Server implementation updated to use official @modelcontextprotocol/sdk patterns:

### **Current Implementation (SDK v0.5.0)**
```typescript
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { SSEServerTransport } from '@modelcontextprotocol/sdk/server/sse.js';

class ClusterHealthMCPServer {
  private server: Server;

  constructor() {
    // Official SDK Server class with capabilities
    this.server = new Server(
      { name: 'cluster-health', version: '1.0.0' },
      { capabilities: { resources: {}, tools: {} } }
    );
    this.setupHandlers();
  }

  // Dual transport support for stdio and HTTP
  public async start(): Promise<void> {
    const transport = process.env['MCP_TRANSPORT'] || 'stdio';

    if (transport === 'http') {
      await this.startHttpTransport(); // For OLSConfig integration
    } else {
      await this.startStdioTransport(); // For direct spawning
    }
  }
}
```

### **Key Standards Compliance**
- ✅ **Official SDK**: Uses `@modelcontextprotocol/sdk` v0.5.0+
- ✅ **Server Class**: Uses official `Server` class with proper capabilities
- ✅ **Request Handlers**: Uses `setRequestHandler` with official schema types
- ✅ **Transport Support**: Supports both stdio and HTTP transports
- ✅ **Type Safety**: Full TypeScript integration with SDK types
- ✅ **Dependencies**: Added `express` and `zod` for HTTP transport and validation

## Validated Patterns Framework Integration

The MCP server deployment integrates with the Validated Patterns OpenShift Framework (ADR-019):

### Deployment Architecture

**Helm Chart Structure**:
```
charts/hub/templates/
├── mcp-server-deployment.yaml      # MCP server deployment
├── mcp-server-service.yaml         # Service for MCP server
├── mcp-server-configmap.yaml       # Configuration (resources, tools)
└── mcp-server-rbac.yaml            # RBAC permissions
```

**Values Configuration** (values-hub.yaml):
```yaml
mcp_server:
  enabled: true
  image: quay.io/openshift-aiops/cluster-health-mcp-server:latest
  replicas: 1
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "500m"
  transport: http  # or stdio for direct spawning
  lightspeed_integration: true
```

### Deployment Workflow

1. **Prerequisites Role** (`validated_patterns_prerequisites`): Validates cluster has required operators
2. **Common Role** (`validated_patterns_common`): Deploys GitOps infrastructure
3. **Deploy Role** (`validated_patterns_deploy`): Deploys MCP server via ArgoCD
4. **Validate Role** (`validated_patterns_validate`): Verifies MCP server health and connectivity

### ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cluster-health-mcp-server
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://github.com/openshift-aiops/openshift-aiops-platform
    targetRevision: main
    path: charts/hub
    helm:
      values: |
        mcp_server:
          enabled: true
  destination:
    server: https://kubernetes.default.svc
    namespace: self-healing-platform
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### E2E Testing

MCP server deployment is validated using role-based E2E tests:

```yaml
- name: Validate MCP Server Deployment
  include_tasks: ../../ansible/roles/validated_patterns_validate/tasks/validate_health.yml
  vars:
    health_check_endpoints:
      - name: mcp-server
        url: http://cluster-health-mcp-server:3000/health
        expected_status: 200
```

## Implementation Status

- ✅ **MCP Server Core**: TypeScript implementation with dual transport support
- ✅ **Service Separation**: Express.js removed per ADR-015, re-added for HTTP transport only
- ✅ **MCP Protocol**: Resources and tools implemented correctly
- ✅ **SDK Compliance**: Updated to use official @modelcontextprotocol/sdk patterns
- ✅ **Testing**: All tests passing with pure MCP functionality
- 🔄 **Deployment**: Ready for OpenShift cluster deployment via Validated Patterns
- ⏳ **Lightspeed Integration**: Testing with OLSConfig pending
- ⏳ **Helm Charts**: MCP server Helm chart integration in progress

---

*This ADR implements the core MCP server requirement from the PRD while maintaining architectural purity through ADR-015 service separation principles, now fully compliant with official SDK standards.*
