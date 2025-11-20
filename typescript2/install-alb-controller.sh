#!/bin/bash

# AWS Load Balancer Controller Installation Script
# This script installs the AWS Load Balancer Controller in your EKS cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CLUSTER_NAME="prod-eks-sre-cluster"
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="575108957879"
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Load Balancer Controller Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm is not installed${NC}"
    echo -e "${YELLOW}Install helm: https://helm.sh/docs/intro/install/${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Check cluster access
echo -e "${YELLOW}Checking cluster access...${NC}"
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}Error: Cannot access cluster. Please update kubeconfig:${NC}"
    echo -e "${YELLOW}  aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Cluster access verified${NC}"
echo ""

# Step 1: Create IAM Policy
echo -e "${YELLOW}Step 1: Creating IAM Policy...${NC}"

# Check if policy already exists
if aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" &> /dev/null; then
    echo -e "${GREEN}✓ IAM Policy already exists${NC}"
    POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
else
    # Create the policy
    POLICY_ARN=$(aws iam create-policy \
        --policy-name ${POLICY_NAME} \
        --policy-document file://iam-policy.json \
        --query 'Policy.Arn' \
        --output text)
    echo -e "${GREEN}✓ IAM Policy created: ${POLICY_ARN}${NC}"
fi
echo ""

# Step 2: Create IAM Service Account
echo -e "${YELLOW}Step 2: Creating IAM Service Account...${NC}"

eksctl create iamserviceaccount \
  --cluster=${CLUSTER_NAME} \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=${POLICY_ARN} \
  --approve \
  --override-existing-serviceaccounts \
  --region=${AWS_REGION}

echo -e "${GREEN}✓ IAM Service Account created${NC}"
echo ""

# Step 3: Install AWS Load Balancer Controller using Helm
echo -e "${YELLOW}Step 3: Installing AWS Load Balancer Controller...${NC}"

# Add the EKS chart repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install the controller
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=${AWS_REGION} \
  --set vpcId=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.resourcesVpcConfig.vpcId" --output text --region ${AWS_REGION})

echo -e "${GREEN}✓ AWS Load Balancer Controller installed${NC}"
echo ""

# Step 4: Verify installation
echo -e "${YELLOW}Step 4: Verifying installation...${NC}"

# Wait for deployment to be ready
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system

echo -e "${GREEN}✓ AWS Load Balancer Controller is running${NC}"
echo ""

# Show controller pods
echo -e "${YELLOW}Controller Pods:${NC}"
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Deploy your application: kubectl apply -f kubernetes/"
echo "2. Check ingress: kubectl get ingress -n prod-hello"
echo "3. Get ALB DNS: kubectl get ingress prod-hello-ingress -n prod-hello -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo ""
