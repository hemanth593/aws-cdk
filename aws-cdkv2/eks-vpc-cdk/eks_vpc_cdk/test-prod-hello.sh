#!/bin/bash

# Test script for prod-hello application
# This script helps test the deployment and ALB connectivity

set -e

NAMESPACE="prod-hello"
SERVICE_NAME="prod-hello-service"
INGRESS_NAME="prod-hello-ingress"

echo "=========================================="
echo "Testing prod-hello Deployment"
echo "=========================================="

# Check if cluster is accessible
echo ""
echo "[Check 1] Verifying cluster connectivity..."
if kubectl cluster-info &> /dev/null; then
    echo "✓ Cluster is accessible"
else
    echo "✗ Cannot connect to cluster"
    echo "Run: aws eks update-kubeconfig --name prod-eks-sre-cluster --region us-east-1"
    exit 1
fi

# Check namespace
echo ""
echo "[Check 2] Checking namespace..."
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "✓ Namespace '$NAMESPACE' exists"
else
    echo "✗ Namespace '$NAMESPACE' does not exist"
    echo "Run: kubectl apply -f kubernetes-manifests.yaml"
    exit 1
fi

# Check deployment
echo ""
echo "[Check 3] Checking deployment..."
DEPLOYMENT_READY=$(kubectl get deployment -n $NAMESPACE prod-hello-deployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
DEPLOYMENT_DESIRED=$(kubectl get deployment -n $NAMESPACE prod-hello-deployment -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")

if [ "$DEPLOYMENT_READY" == "$DEPLOYMENT_DESIRED" ] && [ "$DEPLOYMENT_READY" != "0" ]; then
    echo "✓ Deployment is ready ($DEPLOYMENT_READY/$DEPLOYMENT_DESIRED replicas)"
else
    echo "⚠ Deployment not ready yet ($DEPLOYMENT_READY/$DEPLOYMENT_DESIRED replicas)"
    kubectl get pods -n $NAMESPACE
fi

# Check service
echo ""
echo "[Check 4] Checking service..."
if kubectl get svc -n $NAMESPACE $SERVICE_NAME &> /dev/null; then
    echo "✓ Service '$SERVICE_NAME' exists"
    SERVICE_IP=$(kubectl get svc -n $NAMESPACE $SERVICE_NAME -o jsonpath='{.spec.clusterIP}')
    echo "  Service ClusterIP: $SERVICE_IP"
else
    echo "✗ Service '$SERVICE_NAME' does not exist"
    exit 1
fi

# Check ingress
echo ""
echo "[Check 5] Checking ingress..."
if kubectl get ingress -n $NAMESPACE $INGRESS_NAME &> /dev/null; then
    echo "✓ Ingress '$INGRESS_NAME' exists"
    ALB_DNS=$(kubectl get ingress -n $NAMESPACE $INGRESS_NAME -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -z "$ALB_DNS" ]; then
        echo "⚠ ALB not provisioned yet (this can take 2-3 minutes)"
        echo "  Run this script again in a moment"
    else
        echo "  ALB DNS: $ALB_DNS"
    fi
else
    echo "✗ Ingress '$INGRESS_NAME' does not exist"
    exit 1
fi

# Check pods
echo ""
echo "[Check 6] Checking pods..."
kubectl get pods -n $NAMESPACE -o wide

# Check nodes
echo ""
echo "[Check 7] Checking nodes for prod-hello-ng..."
kubectl get nodes -l eks.amazonaws.com/nodegroup=prod-hello-ng

# Test service internally
echo ""
echo "[Test 1] Testing service connectivity (from within cluster)..."
kubectl run test-curl-$RANDOM --image=curlimages/curl -i --rm --restart=Never -- \
    curl -s -o /dev/null -w "%{http_code}" http://$SERVICE_NAME.$NAMESPACE.svc.cluster.local || echo "Service test completed"

# Test ALB if available
echo ""
if [ ! -z "$ALB_DNS" ]; then
    echo "[Test 2] ALB is available at: http://$ALB_DNS"
    echo ""
    echo "To test the ALB (requires VPC access):"
    echo "  1. From an EC2 instance in the VPC:"
    echo "     curl http://$ALB_DNS"
    echo ""
    echo "  2. From a pod in the cluster:"
    echo "     kubectl run test-alb --image=curlimages/curl -i --rm --restart=Never -- curl http://$ALB_DNS"
    echo ""
    echo "  3. Port-forward for local testing:"
    echo "     kubectl port-forward -n $NAMESPACE svc/$SERVICE_NAME 8080:80"
    echo "     Then: curl http://localhost:8080"
    
    # Attempt to test from a pod
    echo ""
    read -p "Would you like to test the ALB from a pod now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Testing ALB from pod..."
        kubectl run test-alb-$RANDOM --image=curlimages/curl -i --rm --restart=Never -- \
            curl -v http://$ALB_DNS
    fi
else
    echo "[Test 2] ALB not ready yet. Wait 2-3 minutes and run this script again."
fi

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo "Namespace: $NAMESPACE"
echo "Service: $SERVICE_NAME"
echo "Ingress: $INGRESS_NAME"
if [ ! -z "$ALB_DNS" ]; then
    echo "ALB DNS: $ALB_DNS"
    echo ""
    echo "✓ Deployment appears healthy"
    echo ""
    echo "Next steps:"
    echo "  - Test from within VPC: curl http://$ALB_DNS"
    echo "  - Monitor pods: kubectl get pods -n $NAMESPACE -w"
    echo "  - View logs: kubectl logs -n $NAMESPACE -l app=prod-hello"
else
    echo "⚠ ALB provisioning in progress"
    echo ""
    echo "Next steps:"
    echo "  - Wait 2-3 minutes for ALB to be created"
    echo "  - Run this script again: ./test-prod-hello.sh"
    echo "  - Check ALB controller logs: kubectl logs -n kube-system deployment/aws-load-balancer-controller"
fi
echo ""
