from aws_cdk import (
    Stack,
    aws_iam as iam,
    CfnOutput
)
from constructs import Construct

class EksAdminPolicyStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Look up the existing devops-admin role
        devops_admin_role = iam.Role.from_role_name(
            self, "DevopsAdminRole",
            role_name="devops-admins"
        )

        # Create the AdminRoleEKSClusterPolicy and attach it to devops-admin role
        admin_eks_policy = iam.Policy(
            self, "AdminRoleEKSClusterPolicy",
            policy_name="AdminRoleEKSClusterPolicy",
            roles=[devops_admin_role],
            statements=[
                iam.PolicyStatement(
                    sid="EKSAdminAccessPolicy2",
                    effect=iam.Effect.ALLOW,
                    actions=["eks:*"],
                    resources=["*"]
                )
            ]
        )

        # Output the policy name for reference (Policy object doesn't have policy_arn attribute)
        CfnOutput(
            self, "AdminEKSPolicyName", 
            value=admin_eks_policy.policy_name,
            description="Name of the AdminRoleEKSClusterPolicy"
        )
        
        # Output confirmation that policy was attached to devops-admin role
        CfnOutput(
            self, "PolicyAttachedToRole", 
            value=f"AdminRoleEKSClusterPolicy attached to {devops_admin_role.role_name}",
            description="Confirmation of policy attachment"
        )
