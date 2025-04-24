terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.36.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "3.0.0-pre2"
    }
  }

  backend "s3" {
    bucket            = "expensee-dev"
    key               = "expense-dev"
    region            = "us-east-1"
    dynamodb_endpoint = "expensee-locking"
    # encrypt = true
  }

}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

#get configuration using Exec Plugins
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks-cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks-cluster.certificate_authority.0.data)
  # token                  = data.aws_eks_cluster_auth.eks-cluster-auth.token
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes = {
    #config_path = "~/.kube/config"
    host                   = data.aws_eks_cluster.eks-cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks-cluster.certificate_authority[0].data)
    # token                  = data.aws_eks_cluster_auth.eks-cluster-auth.token
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
      command     = "aws"
    }
  }
}