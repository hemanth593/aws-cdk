#!/usr/bin/env python3
import aws_cdk as cdk
from eks_vpc_cdk.eks_vpc_cdk_stack import EksVpcCdkStack
from eks_vpc_cdk.eks_cluster_role import EksClusterRoleStack
from eks_vpc_cdk.eks_admin_policy import EksAdminPolicyStack
from eks_vpc_cdk.eks_nodegroup_role import EksNodeGroupRoleStack
from eks_vpc_cdk.eks_create_cluster import EksClusterStack
from eks_vpc_cdk.eks_launch_template import EksLaunchTemplateStack
from eks_vpc_cdk.eks_nodegroup_scheduler import EksNodeGroupSchedulerStack

app = cdk.App()

# Deploy VPC stack first
vpc_stack = EksVpcCdkStack(app, "EksVpcCdkStack")

# Then deploy the EKS Cluster Role stack
# No explicit dependency needed since they don't share resources
cluster_role_stack = EksClusterRoleStack(app, "EksClusterRoleStack")
nodegroup_role_stack = EksNodeGroupRoleStack(app, "EksNodeGroupRoleStack")
admin_policy_stack = EksAdminPolicyStack(app, "EksAdminPolicyStack")

# Deploy EKS cluster stack
eks_cluster_stack = EksClusterStack(app, "EksClusterStack", vpc_stack=vpc_stack)
eks_cluster_stack.add_dependency(vpc_stack) # Ensure VPC is created before the EKS cluster

# Deploy Launch Template stack
launch_template_stack = EksLaunchTemplateStack(app, "EksLaunchTemplateStack", eks_cluster_stack=eks_cluster_stack)
launch_template_stack.add_dependency(eks_cluster_stack) # Ensure EKS cluster is created before launch template

# Deploy Node Group stack
nodegroup_stack = EksNodeGroupSchedulerStack(
    app, "EksNodeGroupSchedulerStack", 
    vpc_stack=vpc_stack,
    eks_cluster_stack=eks_cluster_stack,
    launch_template_stack=launch_template_stack
)
# Ensure all dependencies are created before the node group
nodegroup_stack.add_dependency(vpc_stack)
nodegroup_stack.add_dependency(cluster_role_stack)
nodegroup_stack.add_dependency(nodegroup_role_stack)
nodegroup_stack.add_dependency(admin_policy_stack)
nodegroup_stack.add_dependency(eks_cluster_stack)
nodegroup_stack.add_dependency(launch_template_stack)

app.synth()
