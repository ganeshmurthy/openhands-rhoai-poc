#!/bin/bash

# OpenHands RHOAI Integration POC Undeploy Script
# This script removes all resources created by deploy.sh
#
# Usage:
#   ./undeploy.sh                    # Interactive mode (asks for confirmation)
#   ./undeploy.sh --delete-all       # Delete everything including PVC and namespace
#   ./undeploy.sh --keep-pvc         # Delete everything except PVC
#   ./undeploy.sh --keep-namespace   # Delete everything except namespace
#   ./undeploy.sh --help             # Show this help

set -Eefuxo pipefail

NAMESPACE="openhands-poc"
RHOAI_NAMESPACE="redhat-ods-applications"

# Parse command line arguments
DELETE_PVC="ask"
DELETE_NAMESPACE="ask"

while [[ $# -gt 0 ]]; do
  case $1 in
    --delete-all)
      DELETE_PVC="yes"
      DELETE_NAMESPACE="yes"
      shift
      ;;
    --keep-pvc)
      DELETE_PVC="no"
      DELETE_NAMESPACE="ask"
      shift
      ;;
    --keep-namespace)
      DELETE_PVC="ask"
      DELETE_NAMESPACE="no"
      shift
      ;;
    --help)
      echo "OpenHands RHOAI Integration POC Undeploy Script"
      echo ""
      echo "Usage:"
      echo "  ./undeploy.sh                    # Interactive mode (asks for confirmation)"
      echo "  ./undeploy.sh --delete-all       # Delete everything including PVC and namespace"
      echo "  ./undeploy.sh --keep-pvc         # Delete everything except PVC"
      echo "  ./undeploy.sh --keep-namespace   # Delete everything except namespace"
      echo "  ./undeploy.sh --help             # Show this help"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown parameter: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

echo "🗑️  Starting OpenHands RHOAI Integration POC Cleanup"

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

# Step 1: Remove RHOAI dashboard integration
echo "🎛️ Removing RHOAI dashboard integration..."
if oc get odhapplication openhands -n $RHOAI_NAMESPACE &> /dev/null; then
    oc delete odhapplication openhands -n $RHOAI_NAMESPACE
    echo "   ✅ Removed OpenHands dashboard tile"
else
    echo "   ℹ️  OpenHands dashboard tile not found (already removed or never created)"
fi

# Step 2: Remove OpenShift route
echo "🌐 Removing OpenShift route..."
if oc get route openhands-route -n $NAMESPACE &> /dev/null; then
    oc delete route openhands-route -n $NAMESPACE
    echo "   ✅ Removed OpenHands route"
else
    echo "   ℹ️  OpenHands route not found"
fi

# Step 3: Remove service
echo "🔌 Removing service..."
if oc get service openhands-service -n $NAMESPACE &> /dev/null; then
    oc delete service openhands-service -n $NAMESPACE
    echo "   ✅ Removed OpenHands service"
else
    echo "   ℹ️  OpenHands service not found"
fi

# Step 4: Remove deployment
echo "🤖 Removing OpenHands deployment..."
if oc get deployment openhands -n $NAMESPACE &> /dev/null; then
    oc delete deployment openhands -n $NAMESPACE
    echo "   ✅ Removed OpenHands deployment"
else
    echo "   ℹ️  OpenHands deployment not found"
fi

# Step 5: Remove PVC (this will delete workspace data)
echo "💾 Removing persistent volume claim..."
if oc get pvc openhands-workspace -n $NAMESPACE &> /dev/null; then
    if [[ $DELETE_PVC == "yes" ]]; then
        echo "   🗑️  Deleting workspace PVC (--delete-all specified)"
        oc delete pvc openhands-workspace -n $NAMESPACE
        echo "   ✅ Removed OpenHands workspace PVC"
    elif [[ $DELETE_PVC == "no" ]]; then
        echo "   ℹ️  Keeping workspace PVC (--keep-pvc specified)"
    else
        echo "   ⚠️  This will delete all workspace data!"
        read -p "   Do you want to delete the workspace PVC? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            oc delete pvc openhands-workspace -n $NAMESPACE
            echo "   ✅ Removed OpenHands workspace PVC"
        else
            echo "   ℹ️  Keeping workspace PVC (data preserved)"
        fi
    fi
else
    echo "   ℹ️  OpenHands workspace PVC not found"
fi

# Step 6: Remove RBAC resources
echo "🔐 Removing RBAC resources..."

# Remove ClusterRoleBinding
if oc get clusterrolebinding openhands-binding &> /dev/null; then
    oc delete clusterrolebinding openhands-binding
    echo "   ✅ Removed ClusterRoleBinding"
else
    echo "   ℹ️  ClusterRoleBinding not found"
fi

# Remove ClusterRole
if oc get clusterrole openhands-role &> /dev/null; then
    oc delete clusterrole openhands-role
    echo "   ✅ Removed ClusterRole"
else
    echo "   ℹ️  ClusterRole not found"
fi

# Remove ServiceAccount (will be deleted with namespace, but explicit cleanup)
if oc get serviceaccount openhands-sa -n $NAMESPACE &> /dev/null; then
    oc delete serviceaccount openhands-sa -n $NAMESPACE
    echo "   ✅ Removed ServiceAccount"
else
    echo "   ℹ️  ServiceAccount not found"
fi

# Step 7: Remove secrets and configmaps
echo "🔑 Removing secrets and configmaps..."
if oc get secret openhands-secrets -n $NAMESPACE &> /dev/null; then
    oc delete secret openhands-secrets -n $NAMESPACE
    echo "   ✅ Removed OpenHands secrets"
else
    echo "   ℹ️  OpenHands secrets not found"
fi

if oc get configmap openhands-config -n $NAMESPACE &> /dev/null; then
    oc delete configmap openhands-config -n $NAMESPACE
    echo "   ✅ Removed OpenHands configmap"
else
    echo "   ℹ️  OpenHands configmap not found"
fi

# Step 8: Wait for pods to terminate
echo "⏳ Waiting for pods to terminate..."
if oc get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -q openhands; then
    oc wait --for=delete pods -l app=openhands -n $NAMESPACE --timeout=120s
    echo "   ✅ All OpenHands pods terminated"
else
    echo "   ℹ️  No OpenHands pods found"
fi

# Step 9: Delete the namespace
echo "🗂️  Removing namespace..."
if oc get namespace $NAMESPACE &> /dev/null; then
    if [[ $DELETE_NAMESPACE == "yes" ]]; then
        echo "   🗑️  Deleting namespace '$NAMESPACE' (--delete-all specified)"
        oc delete namespace $NAMESPACE
        echo "   ⏳ Waiting for namespace deletion..."
        oc wait --for=delete namespace/$NAMESPACE --timeout=300s
        echo "   ✅ Removed namespace '$NAMESPACE'"
    elif [[ $DELETE_NAMESPACE == "no" ]]; then
        echo "   ℹ️  Keeping namespace '$NAMESPACE' (--keep-namespace specified)"
    else
        echo "   ⚠️  This will delete the entire '$NAMESPACE' namespace and all remaining resources!"
        read -p "   Do you want to delete the namespace? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            oc delete namespace $NAMESPACE
            echo "   ⏳ Waiting for namespace deletion..."
            oc wait --for=delete namespace/$NAMESPACE --timeout=300s
            echo "   ✅ Removed namespace '$NAMESPACE'"
        else
            echo "   ℹ️  Keeping namespace '$NAMESPACE'"
        fi
    fi
else
    echo "   ℹ️  Namespace '$NAMESPACE' not found"
fi

echo ""
echo "✅ OpenHands POC cleanup completed!"
echo ""
echo "📋 Cleanup Summary:"
echo "   🎛️  RHOAI dashboard integration: Removed"
echo "   🌐 Route and service: Removed"
echo "   🤖 Deployment and pods: Removed"
echo "   🔐 RBAC resources: Removed"
echo "   🔑 Secrets and configmaps: Removed"
echo "   🗂️  Namespace: $(if oc get namespace $NAMESPACE &> /dev/null; then echo "Preserved"; else echo "Removed"; fi)"
echo ""
echo "🔍 Verification Commands:"
echo "   Check namespace: oc get namespace $NAMESPACE"
echo "   Check dashboard: oc get odhapplication openhands -n $RHOAI_NAMESPACE"
echo "   Check cluster resources: oc get clusterrole,clusterrolebinding | grep openhands"
echo ""
echo "🚀 To redeploy OpenHands, run: ./deploy.sh"
