#!/bin/bash

# ECR Image Pull Troubleshooting Script
# This script helps diagnose and fix ECR image pull issues

set -e

REGION="us-east-1"
ACCOUNT_ID="575108957879"
REPO_NAME="hello/swatops13032"
IMAGE_TAG="latest"
NAMESPACE="prod-hello"
POD_NAME="prod-hello-deployment"

echo "=========================================="
echo "ECR Image Pull Troubleshooting"
echo "=========================================="

# Step 1: Check if image exists in ECR
echo ""
echo "[Step 1] Checking if image exists in ECR..."
if aws ecr describe-images \
    --repository-name $REPO_NAME \
    --region $REGION \
    --image-ids imageTag=$IMAGE_TAG 2>/dev/null; then
    echo "✓ Image exists in ECR"
else
    echo "✗ Image does NOT exist in ECR"
    echo ""
    echo "Available images in repository:"
    aws ecr describe-images --repository-name $REPO_NAME --region $REGION || echo "Repository may not exist"
    echo ""
    echo "ACTION REQUIRED: Push your image to ECR first"
    exit 1
fi

# Step 2: Check if repository exists
echo ""
echo "[Step 2] Checking ECR repository..."
if aws ecr describe-repositories \
    --repository-names $REPO_NAME \
    --region $REGION 2>/dev/null; then
    echo "✓ Repository exists"
else
    echo "✗ Repository does NOT exist"
    echo "ACTION REQUIRED: Create the repository first"
    exit 1
fi

# Step 3: Get pod details
echo ""
echo "[Step 3] Getting pod details..."
POD_FULL_NAME=$(kubectl get pods -n $NAMESPACE -l app=prod-hello -o jsonpath='{.items[0].metadata.name}')
echo "Pod name: $POD_FULL_NAME"

# Step 4: Check pod events
echo ""
echo "[Step 4] Checking pod events..."
kubectl describe pod $POD_FULL_NAME -n $NAMESPACE | grep -A 10 "Events:"

# Step 5: Get node information
echo ""
echo "[Step 5] Checking which node the pod is on..."
NODE_NAME=$(kubectl get pod $POD_FULL_NAME -n $NAMESPACE -o jsonpath='{.spec.nodeName}')
echo "Node: $NODE_NAME"

# Step 6: Check node IAM role
echo ""
echo "[Step 6] Checking node IAM role and instance profile..."
INSTANCE_ID=$(kubectl get node $NODE_NAME -o jsonpath='{.spec.providerID}' | cut -d'/' -f5)
echo "Instance ID: $INSTANCE_ID"

INSTANCE_PROFILE=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
    --output text)
echo "Instance Profile: $INSTANCE_PROFILE"

ROLE_NAME=$(echo $INSTANCE_PROFILE | cut -d'/' -f2)
echo "IAM Role: $ROLE_NAME"

# Step 7: Check if role has ECR permissions
echo ""
echo "[Step 7] Checking IAM role policies..."
echo "Checking for AmazonEC2ContainerRegistryReadOnly policy..."
if aws iam list-attached-role-policies \
    --role-name $ROLE_NAME \
    --query "AttachedPolicies[?PolicyName=='AmazonEC2ContainerRegistryReadOnly']" \
    --output text | grep -q "AmazonEC2ContainerRegistryReadOnly"; then
    echo "✓ AmazonEC2ContainerRegistryReadOnly is attached"
else
    echo "✗ AmazonEC2ContainerRegistryReadOnly is NOT attached"
    echo ""
    echo "ACTION REQUIRED: Attach ECR policy to role"
fi

# Step 8: Test ECR authentication from local
echo ""
echo "[Step 8] Testing ECR authentication..."
if aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com 2>/dev/null; then
    echo "✓ ECR authentication successful from your machine"
else
    echo "⚠ Could not authenticate to ECR from your machine"
fi

echo ""
echo "=========================================="
echo "Diagnosis Summary"
echo "=========================================="
echo ""
echo "Common causes of image pull failures:"
echo "1. Node IAM role missing ECR permissions"
echo "2. Image doesn't exist in ECR"
echo "3. Image tag is incorrect"
echo "4. Repository permissions issue"
echo "5. Network connectivity from node to ECR"
echo ""
echo "Recommended fixes below..."
echo ""
