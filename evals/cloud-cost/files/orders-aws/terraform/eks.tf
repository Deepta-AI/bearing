locals {
  node_groups = {
    prod = { instance_type = "m6i.4xlarge", size = 6 }
    qa   = { instance_type = "m6i.2xlarge", size = 4 }
    dev  = { instance_type = "m6i.2xlarge", size = 3 }
  }
}

resource "aws_eks_cluster" "orders" {
  for_each = local.node_groups
  name     = "orders-${each.key}"
  role_arn = aws_iam_role.eks.arn
  vpc_config {
    subnet_ids = aws_subnet.private[*].id
  }
  tags = { env = each.key, service = "eks" }
}

resource "aws_eks_node_group" "orders" {
  for_each        = local.node_groups
  cluster_name    = aws_eks_cluster.orders[each.key].name
  node_group_name = "orders-${each.key}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = [each.value.instance_type]
  scaling_config {
    desired_size = each.value.size
    min_size     = each.value.size
    max_size     = each.value.size + 2
  }
  tags = { env = each.key, service = "eks-nodes" }
}
