# EKS Prod-Hello Deployment Guide

This guide provides instructions for deploying the new `prod-hello` node group, application, and internal ALB to your existing EKS cluster.

## Overview

The deployment includes:
1. **New Node Group**: `prod-hello-ng` with 1 node and dedicated security group
2. **Kubernetes Namespace**: `prod-hello` 
3. **Application Deployment**: Running your ECR image `575108957879.dkr.ecr.us-east-1.amazonaws.com/hello/swatops13032:latest`
4. **Internal ALB**: `prod-eks-sre-hello-alb` with its own security group
5. **AWS Load Balancer Controller**: For automatic ALB provisioning via Ingress

## New CDK Stacks Created

- `eks_nodegroup_hello.py` - Creates the prod-hello-ng node group with dedicated security group
- `eks_alb.py` - Creates the internal ALB and security group (alternative to Ingress-based approach)
- `eks_k8s_resources.py` - Outputs Kubernetes manifests for reference

## Prerequisites

1. Existing EKS cluster and infrastructure deployed
2. AWS CLI configured
3. kubectl installed
4. eksctl installed
5. Helm 3 installed
6. Appropriate AWS permissions

## Deployment Steps

### Step 1: Update app.py

Replace your current `app.py` with the updated version:

```bash
cp app_updated.py app.py
```

Or manually add these imports and stacks to your existing `app.py`:

```python
from eks_vpc_cdk.eks_nodegroup_hello import EksNodeGroupHelloStack
from eks_vpc_cdk.eks_k8s_resources import EksK8sResourcesStack
from eks_vpc_cdk.eks_alb import EksAlbStack

# Add after the existing nodegroup_stack:
nodegroup_hello_stack = EksNodeGroupHelloStack(
    app, "EksNodeGroupHelloStack",
    vpc_stack=vpc_stack,
    eks_cluster_stack=eks_cluster_stack,
    launch_template_stack=launch_template_stack
)
nodegroup_hello_stack.add_dependency(vpc_stack)
nodegroup_hello_stack.add_dependency(cluster_role_stack)
nodegroup_hello_stack.add_dependency(nodegroup_role_stack)
nodegroup_hello_stack.add_dependency(admin_policy_stack)
nodegroup_hello_stack.add_dependency(eks_cluster_stack)
nodegroup_hello_stack.add_dependency(launch_template_stack)

k8s_resources_stack = EksK8sResourcesStack(
    app, "EksK8sResourcesStack",
    eks_cluster_stack=eks_cluster_stack
)
k8s_resources_stack.add_dependency(eks_cluster_stack)
k8s_resources_stack.add_dependency(nodegroup_hello_stack)

alb_stack = EksAlbStack(
    app, "EksAlbStack",
    vpc_stack=vpc_stack
)
alb_stack.add_dependency(vpc_stack)
alb_stack.add_dependency(nodegroup_hello_stack)
```

### Step 2: Copy New Stack Files

Copy the new stack files to your CDK project directory:

```bash
# Assuming your project structure is eks_vpc_cdk/
cp eks_nodegroup_hello.py eks_vpc_cdk/
cp eks_k8s_resources.py eks_vpc_cdk/
cp eks_alb.py eks_vpc_cdk/
```

### Step 3: Deploy CDK Stacks

Deploy the new stacks:

```bash
# Bootstrap if not already done
cdk bootstrap

# Synthesize to check for errors
cdk synth

# Deploy only the new stacks
cdk deploy EksNodeGroupHelloStack
cdk deploy EksK8sResourcesStack
cdk deploy EksAlbStack

# Or deploy all at once
cdk deploy --all
```

### Step 4: Configure kubectl

Update your kubeconfig to access the cluster:

```bash
aws eks update-kubeconfig --name prod-eks-sre-cluster --region us-east-1
```

Verify connectivity:

```bash
kubectl get nodes
```

### Step 5: Deploy Application Using AWS Load Balancer Controller (Recommended)

The AWS Load Balancer Controller automatically creates and manages the ALB based on Kubernetes Ingress resources.

#### Option A: Automated Deployment Script

Make the deployment script executable and run it:

```bash
chmod +x deploy-prod-hello.sh
./deploy-prod-hello.sh
```

This script will:
- Set up IAM OIDC provider
- Install AWS Load Balancer Controller
- Deploy the application and create the ALB via Ingress

#### Option B: Manual Deployment

1. **Set up IAM OIDC provider:**

```bash
eksctl utils associate-iam-oidc-provider \
    --region=us-east-1 \
    --cluster=prod-eks-sre-cluster \
    --approve
```

2. **Create IAM policy for AWS Load Balancer Controller:**

```bash
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.8.1/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json
```

3. **Create service account:**

```bash
eksctl create iamserviceaccount \
    --cluster=prod-eks-sre-cluster \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::575108957879:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --region=us-east-1 \
    --approve
```

4. **Install AWS Load Balancer Controller:**

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=prod-eks-sre-cluster \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=us-east-1
```

5. **Wait for controller to be ready:**

```bash
kubectl wait --namespace kube-system \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=aws-load-balancer-controller \
    --timeout=120s
```

6. **Apply Kubernetes manifests:**

```bash
kubectl apply -f kubernetes-manifests.yaml
```

### Step 6: Verify Deployment

1. **Check node group:**

```bash
kubectl get nodes -l eks.amazonaws.com/nodegroup=prod-hello-ng
```

2. **Check namespace:**

```bash
kubectl get namespace prod-hello
```

3. **Check pods:**

```bash
kubectl get pods -n prod-hello
kubectl describe pod -n prod-hello
```

4. **Check service:**

```bash
kubectl get svc -n prod-hello
```

5. **Check ingress and ALB:**

```bash
kubectl get ingress -n prod-hello
kubectl describe ingress prod-hello-ingress -n prod-hello
```

6. **Get ALB DNS name:**

```bash
ALB_DNS=$(kubectl get ingress prod-hello-ingress -n prod-hello -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $ALB_DNS
```

### Step 7: Test the Application

Since the ALB is internal, you need to test from within the VPC:

**Option 1: From an EC2 instance in the VPC:**

```bash
curl http://$ALB_DNS
```

**Option 2: From a pod in the cluster:**

```bash
kubectl run test-curl --image=curlimages/curl -i --rm --restart=Never -- curl http://$ALB_DNS
```

**Option 3: Using kubectl port-forward (for testing):**

```bash
kubectl port-forward -n prod-hello svc/prod-hello-service 8080:80
# Then in another terminal:
curl http://localhost:8080
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                          VPC (192.168.0.0/16)                │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Private Subnets                           │  │
│  │                                                         │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Internal ALB (prod-eks-sre-hello-alb)         │  │  │
│  │  │  Security Group: prod-eks-sre-hello-alb-sg     │  │  │
│  │  │  Port: 80                                       │  │  │
│  │  └──────────────────┬──────────────────────────────┘  │  │
│  │                     │                                   │  │
│  │                     │ Forwards to                       │  │
│  │                     ▼                                   │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  EKS Pods (prod-hello namespace)               │  │  │
│  │  │  Image: 575108957879.dkr.ecr.../swatops13032   │  │  │
│  │  │  Port: 80                                       │  │  │
│  │  │                                                 │  │  │
│  │  │  Running on Node Group: prod-hello-ng          │  │  │
│  │  │  Security Group: prod-hello-ng-sg              │  │  │
│  │  │  Launch Template: prod-scheduler-v2-lt         │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Pods not starting

```bash
kubectl describe pod -n prod-hello
kubectl logs -n prod-hello <pod-name>
```

Check if the image can be pulled:
```bash
# Ensure the node has permissions to pull from ECR
kubectl describe node <node-name>
```

### ALB not created

```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check ingress events
kubectl describe ingress prod-hello-ingress -n prod-hello
```

### Cannot access ALB

1. Verify ALB is created:
```bash
aws elbv2 describe-load-balancers --names prod-eks-sre-hello-alb
```

2. Check security group rules:
```bash
# Get security group ID
aws elbv2 describe-load-balancers --names prod-eks-sre-hello-alb --query 'LoadBalancers[0].SecurityGroups' --output text

# Describe security group rules
aws ec2 describe-security-groups --group-ids <sg-id>
```

3. Ensure you're testing from within the VPC (it's an internal ALB)

### Node not joining node group

```bash
# Check node group status
aws eks describe-nodegroup --cluster-name prod-eks-sre-cluster --nodegroup-name prod-hello-ng

# Check launch template
aws ec2 describe-launch-template-versions --launch-template-name prod-scheduler-v2-lt
```

## Cleanup

To remove the resources:

```bash
# Delete Kubernetes resources
kubectl delete -f kubernetes-manifests.yaml

# Delete CDK stacks
cdk destroy EksAlbStack
cdk destroy EksK8sResourcesStack
cdk destroy EksNodeGroupHelloStack
```

## Notes

- The ALB is **internal** (not internet-facing), so it can only be accessed from within the VPC
- The node group uses the same launch template as `prod-scheduler-v2`
- Pods are scheduled specifically on the `prod-hello-ng` node group using node selectors
- The AWS Load Balancer Controller automatically manages the ALB lifecycle based on the Ingress resource

## Support

For issues or questions:
1. Check CloudFormation stack events in AWS Console
2. Review CDK synthesis output: `cdk synth`
3. Check EKS cluster logs in CloudWatch
4. Review AWS Load Balancer Controller logs
