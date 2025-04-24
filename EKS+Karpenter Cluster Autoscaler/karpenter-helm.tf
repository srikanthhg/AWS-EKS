resource "aws_iam_role" "karpenter_noderole" {
  name = "karpenterNodeRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.karpenter_noderole.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.karpenter_noderole.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.karpenter_noderole.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.karpenter_noderole.name
}

resource "kubernetes_service_account" "karpenter_sa" {
  metadata {
    name      = "karpenterr"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_noderole.arn
    }
  }
  depends_on = [ module.eks ]
}

resource "helm_release" "aws-load-balancer-controller" {
  name            = "karpenter"
  repository      = "oci://public.ecr.aws/karpenter/karpenter" # https://charts.karpenter.sh/
  chart           = "karpenter"
  version         = "1.3.3" # v0.16.2
  namespace       = "kube-system"
  cleanup_on_fail = true
  recreate_pods   = true
  replace         = true
  force_update    = true

  set =[
  {
    name  = "settings.clusterName"
    value = var.cluster_name
  },
  {
    name  = "settings.interruptionQueue"
    value = var.cluster_name
  },
  {
    name  = "controller.resources.requests.cpu"
    value = "1"
  },
  {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  },
  {
    name  = "controller.resources.limits.cpu"
    value = "1"
  },
  {
    name  = "controller.resources.limits.memory"
    value = "1"
  }
  ]
  depends_on = [kubernetes_service_account.alb_controller_sa]
}

#nodepool for karpenter
# Note: This NodePool will create capacity as long as the sum of all created capacity is less than the specified limit.

resource "kubernetes_manifest" "karpenter_nodepool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name      = "default"
    }
    spec = {
      requirements = [
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["amd64"]
        },
        {
          key      = "kubernetes.io/os"
          operator = "In"
          values   = ["linux"]
        },
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = ["on-demand"]
        },
        {
          key      = "karpenter.k8s.aws/instance-category"
          operator = "In"
          values   = ["c", "m", "r"]
        },
        {
          key      = "karpenter.k8s.aws/instance-generation"
          operator = "Gt"
          values   = ["2"]
        },
      ]
      nodeClassRef = {
        group = "karpenter.k8s.aws"
        kind = "EC2NodeClass"
        name = "default"
      }
      expireafter = "720h" # 30 * 24h = 720h
      limits = {
        "resources.cpu"    = "1000"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter = "1m"
      }
    }
  }
  depends_on = [helm_release.aws-load-balancer-controller]
}

#EC2Nodeclass for karpenter
resource "kubernetes_manifest" "karpenter_ec2_nodeclass" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name      = "default"
    }
    spec = {
      role = "KarpenterNodeRole-${var.cluster_name}"
      amiSelectorTerms = [
        {
          alias = "al2023@v20250419"
        }
      ]
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]
    }
  }
  depends_on = [helm_release.aws-load-balancer-controller]
}