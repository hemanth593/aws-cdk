# Quick Start Guide

## Setup (One-time)

```bash
# 1. Install dependencies
npm install

# 2. Configure AWS credentials (if not already done)
aws configure

# 3. Bootstrap CDK (first time only)
cdk bootstrap
```

## Deploy Everything

```bash
# Option 1: Use the deployment script (recommended)
./deploy.sh

# Option 2: Deploy manually
npm run build
cdk deploy --all
```

## Deploy Individual Stacks

```bash
# Build first
npm run build

# Deploy specific stacks
cdk deploy EksVpcCdkStack
cdk deploy EksClusterRoleStack
cdk deploy EksNodeGroupRoleStack
cdk deploy EksClusterStack
cdk deploy EksLaunchTemplateStack
cdk deploy EksNodeGroupSchedulerStack
cdk deploy EksNodeGroupHelloStack
```

## Access Your Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --name prod-eks-sre-cluster --region us-east-1

# Verify
kubectl get nodes
kubectl get pods --all-namespaces
```

## Common Commands

```bash
# View what will be deployed
cdk synth

# Compare with deployed
cdk diff

# List all stacks
cdk list

# Destroy everything
cdk destroy --all
```

## Prerequisites Checklist

Before deploying, ensure:

- [ ] AWS CLI installed and configured
- [ ] Node.js installed (v18+)
- [ ] IAM role `devops-admins` exists
- [ ] EC2 key pair `prod-eks-sre` exists in us-east-1

## Project Structure

```
.
├── bin/
│   └── eks-cdk.ts              # Main app entry point
├── lib/                         # Stack definitions
│   ├── eks-vpc-cdk-stack.ts
│   ├── eks-admin-policy-stack.ts
│   ├── eks-cluster-role-stack.ts
│   ├── eks-nodegroup-role-stack.ts
│   ├── eks-cluster-stack.ts
│   ├── eks-launch-template-stack.ts
│   ├── eks-nodegroup-scheduler-stack.ts
│   └── eks-nodegroup-hello-stack.ts
├── iam-policy.json             # IAM policy for ALB controller
├── package.json
├── tsconfig.json
├── cdk.json
├── deploy.sh                   # Deployment helper script
└── README.md
```

## Troubleshooting

### Build fails
```bash
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Deployment fails
- Check CloudFormation console for detailed errors
- Ensure prerequisites (IAM role, key pair) exist
- Verify AWS credentials have necessary permissions

### Can't connect to cluster
```bash
# Update kubeconfig
aws eks update-kubeconfig --name prod-eks-sre-cluster --region us-east-1

# Verify AWS credentials
aws sts get-caller-identity
```

## What Gets Deployed

1. **VPC** (192.168.0.0/16)
   - 3 public subnets (us-east-1a/b/c)
   - 3 private subnets (us-east-1a/b/c)
   - NAT Gateway, Internet Gateway

2. **EKS Cluster** (v1.33)
   - Name: prod-eks-sre-cluster
   - Public + Private endpoints
   - Custom security groups

3. **Node Groups**
   - prod-scheduler-v2: 2 nodes (t3a.xlarge)
   - prod-hello-ng: 1 node (t3a.xlarge)
   - Launch template with custom user data

4. **IAM Roles & Policies**
   - Cluster role with EKS policies
   - Node group role with CNI, ECR, SSM policies
   - Admin policy for devops-admins

## Cost Estimate

Approximate monthly costs (us-east-1):
- EKS Cluster: ~$73/month
- 3x t3a.xlarge nodes: ~$240/month
- NAT Gateway: ~$33/month
- Data transfer: Variable
**Total: ~$350-400/month**

## Security Notes

- Cluster has public endpoint (restrict via security groups in production)
- Worker nodes in private subnets
- Security group allows 0.0.0.0/0 for HTTP/MySQL (review and restrict)
- Review IAM policies before production use

## Support

- AWS CDK Docs: https://docs.aws.amazon.com/cdk/
- EKS Best Practices: https://aws.github.io/aws-eks-best-practices/
- Kubernetes Docs: https://kubernetes.io/docs/
