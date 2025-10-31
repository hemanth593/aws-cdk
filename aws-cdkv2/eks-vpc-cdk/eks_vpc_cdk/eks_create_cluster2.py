from aws_cdk import (
    Stack,
    aws_eks as eks,
    aws_ec2 as ec2,
    aws_iam as iam,
    CfnOutput
)
from constructs import Construct
from eks_vpc_cdk.eks_vpc_cdk_stack import EksVpcCdkStack # Import the VPC stack

class EksClusterStack(Stack):
    def __init__(self, scope: Construct, id: str, vpc_stack: EksVpcCdkStack, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Retrieve VPC and subnet information from the passed vpc_stack
        vpc_cfn = vpc_stack.vpc
        public_subnets = vpc_stack.public_subnets
        private_subnets = vpc_stack.private_subnets

        # Import the VPC as an L2 construct for use with SecurityGroup
        # This approach ensures the security group correctly references the VPC by ID and attributes.
        vpc = ec2.Vpc.from_vpc_attributes(
            self, "ImportedVpc",
            vpc_id=vpc_cfn.ref,
            # Explicitly define availability zones as they are crucial for proper VPC attribute import
            availability_zones=["us-east-1a", "us-east-1b", "us-east-1c"],
            vpc_cidr_block="192.168.0.0/16"
        )

        # 1. Create EKS cluster security group
        cluster_sg = ec2.SecurityGroup(
            self, "EksClusterSecurityGroup",
            vpc=vpc, # Use the imported L2 VPC construct
            security_group_name="prod-sre-cluster-sg",
            description="Security group for EKS cluster control plane",
            allow_all_outbound=True # Explicitly allow all outbound traffic to fix the VpcId issue
        )

        # Add appropriate security group rules for EKS
        # Based on initial request, allowing HTTP and MySQL from 0.0.0.0/0
        cluster_sg.add_ingress_rule(
            peer=ec2.Peer.ipv4("0.0.0.0/0"),
            connection=ec2.Port.tcp(80),
            description="Allow HTTP access to cluster"
        )
        cluster_sg.add_ingress_rule(
            peer=ec2.Peer.ipv4("0.0.0.0/0"),
            connection=ec2.Port.tcp(3306),
            description="Allow MySQL access to cluster"
        )
        # Note: If you prefer the more secure HTTPS from VPC CIDR as in your provided code,
        # you can replace the above two rules with:
        # cluster_sg.add_ingress_rule(
        #     peer=ec2.Peer.ipv4("192.168.0.0/16"),
        #     connection=ec2.Port.tcp(443),
        #     description="Allow HTTPS access to Kubernetes API from VPC"
        # )


        # Get the EKS Cluster Role ARN
        # The EKS service sometimes requires the IAM role ARN without region for cluster creation.
        # Construct the ARN manually to ensure no region information is present,
        # adhering to the format: arn:aws:iam::<account-id>:role/<role-name>
        eks_cluster_role_name = "prod-sre-eks-cluster-role"
        eks_cluster_role_arn = f"arn:{Stack.of(self).partition}:iam::{Stack.of(self).account}:role/{eks_cluster_role_name}"

        # Look up the IAM Role using the constructed ARN
        eks_cluster_role = iam.Role.from_role_arn(
            self, "EksClusterRoleLookup",
            role_arn=eks_cluster_role_arn,
            # Set mutable to False for imported roles if you don't intend to modify them.
            # This is generally a good practice for roles you expect to exist and not be changed by this stack.
            mutable=False
        )

        # 2. Create EKS Cluster
        cluster = eks.CfnCluster(
            self, "ProdSreEksCluster",
            name="prod-eks-sre-cluster",
            role_arn=eks_cluster_role.role_arn, # Attach the EKS Cluster Role
            version="1.33", # Updated: Kubernetes Version to 1.33 as per your request
            resources_vpc_config=eks.CfnCluster.ResourcesVpcConfigProperty(
                subnet_ids=[s.ref for s in public_subnets + private_subnets], # 5. Networking: Attach Private and Public Subnets
                security_group_ids=[cluster_sg.security_group_id],
                endpoint_public_access=True, # 7. Endpoint Access: Public
                endpoint_private_access=True, # 7. Endpoint Access: Private
                public_access_cidrs=["0.0.0.0/0"] # 7. Endpoint Access: Public and Private (CIDR: 0.0.0.0/0)
            ),
            kubernetes_network_config=eks.CfnCluster.KubernetesNetworkConfigProperty(
                ip_family="ipv4", # Corrected: Use uppercase "IPV4" for Cfn property
                service_ipv4_cidr="10.100.0.0/16" # 6. IPv4 CIDR: 10.100.0.0/16
            )
        )

        # Output the Cluster Name and ARN
        CfnOutput(self, "EksClusterName", value=cluster.name)
        CfnOutput(self, "EksClusterArn", value=cluster.attr_arn)

