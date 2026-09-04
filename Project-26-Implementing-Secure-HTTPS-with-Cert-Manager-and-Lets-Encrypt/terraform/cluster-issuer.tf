resource "kubectl_manifest" "letsencrypt_prod" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.acme_email}
        privateKeySecretRef:
          name: letsencrypt-prod
        solvers:
          - selector:
              dnsZones:
                - "lydiahnganga.cloud"
            dns01:
              route53:
                region: ${var.route53_dns01_region}
                role: ${module.cert_manager_irsa.iam_role_arn}
                auth:
                  kubernetes:
                    serviceAccountRef:
                      name: "cert-manager"
  YAML

  depends_on = [
    helm_release.cert_manager,
    kubernetes_role_binding.cert_manager_tokenrequest
  ]
}
