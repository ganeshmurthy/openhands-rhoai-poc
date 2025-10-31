# OpenHands RHOAI Integration POC

## 🚨 Current Project Status

Here is a summary of issues I faced with OpenHands. To make the proof of concept minimally viable, we need live chat to work. But I faced OpenShift compatibility issues because it is pretty restrictive when it comes to permissions (for good reason).

### Root Problems:
- **Entrypoint Script Dependencies**: OpenHands' entrypoint.sh requires root privileges for user management and Docker socket access
- **Virtual Environment Permissions**: The Python venv in /app/.venv/bin/ cannot be executed by OpenShift's arbitrary UID assignments
- **Complex Build Process**: OpenHands has intricate build dependencies (like build_vscode.py) that make system-wide installation and building your own image problematic
- **Runtime Expectations**: All runtimes (local, cli, kubernetes) expect either Docker access or specific system dependencies that conflict with OpenShift's restricted-v2 SCC

### What I Tried:
- **Basic deployment** - worked for UI access
- **LLM integration** - successfully connected to RHOAI endpoints
- **Real-time chat** - blocked by Socket.IO/runtime initialization failures due to permission issues
- **Multiple runtimes** - local, cli, kubernetes all failed due to permission issues
- **Custom image approaches** - entrypoint bypass, venv permission fixes, system-wide installation

### Conclusion:
OpenHands was designed for environments with slightly more permissive security contexts (like standard Docker or less restrictive Kubernetes). OpenShift's security-first approach with arbitrary UIDs, read-only filesystems, and restricted capabilities creates fundamental incompatibilities.

The POC successfully demonstrated the UI integration and LLM connectivity, but the core interactive functionality remains blocked by OpenShift's strict security model.

### Future Outlook:
Wait for OpenHands to develop OpenShift-compatible deployment modes.

---

This repository contains the configuration files and deployment scripts for integrating OpenHands AI agent with Red Hat OpenShift AI (RHOAI).



## 🎯 Overview

OpenHands is an autonomous AI agent that specializes in software engineering tasks. This POC demonstrates how to:
- Deploy OpenHands on OpenShift
- Integrate with RHOAI-hosted language models
- Add OpenHands to the RHOAI dashboard
- Configure secure access and networking

## 📋 Prerequisites

- OpenShift cluster with RHOAI installed
- OpenShift CLI (`oc`) installed and configured
- Cluster admin or sufficient permissions to create namespaces and RBAC
- RHOAI model serving endpoint available (e.g., Llama 3.1 8B)

## 🚀 Quick Start

### 1. Clone and Prepare

```bash
# Navigate to the POC directory
cd openhands-rhoai-poc

# Make deployment script executable (if needed)
chmod +x deploy.sh undeploy.sh
```

### 2. Configure RHOAI Integration

Edit `openhands-config.yaml` to update:
```yaml
data:
  llm_base_url: "https://your-actual-rhoai-model-endpoint.com/v1"
  llm_model: "your-model-name"
```

Edit `openhands-config.yaml` to update the API key:
```bash
# Generate base64 encoded API key
echo -n "your-actual-api-key" | base64

# Update the secret in openhands-config.yaml
```

### 3. Deploy

```bash
# Run the deployment script
./deploy.sh
```

### 4. Verify Deployment

```bash
# Check pod status
oc get pods -n openhands-poc

# Check route
oc get route -n openhands-poc

# Check logs
oc logs deployment/openhands -n openhands-poc
```

## 📁 File Structure

```
openhands-rhoai-poc/
├── openhands-deployment.yaml      # Main deployment, PVC, RBAC
├── openhands-service.yaml         # Service and Route
├── openhands-config.yaml          # ConfigMap, Secret, Namespace
├── rhoai-dashboard-integration.yaml # RHOAI dashboard tile
├── deploy.sh                      # Automated deployment script
├── undeploy.sh                    # Automated cleanup script
└── README.md                      # This file
```

## 🔧 Configuration Details

### Environment Variables

| Variable | Description | Source |
|----------|-------------|---------|
| `LLM_BASE_URL` | RHOAI model endpoint | ConfigMap |
| `LLM_API_KEY` | API key for model access | Secret |
| `LLM_MODEL` | Model name | ConfigMap |
| `WORKSPACE_BASE` | Workspace directory | Static |
| `SANDBOX_RUNTIME_CONTAINER_IMAGE` | Runtime container | Static |

### Resource Requirements

- **CPU**: 500m request, 2 cores limit
- **Memory**: 2Gi request, 4Gi limit  
- **Storage**: 10Gi PVC for workspace
- **Network**: HTTPS route with TLS termination

### Security Configuration

- Dedicated ServiceAccount with minimal RBAC
- Non-root container execution (UID 1000)
- No privilege escalation
- Secure secret management for API keys

## 🎛️ RHOAI Dashboard Integration

The POC includes an `OdhApplication` custom resource that:
- Adds OpenHands tile to RHOAI dashboard `/enabled` page
- Shows "Open Application" button for direct access
- Configured as "Red Hat managed" category like core RHOAI services
- No validation required - simple direct launch
- Categorizes under "AI and Machine Learning"

## 🔍 Troubleshooting

### Common Issues

1. **Pod stuck in Pending**
   ```bash
   oc describe pod -l app=openhands -n openhands-poc
   ```
   Check for PVC binding issues or resource constraints.

2. **Connection to RHOAI model fails**
   ```bash
   oc logs deployment/openhands -n openhands-poc
   ```
   Verify `LLM_BASE_URL` and `LLM_API_KEY` configuration.

3. **Dashboard tile not appearing**
   ```bash
   oc get odhapplication openhands -n redhat-ods-applications
   ```
   Ensure RHOAI dashboard has proper permissions.

### Useful Commands

```bash
# Restart deployment
oc rollout restart deployment/openhands -n openhands-poc

# Update configuration
oc edit configmap openhands-config -n openhands-poc

# Check route accessibility
curl -k https://$(oc get route openhands-route -n openhands-poc -o jsonpath='{.spec.host}')

# Port forward for local testing
oc port-forward svc/openhands-service 3000:3000 -n openhands-poc
```

## 🧹 Cleanup

### Automated Cleanup (Recommended)

```bash
# Interactive mode (asks for confirmation)
./undeploy.sh

# Delete everything including PVC and namespace (no prompts)
./undeploy.sh --delete-all

# Delete everything except PVC (preserves workspace data)
./undeploy.sh --keep-pvc

# Delete everything except namespace (keeps namespace for redeployment)
./undeploy.sh --keep-namespace

# Show help
./undeploy.sh --help
```

The undeploy script will:
- Remove RHOAI dashboard integration
- Delete OpenShift route and service
- Remove deployment and pods
- Clean up RBAC resources (ClusterRole, ClusterRoleBinding, ServiceAccount)
- Delete secrets and configmaps
- Handle PVC and namespace deletion based on parameters

### Manual Cleanup (Alternative)

```bash
# Remove all POC resources manually
oc delete namespace openhands-poc
oc delete odhapplication openhands -n redhat-ods-applications
oc delete clusterrole openhands-role
oc delete clusterrolebinding openhands-binding
```

## 🤝 Support

- OpenHands Documentation: https://docs.all-hands.dev/
- RHOAI Documentation: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed
- OpenShift Documentation: https://docs.openshift.com/
