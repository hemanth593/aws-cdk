#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { EksVpcCdkStack } from '../lib/eks-vpc-cdk-stack';
import { EksKmsKeyStack } from '../lib/eks-kms-key-stack';
import { EksAdminPolicyStack } from '../lib/eks-admin-policy-stack';
import { EksClusterRoleStack } from '../lib/eks-cluster-role-stack';
import { EksNodeGroupRoleStack } from '../lib/eks-nodegroup-role-stack';
import { EksClusterStack } from '../lib/eks-cluster-stack';
import { EksLaunchTemplateStack } from '../lib/eks-launch-template-stack';
import { EksNodeGroupSchedulerStack } from '../lib/eks-nodegroup-scheduler-stack';
import { EksNodeGroupHelloStack } from '../lib/eks-nodegroup-hello-stack';

const app = new cdk.App();

// Set the AWS environment (update with your account and region)
const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT || '575108957879',
  region: process.env.CDK_DEFAULT_REGION || 'us-east-1',
};

// 1. Create KMS Key Stack (for envelope encryption)
const kmsKeyStack = new EksKmsKeyStack(app, 'EksKmsKeyStack', {
  env: env,
  description: 'KMS key for EKS cluster envelope encryption',
});

// 2. Create VPC Stack
const vpcStack = new EksVpcCdkStack(app, 'EksVpcCdkStack', {
  env: env,
  description: 'VPC infrastructure for EKS cluster',
});

// 3. Create Admin Policy Stack (for devops-admin role)
const adminPolicyStack = new EksAdminPolicyStack(app, 'EksAdminPolicyStack', {
  env: env,
  description: 'IAM policy for EKS admin access',
});

// 4. Create EKS Cluster Role Stack
const clusterRoleStack = new EksClusterRoleStack(app, 'EksClusterRoleStack', {
  env: env,
  description: 'IAM role for EKS cluster',
});

// 5. Create EKS Node Group Role Stack
const nodeGroupRoleStack = new EksNodeGroupRoleStack(
  app,
  'EksNodeGroupRoleStack',
  {
    env: env,
    description: 'IAM role for EKS worker nodes',
  }
);

// 6. Create EKS Cluster Stack with KMS encryption (depends on VPC, Cluster Role, and KMS Key)
const clusterStack = new EksClusterStack(app, 'EksClusterStack', vpcStack, kmsKeyStack, {
  env: env,
  description: 'EKS cluster configuration with KMS envelope encryption',
});
clusterStack.addDependency(vpcStack);
clusterStack.addDependency(clusterRoleStack);
clusterStack.addDependency(kmsKeyStack);

// 7. Create Launch Template Stack (depends on Cluster)
const launchTemplateStack = new EksLaunchTemplateStack(
  app,
  'EksLaunchTemplateStack',
  clusterStack,
  {
    env: env,
    description: 'Launch template for EKS worker nodes',
  }
);
launchTemplateStack.addDependency(clusterStack);

// 8. Create Scheduler Node Group Stack (depends on Cluster, Launch Template, and Node Group Role)
const schedulerNodeGroupStack = new EksNodeGroupSchedulerStack(
  app,
  'EksNodeGroupSchedulerStack',
  vpcStack,
  clusterStack,
  launchTemplateStack,
  {
    env: env,
    description: 'EKS node group for scheduler workloads',
  }
);
schedulerNodeGroupStack.addDependency(clusterStack);
schedulerNodeGroupStack.addDependency(launchTemplateStack);
schedulerNodeGroupStack.addDependency(nodeGroupRoleStack);

// 9. Create Hello Node Group Stack (depends on Cluster, Launch Template, and Node Group Role)
const helloNodeGroupStack = new EksNodeGroupHelloStack(
  app,
  'EksNodeGroupHelloStack',
  vpcStack,
  clusterStack,
  launchTemplateStack,
  {
    env: env,
    description: 'EKS node group for hello application',
  }
);
helloNodeGroupStack.addDependency(clusterStack);
helloNodeGroupStack.addDependency(launchTemplateStack);
helloNodeGroupStack.addDependency(nodeGroupRoleStack);

// Synthesize the app
app.synth();

