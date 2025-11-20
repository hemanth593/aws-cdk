# 🚀 EKS CDK TypeScript - Quick Reference Card

## 📦 Initial Setup

```bash
# 1. Extract and enter directory
tar -xzf eks-cdk-typescript.tar.gz
cd eks-cdk-typescript

# 2. Install dependencies
npm install

# 3. Build project
npm run build

# 4. Bootstrap CDK (first time only)
cdk bootstrap
```

## 🚢 Deploy Everything

```bash
# Interactive deployment (recommended)
./deploy.sh

# Or deploy all at once
cdk deploy --all

# Or with auto-approval
cdk deploy --all --require-approval never
```

## 🎯 Deploy Specific Stacks

```bash
# Deploy in order
cdk deploy EksVpcCdkStack
cdk deploy EksClusterRoleStack
cdk deploy EksNodeGroupRoleStack
cdk deploy EksAdminPolicyStack
cdk deploy EksClusterStack
cdk deploy EksLaunchTemplateStack
cdk deploy EksNodeGroupSchedulerStack
cdk deploy EksNodeGroupHelloStack
```

## 🔍 Useful Commands

```bash
# View stacks
cdk list

# See what will change
cdk diff

# View CloudFormation template
cdk synth EksClusterStack

# Watch for changes and rebuild
npm run watch
```

## ☸️ Access Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --name prod-eks-sre-cluster --region us-east-1

# Verify nodes
kubectl get nodes

# Check all resources
kubectl get all --all-namespaces
```

## 🗑️ Cleanup

```bash
# Destroy everything
cdk destroy --all

# Or use script
npm run destroy
```

## 📋 Prerequisites Checklist

- [ ] Node.js v18+ installed
- [ ] AWS CLI configured
- [ ] IAM role `devops-admins` exists
- [ ] EC2 key pair `prod-eks-sre` exists in us-east-1
- [ ] CDK bootstrapped in target account/region

## 🏗️ What Gets Created

| Resource | Name | Details |
|----------|------|---------|
| VPC | eks-vpc | 192.168.0.0/16 |
| EKS Cluster | prod-eks-sre-cluster | v1.33, IPv4 |
| Node Group 1 | prod-scheduler-v2 | 2x t3a.xlarge |
| Node Group 2 | prod-hello-ng | 1x t3a.xlarge |
| Launch Template | prod-scheduler-v2-lt | 70GB gp3, custom user data |

## 💰 Estimated Cost

~$350-400/month (us-east-1)
- EKS Cluster: $73/mo
- 3x t3a.xlarge: $240/mo
- NAT Gateway: $33/mo
- Data Transfer: Variable

## 🔧 Quick Customizations

### Change Key Pair
Edit `lib/eks-launch-template-stack.ts`:
```typescript
const keyPairName = 'your-key-name';
```

### Change Instance Type
Edit `lib/eks-launch-template-stack.ts`:
```typescript
instanceType: 't3a.2xlarge',  // or any type
```

### Change Node Count
Edit `lib/eks-nodegroup-scheduler-stack.ts` or `eks-nodegroup-hello-stack.ts`:
```typescript
scalingConfig: {
  desiredSize: 3,
  minSize: 2,
  maxSize: 5,
}
```

## 🆘 Troubleshooting

### Build fails
```bash
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Deployment fails
```bash
# Check CloudFormation events
aws cloudformation describe-stack-events --stack-name EksClusterStack

# Verify prerequisites
aws iam get-role --role-name devops-admins
aws ec2 describe-key-pairs --key-names prod-eks-sre
```

### Can't connect to cluster
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Re-update kubeconfig
aws eks update-kubeconfig --name prod-eks-sre-cluster --region us-east-1

# Check cluster status
kubectl cluster-info
```

## 📚 Documentation Files

- **README.md** - Full documentation
- **QUICKSTART.md** - Quick start guide  
- **PROJECT-SUMMARY.md** - Conversion details
- **THIS FILE** - Quick reference

## 🔗 Useful Links

- [AWS CDK Docs](https://docs.aws.amazon.com/cdk/)
- [EKS User Guide](https://docs.aws.amazon.com/eks/)
- [CDK TypeScript API](https://docs.aws.amazon.com/cdk/api/v2/)

## 💡 Pro Tips

1. Use `npm run watch` during development
2. Run `cdk diff` before deploying changes
3. Use `--require-approval never` for CI/CD
4. Enable CloudWatch Container Insights for monitoring
5. Tag resources for cost tracking
6. Keep CDK version consistent across team

---

**Need Help?** Check PROJECT-SUMMARY.md for detailed information!
