#!/bin/bash
set -e

# Arguments passed from Terraform
REGION=$1
CLUSTER_NAME=$2

echo "Starting LB Cleanup Guard (Destroy Provisioner)..."

# Ensure kubeconfig is updated
if aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"; then
    echo "Connected to cluster: $CLUSTER_NAME"
else
    echo "Warning: Could not connect to cluster. Assuming already destroyed."
    exit 0
fi

echo "Waiting for LoadBalancer services to be cleaned up by the controller..."

# Wait loop (up to 5 minutes)
for i in {1..30}; do
    # Count LoadBalancer services (cross-platform compatible count)
    LB_COUNT=$(kubectl get svc --all-namespaces --no-headers 2>/dev/null | grep LoadBalancer | wc -l | tr -d ' ')

    if [ "$LB_COUNT" -eq "0" ]; then
        echo "All LoadBalancer services are gone. Safe to destroy controller."
        exit 0
    fi
    
    echo "Found $LB_COUNT LoadBalancer(s) still active. Waiting for controller cleanup... ($i/30)"
    sleep 10
done

echo "Timeout waiting for controller cleanup. Force deleting remaining LoadBalancer services..."

# List and delete remaining LoadBalancers
kubectl get svc --all-namespaces --no-headers | grep LoadBalancer | while read -r ns name rest; do
    echo "Force deleting service $name in namespace $ns..."
    kubectl delete svc "$name" -n "$ns" --timeout=30s --grace-period=0 --force 2>/dev/null || true
    # Patch finalizers if stuck
    kubectl patch svc "$name" -n "$ns" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
done

# Give AWS API a moment to register deletions, though we can't guarantee AWS resource deletion if controller is stuck/gone.
sleep 30

echo "Cleanup Guard finished."
