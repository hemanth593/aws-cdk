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

const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT || '575108957879',
  region: process.env.CDK_DEFAULT_REGION || 'us-east-1',
};

// 1. IAM roles FIRST (because KMS key policy references these)
const clusterRoleStack = new EksClusterRoleStack(app, 'EksClusterRoleStack', {
  env,
});
const nodeGroupRoleStack = new EksNodeGroupRoleStack(app, 'EksNodeGroupRoleStack', {
  env,
});

// 2. Now create the KMS key (safe now because IAM roles exist)
const kmsKeyStack = new EksKmsKeyStack(app, 'EksKmsKeyStack', {
  env,
});
kmsKeyStack.addDependency(clusterRoleStack);
kmsKeyStack.addDependency(nodeGroupRoleStack);

// 3. VPC Stack
const vpcStack = new EksVpcCdkStack(app, 'EksVpcCdkStack', {
  env,
});

// 4. Admin Policy Stack
const adminPolicyStack = new EksAdminPolicyStack(app, 'EksAdminPolicyStack', {
  env,
});

// 5. Create EKS Cluster Stack
const clusterStack = new EksClusterStack(app, 'EksClusterStack', vpcStack, kmsKeyStack, {
  env,
});
clusterStack.addDependency(vpcStack);
clusterStack.addDependency(kmsKeyStack);
clusterStack.addDependency(clusterRoleStack);

// 6. Launch Template
const launchTemplateStack = new EksLaunchTemplateStack(
  app,
  'EksLaunchTemplateStack',
  clusterStack,
  { env }
);
launchTemplateStack.addDependency(clusterStack);

// 7. Scheduler Node Group
const schedulerNodeGroupStack = new EksNodeGroupSchedulerStack(
  app,
  'EksNodeGroupSchedulerStack',
  vpcStack,
  clusterStack,
  launchTemplateStack,
  { env }
);
schedulerNodeGroupStack.addDependency(clusterStack);
schedulerNodeGroupStack.addDependency(launchTemplateStack);
schedulerNodeGroupStack.addDependency(nodeGroupRoleStack);

// 8. Hello Node Group
const helloNodeGroupStack = new EksNodeGroupHelloStack(
  app,
  'EksNodeGroupHelloStack',
  vpcStack,
  clusterStack,
  launchTemplateStack,
  { env }
);
helloNodeGroupStack.addDependency(clusterStack);
helloNodeGroupStack.addDependency(launchTemplateStack);
helloNodeGroupStack.addDependency(nodeGroupRoleStack);

app.synth();
