# EKS Infrastructure with AWS CDK (TypeScript)

This project contains AWS CDK code to deploy a complete EKS (Elastic Kubernetes Service) infrastructure in TypeScript.

## Project Structure

```
.
├── bin/
│   └── eks-cdk.ts              # Main CDK app entry point
├── lib/                        # Stack definitions (will be created after build)
│   ├── eks-vpc-cdk-stack.ts
│   ├── eks-admin-policy-stack.ts
│   ├── eks-cluster-role-stack.ts
│   ├── eks-nodegroup-role-stack.ts
│   ├── eks-cluster-stack.ts
│   ├── eks-launch-template-stack.ts
│   ├── eks-nodegroup-scheduler-stack.ts
│   └── eks-nodegroup-hello-stack.ts
├── package.json
├── tsconfig.json
└── cdk.json
```

## Prerequisites

1. **Node.js and npm**: Install Node.js (v18 or later recommended)
2. **AWS CLI**: Configure with your AWS credentials
3. **AWS CDK**: Install globally (optional, as it's included in dev dependencies)

```bash
npm install -g aws-cdk
```

## Setup Instructions

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure AWS Credentials

Make sure your AWS credentials are configured:

```bash
aws configure
```

Or set environment variables:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### 3. Bootstrap CDK (First Time Only)

If you haven't used CDK in your AWS account/region before:

```bash
cdk bootstrap aws://ACCOUNT-ID/REGION
```

Or let CDK detect your account:

```bash
cdk bootstrap
```

## Project Organization

The stack files need to be moved to a `lib/` directory. Run these commands:

```bash
# Create lib directory if it doesn't exist
mkdir -p lib

# Move all stack files to lib directory
mv eks-*.ts lib/
```

## Build the Project

Compile TypeScript to JavaScript:

```bash
npm run build
```

Or watch for changes:

```bash
npm run watch
```

## Deployment

### Synthesize CloudFormation Templates

To see the CloudFormation templates that will be generated:

```bash
npm run synth
# or
cdk synth
```

### Deploy All Stacks

Deploy all stacks in the correct order (dependencies are handled automatically):

```bash
npm run deploy
# or
cdk deploy --all
```

### Deploy Specific Stacks

Deploy individual stacks:

```bash
cdk deploy EksVpcCdkStack
cdk deploy EksClusterRoleStack
cdk deploy EksNodeGroupRoleStack
cdk deploy EksAdminPolicyStack
cdk deploy EksClusterStack
cdk deploy EksLaunchTemplateStack
cdk deploy EksNodeGroupSchedulerStack
cdk deploy EksNodeGroupHelloStack
```

### Deploy with Auto-Approval

Skip confirmation prompts:

```bash
cdk deploy --all --require-approval never
```

## Stack Descriptions

1. **EksVpcCdkStack**: Creates VPC with public/private subnets, NAT Gateway, and Internet Gateway
2. **EksAdminPolicyStack**: Creates IAM policy for EKS admin access (attaches to devops-admins role)
3. **EksClusterRoleStack**: Creates IAM role for EKS cluster control plane
4. **EksNodeGroupRoleStack**: Creates IAM role for EKS worker nodes
5. **EksClusterStack**: Creates the EKS cluster with version 1.33
6. **EksLaunchTemplateStack**: Creates EC2 launch template for worker nodes
7. **EksNodeGroupSchedulerStack**: Creates scheduler node group (2 nodes)
8. **EksNodeGroupHelloStack**: Creates hello node group (1 node)

## Deployment Order

The stacks have dependencies and will be deployed in this order:

```
1. EksVpcCdkStack
2. EksAdminPolicyStack (independent)
3. EksClusterRoleStack (independent)
4. EksNodeGroupRoleStack (independent)
5. EksClusterStack (depends on VPC and Cluster Role)
6. EksLaunchTemplateStack (depends on Cluster)
7. EksNodeGroupSchedulerStack (depends on Cluster, Launch Template, Node Group Role)
8. EksNodeGroupHelloStack (depends on Cluster, Launch Template, Node Group Role)
```

## Important Notes

### Prerequisites Required

Before deploying, ensure these resources exist:

1. **IAM Role**: `devops-admins` (required by EksAdminPolicyStack)
2. **EC2 Key Pair**: `prod-eks-sre` (referenced in launch template)

### Customization

To customize the deployment, edit these values in the respective stack files:

- **Key Pair**: Change `prod-eks-sre` in `eks-launch-template-stack.ts`
- **Instance Type**: Modify `t3a.xlarge` in `eks-launch-template-stack.ts`
- **Node Count**: Adjust scaling config in nodegroup stacks
- **Kubernetes Version**: Update version in `eks-cluster-stack.ts`

## Managing the Infrastructure

### View Stack Outputs

After deployment, view outputs:

```bash
aws cloudformation describe-stacks --stack-name EksClusterStack --query 'Stacks[0].Outputs'
```

### Update Kubernetes Config

After cluster creation, update your kubeconfig:

```bash
aws eks update-kubeconfig --name prod-eks-sre-cluster --region us-east-1
```

### Verify Cluster

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

## Cleanup

### Destroy All Stacks

Remove all resources (this will delete everything):

```bash
npm run destroy
# or
cdk destroy --all
```

### Destroy Specific Stack

```bash
cdk destroy EksNodeGroupHelloStack
```

**Warning**: Always destroy node groups before destroying the cluster.

## Troubleshooting

### Build Errors

If you encounter build errors:

```bash
# Clean and rebuild
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Deployment Failures

Check CloudFormation console for detailed error messages:

```bash
aws cloudformation describe-stack-events --stack-name <STACK-NAME>
```

### CDK Version Mismatch

Ensure all CDK packages are the same version:

```bash
npm list aws-cdk-lib
```

## Additional Commands

```bash
# List all stacks
cdk list

# Compare deployed stack with current state
cdk diff

# View synthesized CloudFormation template
cdk synth EksClusterStack

# View stack metadata
cdk metadata EksClusterStack
```

## AWS Load Balancer Controller

If you need to install the AWS Load Balancer Controller, use the IAM policy provided in `iam-policy.json`:

```bash
# Create IAM policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json
```

## Security Considerations

1. The cluster has both public and private endpoint access enabled
2. Security groups allow traffic from 0.0.0.0/0 for HTTP and MySQL (consider restricting)
3. Review and adjust security group rules based on your requirements
4. Worker nodes are in private subnets for better security

## Support

For issues or questions:
- Check AWS CDK documentation: https://docs.aws.amazon.com/cdk/
- Review EKS best practices: https://aws.github.io/aws-eks-best-practices/

## License

This project is provided as-is for infrastructure deployment.
