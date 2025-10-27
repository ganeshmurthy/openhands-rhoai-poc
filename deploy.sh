#!/bin/bash

# OpenHands RHOAI Integration POC Deployment Script
# This script deploys OpenHands AI agent integrated with Red Hat OpenShift AI

set -Eefuxo pipefail

NAMESPACE="openhands-poc"
RHOAI_NAMESPACE="redhat-ods-applications"

echo "🚀 Starting OpenHands RHOAI Integration POC Deployment"

# Check if oc is available
if ! command -v oc &> /dev/null; then
    echo "❌ OpenShift CLI (oc) is not installed or not in PATH"
    exit 1
fi

# Check if logged into OpenShift
if ! oc whoami &> /dev/null; then
    echo "❌ Not logged into OpenShift cluster. Please run 'oc login' first"
    exit 1
fi

echo "✅ Connected to OpenShift cluster as $(oc whoami)"

# Step 1: Create namespace first
echo "📦 Creating namespace..."
oc create namespace $NAMESPACE --dry-run=client -o yaml | oc apply -f -

# Wait 30 seconds for namespace to be ready
echo "⏳ Waiting 30 seconds for namespace to be ready..."
sleep 30

# Step 2: Apply configurations
echo "🔧 Applying configurations..."
oc apply -f openhands-config.yaml

# Step 3: Deploy OpenHands application
echo "🤖 Deploying OpenHands application..."
oc apply -f openhands-deployment.yaml

# Step 3a: Grant anyuid SCC for OpenHands (requires root for entrypoint)
echo "🔐 Granting anyuid SCC to OpenHands service account..."
oc adm policy add-scc-to-user anyuid -z openhands-sa -n $NAMESPACE

# Step 4: Create service and route
echo "🌐 Creating service and route..."
oc apply -f openhands-service.yaml

# Step 5: Wait for deployment to be ready
echo "⏳ Waiting for OpenHands deployment to be ready..."
oc rollout status deployment/openhands -n $NAMESPACE --timeout=300s

# Step 6: Integrate with RHOAI dashboard
echo "🎛️ Integrating with RHOAI dashboard..."
oc apply -f rhoai-dashboard-integration.yaml

# Step 7: Get the route URL
echo "🔗 Getting OpenHands route URL..."
ROUTE_URL=$(oc get route openhands-route -n $NAMESPACE -o jsonpath='{.spec.host}')

echo ""
echo "✅ OpenHands POC deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "   Namespace: $NAMESPACE"
echo "   Route URL: https://$ROUTE_URL"
echo "   Dashboard: Check RHOAI dashboard for OpenHands tile"
echo ""
echo "🔧 Next Steps:"
echo "   1. Update the LLM_BASE_URL in openhands-config.yaml with your actual RHOAI model endpoint"
echo "   2. Update the LLM_API_KEY in openhands-secrets.yaml with your actual API key"
echo "   3. Restart the deployment: oc rollout restart deployment/openhands -n $NAMESPACE"
echo "   4. Access OpenHands at: https://$ROUTE_URL"
echo ""
echo "🔍 Troubleshooting:"
echo "   Check pods: oc get pods -n $NAMESPACE"
echo "   Check logs: oc logs deployment/openhands -n $NAMESPACE"
echo "   Check route: oc get route -n $NAMESPACE"
