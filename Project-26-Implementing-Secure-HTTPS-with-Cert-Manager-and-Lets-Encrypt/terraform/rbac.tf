# Grants the cert-manager ServiceAccount permission to request its own
# projected token via the TokenRequest API — required for the ClusterIssuer's
# auth.kubernetes.serviceAccountRef pattern. Without this, DNS-01 challenges
# fail with "cannot create resource serviceaccounts/token".
resource "kubernetes_role" "cert_manager_tokenrequest" {
  metadata {
    name      = "cert-manager-tokenrequest"
    namespace = var.cert_manager_namespace
  }

  rule {
    api_groups     = [""]
    resources      = ["serviceaccounts/token"]
    resource_names = ["cert-manager"]
    verbs          = ["create"]
  }

  depends_on = [helm_release.cert_manager]
}

resource "kubernetes_role_binding" "cert_manager_tokenrequest" {
  metadata {
    name      = "cert-manager-tokenrequest"
    namespace = var.cert_manager_namespace
  }

  subject {
    kind      = "ServiceAccount"
    name      = "cert-manager"
    namespace = var.cert_manager_namespace
  }

  role_ref {
    kind      = "Role"
    name      = kubernetes_role.cert_manager_tokenrequest.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [helm_release.cert_manager]
}
