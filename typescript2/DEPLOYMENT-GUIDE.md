# Complete EKS Deployment Guide with KMS Encryption and Application

## 🎯 Overview

This guide covers the complete deployment including:
- ✅ KMS envelope encryption for EKS secrets
- ✅ Role mapping (devops-admins → cluster admin)
- ✅ AWS Load Balancer Controller
- ✅ prod-hello application deployment
- ✅ Internal ALB configuration
- ✅ Route53 DNS setup

## 📋 Prerequisites

### Required Tools
```bash
# Node.js v18+
node --version

# AWS CLI
aws --version

# kubectl
kubectl version --client

# helm (for ALB controller)
helm version

# eksctl (for ALB controller)
eksctl version
```

### AWS Resources Required
- ✅ IAM role: `devops-admins` (ARN: arn:aws:iam::575108957879:role/devops-admins)
- ✅ EC2 key pair: `prod-eks-sre` in us-east-1
- ✅ ECR image: `575108957879.dkr.ecr.us-east-1.amazonaws.com/prod-hello:latest`
- ✅ Route53 hosted zone: `pagidh.sre.practice.com`

### Verify Prerequisites
```bash
# Check IAM role
aws iam get-role --role-name devops-admins

# Check EC2 key pair
aws ec2 describe-key-pairs --key-names prod-eks-sre --region us-east-1

# Check ECR image
aws ecr describe-images --repository-name prod-hello --region us-east-1

# Check Route53 hosted zone
aws route53 list-hosted-zones-by-name --dns-name pagidh.sre.practice.com
```

## 🚀 Quick Deployment (Automated)

The easiest way to deploy everything:

```bash
# Extract and enter directory
tar -xzf eks-cdk-typescript.tar.gz
cd eks-cdk-typescript

# Run complete deployment script
./deploy-complete.sh
```

This script will:
1. Deploy all CDK infrastructure with KMS encryption
2. Configure cluster with role mapping
3. Install AWS Load Balancer Controller
4. Deploy prod-hello application
5. Provide instructions for Route53 setup

## 📝 Step-by-Step Manual Deployment

### Phase 1: Deploy Infrastructure

```bash
# 1. Install dependencies
npm install

# 2. Build project
npm run build

# 3. Bootstrap CDK (first time only)
cdk bootstrap

# 4. Deploy all stacks
cdk deploy --all
```

**Stacks deployed:**
1. **EksKmsKeyStack** - KMS key for envelope encryption
2. **EksVpcCdkStack** - VPC with subnets
3. **EksAdminPolicyStack** - Admin IAM policy
4. **EksClusterRoleStack** - Cluster IAM role
5. **EksNodeGroupRoleStack** - Node group IAM role
6. **EksClusterStack** - EKS cluster (with KMS encryption)
7. **EksLaunchTemplateStack** - Launch template
8. **EksNodeGroupSchedulerStack** - Scheduler node group
9. **EksNodeGroupHelloStack** - Hello node group

### Phase 2: Configure Cluster Access

```bash
# 1. Update kubeconfig
aws eks update-kubeconfig --name prod-eks-sre-cluster --region us-east-1

# 2. Apply aws-auth ConfigMap (enables role mapping)
kubectl apply -f kubernetes/aws-auth-configmap.yaml

# 3. Verify cluster access
kubectl get nodes

# 4. Verify you have admin access
kubectl auth can-i '*' '*'
```

**What the aws-auth ConfigMap does:**
- Maps `devops-admins` IAM role → `system:masters` Kubernetes group
- Maps node IAM role → allows nodes to join cluster
- Gives you full cluster admin permissions via your IAM role

### Phase 3: Install AWS Load Balancer Controller

```bash
# Run the installation script
./install-alb-controller.sh
```

**What this does:**
1. Creates IAM policy for ALB controller
2. Creates IAM service account using IRSA
3. Installs controller via Helm
4. Verifies installation

**Manual installation steps:**
```bash
# Create IAM policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json

# Create IAM service account
eksctl create iamserviceaccount \
  --cluster=prod-eks-sre-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::575108957879:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region=us-east-1

# Add helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=prod-eks-sre-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1

# Verify
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Phase 4: Deploy prod-hello Application

```bash
# Deploy all manifests
kubectl apply -f kubernetes/

# Or deploy individually
kubectl apply -f kubernetes/00-namespace.yaml
kubectl apply -f kubernetes/01-deployment.yaml
kubectl apply -f kubernetes/02-service.yaml
kubectl apply -f kubernetes/03-ingress.yaml
```

**What gets deployed:**
- **Namespace**: `prod-hello`
- **Deployment**: 2 replicas of prod-hello app
  - Image: `575108957879.dkr.ecr.us-east-1.amazonaws.com/prod-hello:latest`
  - NodeSelector: `eks.amazonaws.com/nodegroup: prod-hello-ng`
  - Resources: 128Mi-256Mi RAM, 100m-200m CPU
- **Service**: NodePort service on port 80
- **Ingress**: Internal ALB with hostname `pagidh.sre.practice.com`

**Verify deployment:**
```bash
# Check namespace
kubectl get namespace prod-hello

# Check pods
kubectl get pods -n prod-hello

# Check service
kubectl get svc -n prod-hello

# Check ingress
kubectl get ingress -n prod-hello

# View pod logs
kubectl logs -f deployment/prod-hello-deployment -n prod-hello
```

### Phase 5: Configure Route53

```bash
# 1. Get ALB DNS name
ALB_DNS=$(kubectl get ingress prod-hello-ingress -n prod-hello -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB DNS: $ALB_DNS"

# 2. Get Hosted Zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name pagidh.sre.practice.com \
  --query 'HostedZones[0].Id' \
  --output text)
echo "Hosted Zone ID: $HOSTED_ZONE_ID"

# 3. Get ALB Hosted Zone ID
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(DNSName, \`$ALB_DNS\`)].CanonicalHostedZoneId" \
  --output text)
echo "ALB Zone ID: $ALB_ZONE_ID"

# 4. Create Route53 change batch
cat > route53-change.json <<EOF
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "pagidh.sre.practice.com",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "$ALB_ZONE_ID",
        "DNSName": "$ALB_DNS",
        "EvaluateTargetHealth": false
      }
    }
  }]
}
EOF

# 5. Apply the change
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file://route53-change.json

# 6. Verify DNS propagation (may take a few minutes)
dig pagidh.sre.practice.com
```

## 🔍 Verification Steps

### 1. Check Infrastructure
```bash
# List all stacks
cdk list

# Check stack outputs
aws cloudformation describe-stacks --stack-name EksKmsKeyStack
aws cloudformation describe-stacks --stack-name EksClusterStack
```

### 2. Verify KMS Encryption
```bash
# Check cluster encryption config
aws eks describe-cluster --name prod-eks-sre-cluster \
  --query 'cluster.encryptionConfig' \
  --output json

# Verify KMS key
aws kms describe-key --key-id alias/eks-prod-sre-cluster
```

### 3. Verify Cluster Access
```bash
# Check current context
kubectl config current-context

# Test admin permissions
kubectl auth can-i create deployments --all-namespaces
kubectl auth can-i delete nodes

# View nodes
kubectl get nodes -o wide

# Check node group labels
kubectl get nodes --show-labels | grep nodegroup
```

### 4. Verify Application
```bash
# Check deployment
kubectl get deployment -n prod-hello
kubectl describe deployment prod-hello-deployment -n prod-hello

# Check pods are on correct nodes
kubectl get pods -n prod-hello -o wide

# Check pod logs
kubectl logs -l app=prod-hello -n prod-hello --tail=50

# Test service internally
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://prod-hello-service.prod-hello.svc.cluster.local
```

### 5. Verify Load Balancer
```bash
# Check ingress
kubectl get ingress prod-hello-ingress -n prod-hello
kubectl describe ingress prod-hello-ingress -n prod-hello

# Get ALB details
ALB_DNS=$(kubectl get ingress prod-hello-ingress -n prod-hello -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Check ALB in AWS console or CLI
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(DNSName, \`$ALB_DNS\`)]"

# Check target groups
aws elbv2 describe-target-groups --query "TargetGroups[?contains(LoadBalancerArns[0], 'prod-hello')]"

# Check target health
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
  --query "TargetGroups[?contains(LoadBalancerArns[0], 'prod-hello')].TargetGroupArn" \
  --output text)
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN
```

### 6. Test Application Access
```bash
# Test via ALB DNS (internal - requires VPN/bastion)
curl http://$ALB_DNS

# Test via Route53 domain (internal - requires VPN/bastion)
curl http://pagidh.sre.practice.com

# Test with headers
curl -H "Host: pagidh.sre.practice.com" http://$ALB_DNS
```

## 🔧 Configuration Details

### KMS Encryption
- **Key Alias**: `alias/eks-prod-sre-cluster`
- **Encryption**: Secrets only (envelope encryption)
- **Key Rotation**: Enabled
- **Permissions**: 
  - Admin: devops-admins role
  - EKS service
  - Cluster role
  - Node group role (decrypt only)

### Role Mapping
```yaml
# devops-admins role → system:masters
- rolearn: arn:aws:iam::575108957879:role/devops-admins
  username: devops-admin
  groups:
    - system:masters

# Node role → system:nodes
- rolearn: arn:aws:iam::575108957879:role/prod-sre-workernode-role
  username: system:node:{{EC2PrivateDNSName}}
  groups:
    - system:bootstrappers
    - system:nodes
```

### Application Configuration
- **Image**: `575108957879.dkr.ecr.us-east-1.amazonaws.com/prod-hello:latest`
- **Node Group**: `prod-hello-ng` (1 node, t3a.xlarge)
- **Replicas**: 2 pods
- **Resources**: 128-256Mi RAM, 100-200m CPU
- **Port**: 80
- **Health Checks**: HTTP on /

### Load Balancer Configuration
- **Type**: Internal Application Load Balancer
- **Scheme**: internal
- **Target Type**: IP (required for Fargate/pod IPs)
- **Subnets**: Private subnets only
- **Health Check**: HTTP on / every 15s
- **Stickiness**: Enabled (1 hour)
- **Hostname**: pagidh.sre.practice.com

## 🐛 Troubleshooting

### Pods not starting
```bash
# Check pod status
kubectl get pods -n prod-hello
kubectl describe pod <pod-name> -n prod-hello

# Check events
kubectl get events -n prod-hello --sort-by='.lastTimestamp'

# Check if image can be pulled
kubectl run test --image=575108957879.dkr.ecr.us-east-1.amazonaws.com/prod-hello:latest --dry-run=client -o yaml | kubectl apply -f -
```

### Pods not scheduling on prod-hello-ng
```bash
# Check node labels
kubectl get nodes --show-labels | grep prod-hello

# Check nodeSelector in deployment
kubectl get deployment prod-hello-deployment -n prod-hello -o yaml | grep -A 5 nodeSelector

# Check if nodes have taints
kubectl describe node <node-name> | grep Taints
```

### ALB not created
```bash
# Check ingress status
kubectl describe ingress prod-hello-ingress -n prod-hello

# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check service account
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml

# Verify IAM role annotation
kubectl get sa aws-load-balancer-controller -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
```

### Cannot access cluster
```bash
# Update kubeconfig
aws eks update-kubeconfig --name prod-eks-sre-cluster --region us-east-1

# Check aws-auth ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml

# Verify your IAM identity
aws sts get-caller-identity

# Re-apply aws-auth if needed
kubectl apply -f kubernetes/aws-auth-configmap.yaml
```

### DNS not resolving
```bash
# Check Route53 record
aws route53 list-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --query "ResourceRecordSets[?Name=='pagidh.sre.practice.com.']"

# Test DNS resolution
dig pagidh.sre.practice.com
nslookup pagidh.sre.practice.com

# Check ALB DNS
kubectl get ingress prod-hello-ingress -n prod-hello -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## 🧹 Cleanup

### Delete Application
```bash
kubectl delete -f kubernetes/
```

### Delete ALB Controller
```bash
helm uninstall aws-load-balancer-controller -n kube-system
eksctl delete iamserviceaccount \
  --cluster=prod-eks-sre-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --region=us-east-1
```

### Delete Infrastructure
```bash
cdk destroy --all
```

### Delete Route53 Record
```bash
# Create delete change batch
cat > route53-delete.json <<EOF
{
  "Changes": [{
    "Action": "DELETE",
    "ResourceRecordSet": {
      "Name": "pagidh.sre.practice.com",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "$ALB_ZONE_ID",
        "DNSName": "$ALB_DNS",
        "EvaluateTargetHealth": false
      }
    }
  }]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file://route53-delete.json
```

## 📊 Cost Estimate

| Component | Quantity | Monthly Cost (us-east-1) |
|-----------|----------|-------------------------|
| EKS Cluster | 1 | $73 |
| t3a.xlarge nodes | 3 | $240 |
| NAT Gateway | 1 | $33 |
| Internal ALB | 1 | $23 |
| KMS Key | 1 | $1 |
| EBS Volumes (gp3) | 3 × 70GB | $21 |
| Data Transfer | Variable | $10-50 |
| **Total** | | **~$401-441** |

## 🔐 Security Considerations

1. **KMS Encryption**: All Kubernetes secrets encrypted at rest
2. **Role-based Access**: IAM roles mapped to Kubernetes RBAC
3. **Private Subnets**: Worker nodes in private subnets
4. **Internal ALB**: ALB not accessible from internet
5. **Network Policies**: Consider adding network policies
6. **Pod Security**: Consider Pod Security Standards/Admission

## 📚 Additional Resources

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [KMS Envelope Encryption](https://docs.aws.amazon.com/eks/latest/userguide/enable-kms.html)
- [EKS IAM Roles](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

---

**Ready to deploy?** Run `./deploy-complete.sh` to get started! 🚀
