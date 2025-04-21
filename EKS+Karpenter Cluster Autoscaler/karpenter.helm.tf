resource "helm_release" "aws-load-balancer-controller" {
  name            = "karpenter"
  repository      = "oci://public.ecr.aws/karpenter/karpenter" # https://charts.karpenter.sh/
  chart           = "karpenter"
  version         = "1.3.3" # v0.16.2
  namespace       = "karpenter"
  cleanup_on_fail = true
  recreate_pods   = true
  replace         = true
  force_update    = true

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }
  set {
    name  = "settings.interruptionQueue"
    value = var.cluster_name
  }
  set {
    name  = "controller.resources.requests.cpu"
    value = "1"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }
  set {
    name  = "controller.resources.limits.cpu"
    value = "1"
  }
  set {
    name  = "controller.resources.limits.memory"
    value = "1"
  }

  depends_on = [kubernetes_service_account.alb_controller_sa]
}