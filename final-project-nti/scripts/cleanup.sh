#!/bin/bash
set -e

echo "Starting Pre-Destroy Cleanup..."

# Variables (populated by pipeline or environment)
REGION=${AWS_REGION:-us-east-1}
CLUSTER_NAME=${CLUSTER_NAME:-devops-cluster}

echo "Updating kubeconfig for cluster: $CLUSTER_NAME in region: $REGION"
# Attempt to update kubeconfig. If cluster is already gone, this will fail, which is fine (nothing to clean).
if ! aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"; then
    echo "Warning: Could not connect to cluster. It might already be destroyed. Skipping K8s cleanup."
    exit 0
fi

echo "Connected to cluster."

# 1. Delete manually applied resources (Ghosts to Terraform)
echo "Deleting resources from k8s/ directory..."
if [ -d "k8s" ]; then
    kubectl delete -f k8s/ --recursive --ignore-not-found=true --timeout=60s || echo "Warning: Failed to delete some k8s manifests."
else
    echo "Directory k8s/ not found, skipping."
fi

# 2. Force delete Namespaces managed by Tools (Safety net)
# Use --cascade=foreground to ensure resources inside are deleted first
echo "Cleaning up Tool Namespaces (argocd, sonarqube, ingress-nginx)..."
kubectl delete ns argocd sonarqube ingress-nginx --ignore-not-found=true --timeout=120s || echo "Warning: Namespaces deletion timed out or failed."

# 3. Aggressively kill pods in default namespace (e.g., application pods)
echo "Force deleting all pods in default namespace..."
kubectl delete pods --all -n default --force --grace-period=0 --ignore-not-found=true

# 4. Check for and remove any lingering LoadBalancer Services (if any exist)
echo "Checking for LoadBalancer services..."
kubectl get svc -A --no-headers | grep LoadBalancer | awk '{print $1, $2}' | while read -r ns svc; do
    echo "Deleting lingering LoadBalancer service: $svc in $ns"
    kubectl delete svc "$svc" -n "$ns" --timeout=30s
done

echo "K8s Cleanup Complete. Proceeding to Terraform Destroy."
