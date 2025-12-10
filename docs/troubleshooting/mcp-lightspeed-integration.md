# Troubleshooting: MCP Server and OpenShift Lightspeed Integration

## Problem Discovered

**Issue**: OpenShift Lightspeed was not aware of the MCP server despite OLSConfig being configured.

**Symptoms**:
```bash
# Lightspeed logs showed:
ERROR: Failed to get MCP tools: unhandled errors in a TaskGroup (1 sub-exception)

# When user asked Lightspeed:
"List all critical incidents from the last hour"
Response: "I cannot directly access your cluster's live data..."
```

## Root Cause Analysis

### Investigation Steps

1. **Checked OLSConfig**:
   ```bash
   oc get olsconfig cluster -o yaml
   ```
   - Found: `mcpServers.streamableHTTP.url: http://cluster-health-mcp-server:3000`
   - OLSConfig was correctly configured ✅

2. **Checked MCP Server Transport**:
   ```bash
   oc logs deployment/cluster-health-mcp-server -n self-healing-platform
   ```
   - Found: `🚀 Cluster Health MCP Server started with stdio transport`
   - **ROOT CAUSE**: MCP server running in **stdio mode**, NOT HTTP mode ❌

3. **Tested Port 3000**:
   ```bash
   curl http://cluster-health-mcp-server:3000/health
   ```
   - Before fix: Connection refused (port not listening)
   - **ISSUE**: Port 3000 was NOT open in stdio mode ❌

### Why This Happened

The MCP server supports TWO transport modes:

| Mode | Environment Variable | Port | Use Case |
|------|---------------------|------|----------|
| **stdio** | `MCP_TRANSPORT=stdio` | N/A | Direct process spawning |
| **HTTP** | `MCP_TRANSPORT=http` | 3000 | OpenShift Lightspeed integration (SSE) |

**Our deployment had:**
- `MCP_TRANSPORT=stdio` ❌
- OpenShift Lightspeed expected HTTP on port 3000 ✅
- **Mismatch!** Transport modes incompatible

## Solution Applied

### Code Changes

#### 1. Changed Deployment to HTTP Transport

**File**: `k8s/mcp-server/base/deployment.yaml`

```yaml
# BEFORE
env:
  - name: MCP_TRANSPORT
    value: "stdio"  # ❌ Wrong for OpenShift Lightspeed

# AFTER
env:
  - name: MCP_TRANSPORT
    value: "http"   # ✅ Correct for OpenShift Lightspeed
  - name: PORT
    value: "3000"   # MCP HTTP endpoint port
```

#### 2. Exposed Both Ports

```yaml
# Deployment ports
ports:
  - containerPort: 3000
    name: mcp-http   # MCP protocol endpoint (SSE)
  - containerPort: 9090
    name: metrics     # Prometheus metrics (health probes)

# Service ports
ports:
  - name: mcp-http
    port: 3000
    targetPort: 3000
  - name: metrics
    port: 9090
    targetPort: 9090
```

### Verification

#### 1. MCP Server Health Check
```bash
$ curl http://cluster-health-mcp-server.self-healing-platform.svc.cluster.local:3000/health

Response:
{
  "status": "healthy",
  "transport": "http",  # ✅ Correct!
  "server": "cluster-health-mcp-server",
  "version": "1.0.0"
}
```

#### 2. Network Connectivity from Lightspeed
```bash
$ oc run test-from-lightspeed --image=curlimages/curl:latest --rm -i --restart=Never \
  -n openshift-lightspeed -- \
  curl -s http://cluster-health-mcp-server.self-healing-platform.svc.cluster.local:3000/health

Response:
{"status":"healthy","transport":"http","server":"cluster-health-mcp-server","version":"1.0.0"}
```
✅ **MCP server accessible from Lightspeed namespace!**

#### 3. MCP Endpoint Exists
```bash
$ curl -I http://cluster-health-mcp-server:3000/mcp

HTTP/1.1 404 Not Found  # Expected for GET (MCP uses POST with SSE)
```

Port 3000 is listening and responding ✅

## How HTTP Transport Works

From `src/mcp-server/src/index.ts`:

```typescript
private async startHttpTransport(): Promise<void> {
  const app = express();
  app.use(express.json());

  // MCP protocol endpoint using SSE (Server-Sent Events)
  app.post('/mcp', async (_req, res) => {
    const transport = new SSEServerTransport('/mcp', res);
    await this.server.connect(transport);
  });

  // Health endpoint
  app.get('/health', (_req, res) => {
    res.json({
      status: 'healthy',
      transport: 'http',
      server: 'cluster-health-mcp-server',
      version: '1.0.0'
    });
  });

  const port = parseInt(process.env['PORT'] || '3000');
  app.listen(port, () => {
    logger.info(`🌐 Cluster Health MCP Server started with HTTP transport on port ${port}`);
    logger.info('📊 Ready to serve OpenShift Lightspeed via OLSConfig');
  });
}
```

**Key Points**:
- **Endpoint**: `POST /mcp`
- **Transport**: SSE (Server-Sent Events) via `SSEServerTransport`
- **Protocol**: Model Context Protocol over HTTP
- **Streaming**: SSE enables real-time streaming responses

## Remaining Issue: Google API Key

**Status**: `ApiReady: False` (In Progress)

**Possible Causes**:
1. **Invalid Google API Key** (most likely)
2. **Generative Language API not enabled** in Google Cloud
3. **Billing not enabled** on Google Cloud project
4. **API quota exceeded**

**Error from earlier logs**:
```
Error code: 400 - API key not valid. Please pass a valid API key.
```

**Fix**:
```bash
# 1. Get a new valid Google API key from:
https://aistudio.google.com/apikey

# 2. Ensure Generative Language API is enabled:
https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com

# 3. Enable billing on the project

# 4. Update the secret:
oc delete secret google-api-key -n openshift-lightspeed
oc create secret generic google-api-key \
  -n openshift-lightspeed \
  --from-literal=apitoken='YOUR_NEW_VALID_API_KEY'

# 5. Restart Lightspeed:
oc delete pod -l app.kubernetes.io/name=lightspeed-app-server -n openshift-lightspeed
```

## Testing the Integration

Once the Google API key is fixed, test with these queries:

### Test 1: Cluster Health
```
User: "What is the current cluster health status?"
Expected: MCP server returns real-time cluster health data
```

### Test 2: Anomaly Detection
```
User: "Show me anomalies from the last 24 hours"
Expected: MCP server queries incidents and returns anomaly list
```

### Test 3: InferenceServices
```
User: "How are my InferenceServices performing?"
Expected: MCP server checks KServe InferenceServices and reports status
```

### Test 4: Remediation
```
User: "Trigger remediation for incident INC-12345"
Expected: MCP server executes remediation via coordination engine
```

## Architecture Diagram

```
OpenShift Console
      ↓
  Lightspeed UI
      ↓
lightspeed-app-server (Pod)
      ↓
   OLSConfig
      ↓
   mcpServers:
     - streamableHTTP:
         url: http://cluster-health-mcp-server:3000  ← HTTP transport
      ↓
cluster-health-mcp-server:3000 (MCP HTTP endpoint)
      ↓
   POST /mcp (SSE transport)
      ↓
MCP Tools:
  - get-cluster-health
  - query-incidents
  - analyze-anomalies
  - trigger-remediation
      ↓
coordination-engine:8080
prometheus, kubernetes API, etc.
```

## Quick Reference

### Check MCP Server Transport Mode
```bash
oc logs deployment/cluster-health-mcp-server -n self-healing-platform | grep "transport"
```
Expected: `Cluster Health MCP Server started with HTTP transport`

### Test MCP Server Health
```bash
curl http://cluster-health-mcp-server.self-healing-platform.svc.cluster.local:3000/health
```
Expected: `{"status":"healthy","transport":"http",...}`

### Check OLSConfig Status
```bash
oc get olsconfig cluster -o jsonpath='{.status.conditions[*]}' | jq .
```
Watch for `ApiReady: True`

### View Lightspeed Logs
```bash
oc logs -n openshift-lightspeed deployment/lightspeed-app-server -c lightspeed-service-api --tail=100
```
Look for: `MCP servers provided: ['cluster-health-mcp-server']` (no errors)

## Related Documentation

- **[Deploy MCP Server Guide](../how-to/deploy-mcp-server-lightspeed.md)** - Complete deployment instructions
- **[Lightspeed-Notebook Feedback Loop](../how-to/lightspeed-notebook-feedback-loop.md)** - Using interactions
- **[ADR-014: MCP Server Architecture](../adrs/014-openshift-aiops-platform-mcp-server.md)** - Technical design
- **[ADR-016: Gemini Integration](../adrs/017-gemini-integration-openshift-lightspeed.md)** - Lightspeed integration

## Summary

**Problem**: OpenShift Lightspeed couldn't connect to MCP server
**Root Cause**: MCP server running stdio transport instead of HTTP
**Solution**: Changed `MCP_TRANSPORT=http` in deployment
**Status**: ✅ MCP server now accessible via HTTP on port 3000
**Remaining**: ⚠️ Google API key needs to be valid

**Commits**:
- `1d442b34` - Enable HTTP transport for OpenShift Lightspeed integration
- `e69f7f81` - Custom application testing guide
- `bdca0b2e` - Fix kustomization reference
