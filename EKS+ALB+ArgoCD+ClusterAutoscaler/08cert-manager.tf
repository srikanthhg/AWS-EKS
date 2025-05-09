resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.17.2" 
  namespace  = "cert-manager" 
  create_namespace = true
  cleanup_on_fail  = true
  recreate_pods    = true
  replace          = true

  set =[ 
    {
      name  = "crds.enabled"
      value = "true"
    }
  ]

  depends_on = [ module.eks]
}


# create a IAM role
resource "aws_iam_role" "cert_manager_role" {
  name = "cert-manager-acme-dns01-route53"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = module.eks.oidc_arn # aws_iam_openid_connect_provider.eks-oidc.arn
        },
        Condition = {
          "StringEquals" = {
            "${module.eks.oidc_url}:sub" = "system:serviceaccount:cert-manager:cert-manager-acme-dns01-route53",
            "${module.eks.oidc_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

}

resource "aws_iam_policy" "certManager_policy" {
  name        = "cert-manager-acme-dns01-route53"
  description = " IAM policy for the cert-manager DNS01 challenge with Route53"

  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
    {
        "Effect"   = "Allow",
        "Action"   = "route53:GetChange",
        "Resource" =  "arn:aws:route53:::change/*",   
    },
    {
        "Effect"= "Allow",
        "Action"= [
            "route53:ChangeResourceRecordSets",
            "route53:ListResourceRecordSets"
        ],
        "Resource"= "arn:aws:route53:::hostedzone/*"
    },
    {
        "Effect"= "Allow",
        "Action"= "route53:ListHostedZonesByName",
        "Resource"= "*"
    }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cert_manager_policy_attach" {
  policy_arn = aws_iam_policy.certManager_policy.arn
  role       = aws_iam_role.cert_manager_role.name
}

# Kubernetes ServiceAccount annotated for IRSA
resource "kubernetes_service_account" "cert_manager_sa" {
  metadata {
    name      = "cert-manager-acme-dns01-route53"
    namespace = "cert-manager"
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cert_manager_role.arn
    }
  }
  depends_on = [ aws_iam_role_policy_attachment.cert_manager_policy_attach ]
}

# kubernetes role
resource "kubernetes_role" "cert_manager_role" {
  metadata {
    name      = "cert-manager-acme-dns01-route53-tokenrequest"
    namespace = "cert-manager"
  }
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts/token"]
    resource_names      = ["cert-manager-acme-dns01-route53"]
    verbs     = ["create"]
  }
}
# kubernetes role binding
resource "kubernetes_role_binding" "cert_manager_role_binding" {
  metadata {
    name      = "cert-manager-acme-dns01-route53-tokenrequest"
    namespace = "cert-manager"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.cert_manager_role.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "cert-manager"
    # name      = kubernetes_service_account.cert_manager_sa.metadata[0].name
    namespace = kubernetes_service_account.cert_manager_sa.metadata[0].namespace
  }
  
}
  

# Issuer is a resource that represents a certificate authority (CA) that can be used to issue certificates.
# ClusterIssuer is a cluster-scoped version of Issuer, which means it can be used across all namespaces in the cluster.

# Create a ClusterIssuer


resource "kubernetes_manifest" "cert_manager_cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind      = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.email
        privateKeySecretRef = {
          name = "letsencrypt-prod-cluster-issuer"
        }
        solvers = [
          {
            dns01 = {
              route53 = {
                region = "${var.region}"
                role = aws_iam_role.cert_manager_role.arn
                auth = {
                    kubernetes = {
                        serviceAccountRef = {
                            name = kubernetes_service_account.cert_manager_sa.metadata[0].name
                        }
                    }
                }
              }
            }
          }
        ]
      }
    }
  }
}

#   depends_on = [module.eks, helm_release.cert_manager]
# }

# # apiVersion: cert-manager.io/v1
# # kind: ClusterIssuer
# # metadata:
# #   name: letsencrypt-prod
# # spec:
# #     acme:
# #         server: "https://acme-v02.api.letsencrypt.org/directory"
# #         email: skanth306@gmail.com
# #         privateKeySecretRef:
# #             name: letsencrypt-prod-cluster-issuer
# #         solvers:
# #         - http01:
# #             ingress:
# #                 class: nginx

resource "kubernetes_manifest" "certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind      = "Certificate" # namespace resource
    metadata = {
      name = "certificate-prod"
      namespace = "argocd" # create the certificate where you appliation resides
    }
    spec = {
        secretName = "skanth306-shop-tls"
        issuerRef = {
            name = "letsencrypt-prod" # name of the ClusterIssuer
            kind = "ClusterIssuer"
        }
        commonName = "*.skanth306.shop"
        dnsNames = [
            "*.skanth306.shop",
            "skanth306.shop"
        ]
        duration = "2160h" # 90 days
        renewBefore = "360h" # 15 days
    }
  }

  depends_on = [module.eks, helm_release.cert_manager, kubernetes_manifest.cert_manager_cluster_issuer]
}