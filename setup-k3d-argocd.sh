#!/bin/bash
set -e

CLUSTER_NAME="k3d-argo-promo"
ARGOCD_PORT=8443

echo "🚀 Setting up k3d cluster with ArgoCD..."

# Check for required tools
for cmd in k3d kubectl helm; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ $cmd is not installed. Please install it first."
        exit 1
    fi
done

# Delete existing cluster if it exists
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "🗑️  Deleting existing cluster '$CLUSTER_NAME'..."
    k3d cluster delete "$CLUSTER_NAME"
fi

# Create k3d cluster with port mapping for ArgoCD
echo "📦 Creating k3d cluster '$CLUSTER_NAME'..."
k3d cluster create "$CLUSTER_NAME" \
    --port "${ARGOCD_PORT}:443@loadbalancer" \
    --k3s-arg "--disable=traefik@server:0"

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Add Argo Helm repository
echo "📥 Adding Argo Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
echo "🔧 Installing ArgoCD..."
helm upgrade --install argocd -n argocd argo/argo-cd --create-namespace \
    --set server.service.type=LoadBalancer \
    --set server.service.servicePortHttps=443 \
    --set configs.params."server\.insecure"=false

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get the initial admin password
echo ""
echo "✅ ArgoCD is installed and ready!"
echo ""
echo "🌐 Access ArgoCD at: https://localhost:${ARGOCD_PORT}"
echo ""
echo "🔑 Login credentials:"
echo "   Username: admin"
echo -n "   Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "⚠️  Note: You may need to accept the self-signed certificate in your browser."
echo ""
echo "💡 To get the password again later, run:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d; echo"

