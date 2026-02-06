# KEDA for Event-Driven Autoscaling (Required for ADO Agents)
resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  namespace        = "keda"
  create_namespace = true
  version          = "2.13.0"

  depends_on = [module.eks]
}
