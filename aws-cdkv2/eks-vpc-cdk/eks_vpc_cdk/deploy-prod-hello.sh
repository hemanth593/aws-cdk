#!/bin/bash

# Deployment script for prod-hello EKS resources
# This script sets up the AWS Load Balancer Controller and deploys the application

set -e

CLUSTER_NAME="prod-eks-sre-cluster"
REGION="us-east-1"
ACCOUNT_ID="575108957879"
ALB_CONTROLLER_VERSION="v2.8.1"

echo "=========================================="
echo "EKS prod-hello Deployment Script"
echo "=========================================="

# Step 1: Update kubeconfig
echo ""
echo "[Step 1] Updating kubeconfig..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Step 2: Verify cluster connectivity
echo ""
echo "[Step 2] Verifying cluster connectivity..."
kubectl get nodes

# Step 3: Create IAM OIDC provider (if not already created)
echo ""
echo "[Step 3] Setting up IAM OIDC provider..."
eksctl utils associate-iam-oidc-provider \
    --region=$REGION \
    --cluster=$CLUSTER_NAME \
    --approve || echo "OIDC provider may already exist"

# Step 4: Create IAM policy for AWS Load Balancer Controller
echo ""
echo "[Step 4] Creating IAM policy for AWS Load Balancer Controller..."
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/$ALB_CONTROLLER_VERSION/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json || echo "Policy may already exist"

# Step 5: Create service account for AWS Load Balancer Controller
echo ""
echo "[Step 5] Creating service account for AWS Load Balancer Controller..."
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --region=$REGION \
    --approve || echo "Service account may already exist"

# Step 6: Install AWS Load Balancer Controller using Helm
echo ""
echo "[Step 6] Installing AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$REGION \
    --set vpcId=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.resourcesVpcConfig.vpcId" --output text) || echo "Controller may already be installed"

# Step 7: Wait for AWS Load Balancer Controller to be ready
echo ""
echo "[Step 7] Waiting for AWS Load Balancer Controller to be ready..."
kubectl wait --namespace kube-system \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=aws-load-balancer-controller \
    --timeout=120s

# Step 8: Apply Kubernetes manifests
echo ""
echo "[Step 8] Applying Kubernetes manifests..."
kubectl apply -f kubernetes-manifests.yaml

# Step 9: Wait for deployment to be ready
echo ""
echo "[Step 9] Waiting for deployment to be ready..."
kubectl wait --namespace prod-hello \
    --for=condition=available deployment/prod-hello-deployment \
    --timeout=300s

# Step 10: Get ALB DNS name
echo ""
echo "[Step 10] Getting ALB DNS name..."
sleep 30  # Wait for ingress to provision ALB
ALB_DNS=$(kubectl get ingress prod-hello-ingress -n prod-hello -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "ALB DNS Name: $ALB_DNS"
echo ""
echo "To test the endpoint, run:"
echo "curl http://$ALB_DNS"
echo ""
echo "To check the deployment status:"
echo "kubectl get pods -n prod-hello"
echo "kubectl get svc -n prod-hello"
echo "kubectl get ingress -n prod-hello"
echo ""
