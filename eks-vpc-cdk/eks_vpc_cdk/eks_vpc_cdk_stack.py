from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
    CfnOutput
)
from constructs import Construct


class EksVpcCdkStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # === VPC ===
        vpc = ec2.CfnVPC(
            self, "EksVpc",
            cidr_block="192.168.0.0/16",
            tags=[{"key": "Name", "value": "eks-vpc"}]
        )

        # === Internet Gateway ===
        igw = ec2.CfnInternetGateway(
            self, "InternetGateway",
            tags=[{"key": "Name", "value": "eks-igw"}]
        )
        ec2.CfnVPCGatewayAttachment(
            self, "VpcIgwAttachment",
            vpc_id=vpc.ref,
            internet_gateway_id=igw.ref
        )

        # === Public Subnets ===
        public_a = ec2.CfnSubnet(
            self, "PublicSubnetA",
            vpc_id=vpc.ref,
            cidr_block="192.168.0.0/20",
            availability_zone="us-east-1a",
            map_public_ip_on_launch=True,
            tags=[{"key": "Name", "value": "prod-eks-subnet-public-us-east-1a"}]
        )

        public_b = ec2.CfnSubnet(
            self, "PublicSubnetB",
            vpc_id=vpc.ref,
            cidr_block="192.168.16.0/20",
            availability_zone="us-east-1b",
            map_public_ip_on_launch=True,
            tags=[{"key": "Name", "value": "prod-eks-subnet-public-us-east-1b"}]
        )

        public_c = ec2.CfnSubnet(
            self, "PublicSubnetC",
            vpc_id=vpc.ref,
            cidr_block="192.168.32.0/20",
            availability_zone="us-east-1c",
            map_public_ip_on_launch=True,
            tags=[{"key": "Name", "value": "prod-eks-subnet-public-us-east-1c"}]
        )

        # === Private Subnets ===
        private_a = ec2.CfnSubnet(
            self, "PrivateSubnetA",
            vpc_id=vpc.ref,
            cidr_block="192.168.48.0/20",
            availability_zone="us-east-1a",
            map_public_ip_on_launch=False,
            tags=[{"key": "Name", "value": "prod-eks-subnet-private-us-east-1a"}]
        )

        private_b = ec2.CfnSubnet(
            self, "PrivateSubnetB",
            vpc_id=vpc.ref,
            cidr_block="192.168.64.0/20",
            availability_zone="us-east-1b",
            map_public_ip_on_launch=False,
            tags=[{"key": "Name", "value": "prod-eks-subnet-private-us-east-1b"}]
        )

        private_c = ec2.CfnSubnet(
            self, "PrivateSubnetC",
            vpc_id=vpc.ref,
            cidr_block="192.168.80.0/20",
            availability_zone="us-east-1c",
            map_public_ip_on_launch=False,
            tags=[{"key": "Name", "value": "prod-eks-subnet-private-us-east-1c"}]
        )

        # === Public Route Table (1 for all public subnets) ===
        public_rt = ec2.CfnRouteTable(
            self, "PublicRouteTable",
            vpc_id=vpc.ref,
            tags=[{"key": "Name", "value": "eks-public-rt"}]
        )

        ec2.CfnRoute(
            self, "PublicDefaultRoute",
            route_table_id=public_rt.ref,
            destination_cidr_block="0.0.0.0/0",
            gateway_id=igw.ref
        )

        for subnet in [public_a, public_b, public_c]:
            ec2.CfnSubnetRouteTableAssociation(
                self, f"{subnet.node.id}Assoc",
                subnet_id=subnet.ref,
                route_table_id=public_rt.ref
            )

        # === NAT Gateway (1 in Public Subnet A) ===
        eip_nat = ec2.CfnEIP(self, "NatEip", domain="vpc")
        nat_gw = ec2.CfnNatGateway(
            self, "NatGateway",
            subnet_id=public_a.ref,
            allocation_id=eip_nat.attr_allocation_id,
            tags=[{"key": "Name", "value": "eks-natgw"}]
        )

        # === Private Route Table (1 for all private subnets) ===
        private_rt = ec2.CfnRouteTable(
            self, "PrivateRouteTable",
            vpc_id=vpc.ref,
            tags=[{"key": "Name", "value": "eks-private-rt"}]
        )

        ec2.CfnRoute(
            self, "PrivateDefaultRoute",
            route_table_id=private_rt.ref,
            destination_cidr_block="0.0.0.0/0",
            nat_gateway_id=nat_gw.ref
        )

        for subnet in [private_a, private_b, private_c]:
            ec2.CfnSubnetRouteTableAssociation(
                self, f"{subnet.node.id}Assoc",
                subnet_id=subnet.ref,
                route_table_id=private_rt.ref
            )

        # === Outputs ===
        CfnOutput(self, "VpcId", value=vpc.ref)
        CfnOutput(self, "VpcCidr", value="192.168.0.0/16")
        
        # Make resources available as instance attributes
        self.vpc = vpc
        self.public_subnets = [public_a, public_b, public_c]
        self.private_subnets = [private_a, private_b, private_c]
