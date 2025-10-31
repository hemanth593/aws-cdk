from aws_cdk import (
    Stack,
    aws_eks as eks,
    aws_iam as iam,
    aws_ec2 as ec2,
    CfnOutput
)
from constructs import Construct
from eks_vpc_cdk.eks_vpc_cdk_stack import EksVpcCdkStack
from eks_vpc_cdk.eks_create_cluster import EksClusterStack
from eks_vpc_cdk.eks_launch_template import EksLaunchTemplateStack

class EksNodeGroupHelloStack(Stack):
    def __init__(self, scope: Construct, id: str, 
                 vpc_stack: EksVpcCdkStack,
                 eks_cluster_stack: EksClusterStack,
                 launch_template_stack: EksLaunchTemplateStack,
                 **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Get the EKS cluster reference
        cluster = eks_cluster_stack.cluster
        
        # Get the launch template ID (reusing the same launch template)
        launch_template_id = launch_template_stack.launch_template.ref
        
        # Get the private subnet IDs
        private_subnet_ids = [subnet.ref for subnet in vpc_stack.private_subnets]
        
        # Import VPC for security group creation
        vpc_cfn = vpc_stack.vpc
        vpc = ec2.Vpc.from_vpc_attributes(
            self, "ImportedVpc",
            vpc_id=vpc_cfn.ref,
            availability_zones=["us-east-1a", "us-east-1b", "us-east-1c"],
            vpc_cidr_block="192.168.0.0/16"
        )
        
        # Create a dedicated security group for prod-hello node group
        hello_sg = ec2.SecurityGroup(
            self, "HelloNodeGroupSecurityGroup",
            vpc=vpc,
            security_group_name="prod-hello-ng-sg",
            description="Security group for prod-hello node group",
            allow_all_outbound=True
        )
        
        # Add ingress rules for the security group
        hello_sg.add_ingress_rule(
            peer=ec2.Peer.ipv4("192.168.0.0/16"),
            connection=ec2.Port.tcp(80),
            description="Allow HTTP from VPC"
        )
        
        hello_sg.add_ingress_rule(
            peer=ec2.Peer.ipv4("192.168.0.0/16"),
            connection=ec2.Port.all_traffic(),
            description="Allow all traffic from VPC"
        )
        
        # Get the EKS NodeGroup Role ARN
        eks_nodegroup_role_name = "prod-sre-workernode-role"
        eks_nodegroup_role_arn = f"arn:{Stack.of(self).partition}:iam::{Stack.of(self).account}:role/{eks_nodegroup_role_name}"
        
        # Look up the IAM Role using the constructed ARN
        eks_nodegroup_role = iam.Role.from_role_arn(
            self, "EksNodeGroupRoleLookup",
            role_arn=eks_nodegroup_role_arn,
            mutable=False
        )

        # Create the EKS Node Group for prod-hello
        node_group = eks.CfnNodegroup(
            self, "ProdHelloNodeGroup",
            cluster_name=cluster.name,
            node_role=eks_nodegroup_role.role_arn,
            nodegroup_name="prod-hello-ng",
            
            # Subnets - use only private subnets
            subnets=private_subnet_ids,
            
            # Launch Template configuration (reusing the same launch template)
            launch_template={
                "id": launch_template_id,
                "version": "$Latest"
            },
            
            # Scaling configuration - 1 node as requested
            scaling_config={
                "desiredSize": 1,
                "minSize": 1,
                "maxSize": 1
            },
            
            # Capacity type
            capacity_type="ON_DEMAND",
            
            # AMI type
            ami_type="AL2023_x86_64_STANDARD",
            
            # Tags for the node group
            tags={
                "Environment": "prod",
                "System": "prod-eks",
                "Component": "prod-eks-hello",
                "NodeGroup": "prod-hello-ng"
            }
        )

        # Store references
        self.node_group = node_group
        self.hello_sg = hello_sg

        # Outputs
        CfnOutput(
            self, "NodeGroupName", 
            value=node_group.nodegroup_name,
            description="EKS Node Group Name for prod-hello"
        )
        
        CfnOutput(
            self, "NodeGroupArn", 
            value=node_group.attr_arn,
            description="EKS Node Group ARN for prod-hello"
        )
        
        CfnOutput(
            self, "HelloSecurityGroupId", 
            value=hello_sg.security_group_id,
            description="Security Group ID for prod-hello node group"
        )
        
        CfnOutput(
            self, "UsedLaunchTemplateId", 
            value=launch_template_id,
            description="Launch Template ID used by prod-hello node group"
        )
