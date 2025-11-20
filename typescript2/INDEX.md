# 📁 EKS CDK TypeScript Project - File Index

## 🎯 Start Here

1. **[QUICK-REFERENCE.md](QUICK-REFERENCE.md)** - Quick commands and setup
2. **[QUICKSTART.md](QUICKSTART.md)** - Step-by-step deployment guide
3. **[README.md](README.md)** - Complete documentation
4. **[PROJECT-SUMMARY.md](PROJECT-SUMMARY.md)** - Conversion details and notes

## 📦 Complete Package

**[eks-cdk-typescript.tar.gz](eks-cdk-typescript.tar.gz)** - Ready-to-deploy archive

Extract with:
```bash
tar -xzf eks-cdk-typescript.tar.gz
cd eks-cdk-typescript
```

## 📂 Project Structure

### 🔧 Configuration Files

| File | Description |
|------|-------------|
| **package.json** | Node.js dependencies and scripts |
| **tsconfig.json** | TypeScript compiler configuration |
| **cdk.json** | CDK app configuration |
| **.gitignore** | Git ignore patterns |
| **iam-policy.json** | IAM policy for AWS Load Balancer Controller |

### 🚀 Deployment

| File | Description |
|------|-------------|
| **deploy.sh** | Interactive deployment script (recommended) |

### 📝 Stack Files (lib/)

| File | Stack Name | Purpose |
|------|-----------|---------|
| **eks-vpc-cdk-stack.ts** | EksVpcCdkStack | VPC with public/private subnets |
| **eks-admin-policy-stack.ts** | EksAdminPolicyStack | IAM policy for admin access |
| **eks-cluster-role-stack.ts** | EksClusterRoleStack | IAM role for cluster |
| **eks-nodegroup-role-stack.ts** | EksNodeGroupRoleStack | IAM role for worker nodes |
| **eks-cluster-stack.ts** | EksClusterStack | EKS cluster (v1.33) |
| **eks-launch-template-stack.ts** | EksLaunchTemplateStack | EC2 launch template |
| **eks-nodegroup-scheduler-stack.ts** | EksNodeGroupSchedulerStack | Scheduler node group (2 nodes) |
| **eks-nodegroup-hello-stack.ts** | EksNodeGroupHelloStack | Hello node group (1 node) |

### 🎯 Application Entry Point (bin/)

| File | Description |
|------|-------------|
| **eks-cdk.ts** | Main CDK app - instantiates all stacks |

## 🚀 Quick Deployment

```bash
# Extract
tar -xzf eks-cdk-typescript.tar.gz
cd eks-cdk-typescript

# Install & Build
npm install
npm run build

# Bootstrap (first time)
cdk bootstrap

# Deploy
./deploy.sh
# OR
cdk deploy --all
```

## 📊 Stack Dependencies

```
┌─────────────────────┐
│   EksVpcCdkStack    │
└──────────┬──────────┘
           │
           ├──────────────────────────────────┐
           │                                  │
┌──────────▼──────────┐          ┌───────────▼──────────┐
│ EksClusterRoleStack │          │EksNodeGroupRoleStack │
└──────────┬──────────┘          └───────────┬──────────┘
           │                                  │
           ├──────────────────────────────────┤
           │                                  │
    ┌──────▼──────────┐                      │
    │ EksClusterStack │                      │
    └──────┬──────────┘                      │
           │                                  │
    ┌──────▼────────────────┐                │
    │EksLaunchTemplateStack │                │
    └──────┬────────────────┘                │
           │                                  │
           ├──────────────────────────────────┤
           │                                  │
┌──────────▼───────────────┐    ┌────────────▼──────────┐
│EksNodeGroupSchedulerStack│    │EksNodeGroupHelloStack │
└──────────────────────────┘    └───────────────────────┘
```

**Note**: EksAdminPolicyStack is independent and can deploy anytime

## 🔍 What Each Stack Creates

### 1. EksVpcCdkStack
- VPC: 192.168.0.0/16
- 3 Public Subnets (us-east-1a/b/c)
- 3 Private Subnets (us-east-1a/b/c)
- Internet Gateway
- NAT Gateway
- Route Tables

### 2. EksAdminPolicyStack
- IAM Policy: AdminRoleEKSClusterPolicy
- Attaches to: devops-admins role
- Permissions: eks:*

### 3. EksClusterRoleStack
- IAM Role: prod-sre-eks-cluster-role
- Managed Policies:
  - AmazonEKSClusterPolicy
  - AmazonEKSVPCResourceController
- Inline Policy: CloudWatch metrics

### 4. EksNodeGroupRoleStack
- IAM Role: prod-sre-workernode-role
- Managed Policies:
  - AmazonEC2ContainerRegistryReadOnly
  - AmazonEKS_CNI_Policy
  - AmazonEKSWorkerNodePolicy
  - AmazonSSMManagedInstanceCore
  - AmazonSSMPatchAssociation
- Inline Policies:
  - WAF permissions
  - EC2 tags
  - CloudWatch metrics

### 5. EksClusterStack
- EKS Cluster: prod-eks-sre-cluster
- Version: 1.33
- Endpoints: Public + Private
- Service CIDR: 10.100.0.0/16
- Security Groups: Custom + Primary

### 6. EksLaunchTemplateStack
- Template: prod-scheduler-v2-lt
- Instance: t3a.xlarge
- Storage: 70GB gp3 (3000 IOPS, 125 throughput)
- Key Pair: prod-eks-sre
- User Data: Hostname tagging script

### 7. EksNodeGroupSchedulerStack
- Node Group: prod-scheduler-v2
- Nodes: 2 (min: 1, max: 2)
- AMI: AL2023_x86_64_STANDARD
- Subnets: Private only

### 8. EksNodeGroupHelloStack
- Node Group: prod-hello-ng
- Nodes: 1 (fixed)
- AMI: AL2023_x86_64_STANDARD
- Subnets: Private only
- Custom Security Group

## 💰 Cost Breakdown

| Component | Quantity | Monthly Cost (us-east-1) |
|-----------|----------|-------------------------|
| EKS Cluster | 1 | ~$73 |
| t3a.xlarge instances | 3 | ~$240 |
| NAT Gateway | 1 | ~$33 |
| EBS Volumes (gp3) | 3 × 70GB | ~$21 |
| Data Transfer | Variable | $10-50 |
| **Total** | | **~$377-417** |

## 🔐 Prerequisites Checklist

Before deployment, verify:

- [ ] AWS CLI installed and configured
- [ ] Node.js v18+ installed
- [ ] AWS credentials with admin permissions
- [ ] IAM role `devops-admins` exists
- [ ] EC2 key pair `prod-eks-sre` exists in us-east-1
- [ ] CDK bootstrapped in target account/region

Check prerequisites:
```bash
# AWS CLI
aws --version

# Node.js
node --version

# AWS Credentials
aws sts get-caller-identity

# IAM Role
aws iam get-role --role-name devops-admins

# Key Pair
aws ec2 describe-key-pairs --key-names prod-eks-sre --region us-east-1
```

## 🛠️ Available npm Scripts

```bash
npm run build      # Compile TypeScript
npm run watch      # Watch mode for development
npm run test       # Run tests
npm run cdk        # Run CDK commands
npm run deploy     # Deploy all stacks
npm run destroy    # Destroy all stacks
npm run synth      # Synthesize CloudFormation
```

## 📞 Support & Documentation

- **AWS CDK**: https://docs.aws.amazon.com/cdk/
- **EKS**: https://docs.aws.amazon.com/eks/
- **Kubernetes**: https://kubernetes.io/docs/
- **TypeScript**: https://www.typescriptlang.org/docs/

## 🎓 Learning Resources

- [CDK Workshop (TypeScript)](https://cdkworkshop.com/40-typescript.html)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS CDK Examples](https://github.com/aws-samples/aws-cdk-examples)

## ⚠️ Important Notes

1. **Region**: All resources deploy to us-east-1 by default
2. **Security**: Review security groups before production use
3. **Costs**: Monitor AWS billing dashboard
4. **Cleanup**: Always run `cdk destroy --all` to avoid ongoing charges
5. **Updates**: Keep CDK and AWS CLI updated

## 📝 Version Information

- **CDK Version**: 2.170.0
- **Kubernetes Version**: 1.33
- **Node.js Runtime**: ES2020
- **TypeScript**: ~5.3.3
- **Default Region**: us-east-1

---

## 🚀 Ready to Deploy?

1. Read **QUICK-REFERENCE.md** for commands
2. Follow **QUICKSTART.md** for step-by-step
3. Run `./deploy.sh` for interactive deployment
4. Check **README.md** for troubleshooting

**Good luck with your EKS deployment!** 🎉
