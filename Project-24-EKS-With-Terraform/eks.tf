module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.32"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  # Required so we can give the EBS CSI driver (and other add-ons) scoped
  # IAM permissions via a Kubernetes service account, instead of node-wide access
  enable_irsa = true

  # Self Managed Node Group(s)
  self_managed_node_group_defaults = {
    instance_type                          = var.asg_instance_types[0].instance_type
    update_launch_template_default_version = true
  }

  self_managed_node_groups = local.self_managed_node_groups

  # aws-auth configmap
  create_aws_auth_configmap = false
  manage_aws_auth_configmap = false
  aws_auth_users            = concat(local.admin_user_map_users, local.developer_user_map_users)

  tags = {
    Environment = "prod"
    Terraform   = "true"
  }
}