from aws_cdk import (
    Stack,
    aws_eks as eks,
    aws_iam as iam,
    CfnOutput
)
from constructs import Construct
from eks_vpc_cdk.eks_vpc_cdk_stack import EksVpcCdkStack
from eks_vpc_cdk.eks_create_cluster import EksClusterStack
from eks_vpc_cdk.eks_launch_template import EksLaunchTemplateStack

class EksNodeGroupSchedulerStack(Stack):
    def __init__(self, scope: Construct, id: str, 
                 vpc_stack: EksVpcCdkStack,
                 eks_cluster_stack: EksClusterStack,
                 launch_template_stack: EksLaunchTemplateStack,
                 **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Get the EKS cluster reference
        cluster = eks_cluster_stack.cluster
        
        # Get the launch template ID
        launch_template_id = launch_template_stack.launch_template.ref
        
        # Get the private subnet IDs
        private_subnet_ids = [subnet.ref for subnet in vpc_stack.private_subnets]
        
        # Get the EKS NodeGroup Role ARN
        # The role was created in EksNodeGroupRoleStack with name "prod-sre-workernode-role"
        eks_nodegroup_role_name = "prod-sre-workernode-role"
        eks_nodegroup_role_arn = f"arn:{Stack.of(self).partition}:iam::{Stack.of(self).account}:role/{eks_nodegroup_role_name}"
        
        # Look up the IAM Role using the constructed ARN
        eks_nodegroup_role = iam.Role.from_role_arn(
            self, "EksNodeGroupRoleLookup",
            role_arn=eks_nodegroup_role_arn,
            mutable=False
        )

        # Create the EKS Node Group
        node_group = eks.CfnNodegroup(
            self, "ProdSchedulerNodeGroup",
            cluster_name=cluster.name,  # Reference to the EKS cluster
            node_role=eks_nodegroup_role.role_arn,  # IAM role for the node group
            nodegroup_name="prod-scheduler-v2",
            
            # Subnets - use only private subnets
            subnets=private_subnet_ids,
            
            # Launch Template configuration
            launch_template={
                "id": launch_template_id,
                "version": "$Latest"  # Use the latest version of the launch template
            },
            
            # Scaling configuration
            scaling_config={
                "desiredSize": 2,  # Desired number of nodes
                "minSize": 1,      # Minimum number of nodes
                "maxSize": 2       # Maximum number of nodes
            },
            
            # Capacity type
            capacity_type="ON_DEMAND",
            
            # AMI type (let EKS handle this since we're using launch template)
            ami_type="AL2023_x86_64_STANDARD",
            
            # Note: remote_access is removed because SSH key is defined in launch template
            
            # Tags for the node group
            tags={
                "Environment": "prod",
                "System": "prod-eks",
                "Component": "prod-eks-scheduler",
                "NodeGroup": "prod-scheduler-v2"
            }
        )

        # Store the node group reference
        self.node_group = node_group

        # Outputs
        CfnOutput(
            self, "NodeGroupName", 
            value=node_group.nodegroup_name,
            description="EKS Node Group Name"
        )
        
        CfnOutput(
            self, "NodeGroupArn", 
            value=node_group.attr_arn,
            description="EKS Node Group ARN"
        )
        
        CfnOutput(
            self, "NodeGroupClusterName", 
            value=node_group.cluster_name,
            description="EKS Cluster Name associated with this node group"
        )
        
        CfnOutput(
            self, "UsedLaunchTemplateId", 
            value=launch_template_id,
            description="Launch Template ID used by this node group"
        )
        
        CfnOutput(
            self, "UsedPrivateSubnets", 
            value=",".join(private_subnet_ids),
            description="Private subnet IDs used by this node group"
        )
