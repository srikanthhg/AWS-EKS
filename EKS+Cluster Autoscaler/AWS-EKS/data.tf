data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = [local.name]
  }
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"               # Filter by VPC ID
    values = [data.aws_vpc.main.id] # VPC ID from the data source
  }

  filter {
    name   = "tag:kubernetes.io/role/internal-elb" # Filter by the specific tag
    values = ["1"]                                 # Value to match
  }
}

data "tls_certificate" "eks-certificate" {
  url = aws_eks_cluster.my_cluster.identity[0].oidc[0].issuer
}

#https://oidc.eks.us-east-1.amazonaws.com/id/3145F8DA5B4C45EFB1C3A1345AFC9BC5
# output "eks-oidc-url" {
#   value = data.tls_certificate.eks-certificate.url
# }
# output "thumbprint" {
#   value = data.tls_certificate.eks-certificate.certificates[0].sha1_fingerprint
# }

data "aws_eks_cluster" "eks-cluster" {
  name = aws_eks_cluster.my_cluster.name

  depends_on = [aws_eks_cluster.my_cluster]
}

data "aws_eks_cluster_auth" "eks-cluster-auth" {
  name = aws_eks_cluster.my_cluster.name
}
