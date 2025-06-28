resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = "kube-system"
  }

  data = {
    api-token = var.cloudflare_cert_manager_token
  }
}

resource "kubernetes_namespace" "cloudflared" {
  metadata {
    name = "cloudflared"
  }
}

resource "kubernetes_secret" "tunnel" {
  metadata {
    name      = "tunnel"
    namespace = "cloudflared"
  }

  data = {
    token = var.cloudflare_tunnel_token
  }
}

resource "kubernetes_secret" "repo_github" {
  metadata {
    name      = "repo-github"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type          = "git"
    url           = var.ssh_clone_url
    sshPrivateKey = var.ssh_deploy_key
  }
}

resource "kubernetes_manifest" "applicationset_gitops" {
  manifest = {
    "apiVersion" = "argoproj.io/v1alpha1"
    "kind"       = "ApplicationSet"
    "metadata" = {
      "name"      = "gitops"
      "namespace" = "argocd"
    }
    "spec" = {
      "goTemplate"        = true
      "goTemplateOptions" = ["missingkey=error"]
      "generators" = [
        {
          "git" = {
            "repoURL"  = var.ssh_clone_url
            "revision" = "HEAD"
            "directories" = [
              {
                "path" = "*"
              }
            ]
          }
        }
      ]
      "syncPolicy" = {
        "preserveResourcesOnDeletion" = true
      }
      "ignoreApplicationDifferences" = [
        {
          "jsonPointers" = [
            "/spec/syncPolicy"
          ]
        }
      ]
      "template" = {
        "metadata" = {
          "name" = "{{.path.basename}}"
          "annotations" = {
            "argocd.argoproj.io/manifest-generate-paths" = "."
          }
        }
        "spec" = {
          "project" = "default"
          "source" = {
            "repoURL"        = var.ssh_clone_url
            "targetRevision" = "HEAD"
            "path"           = "{{.path.path}}"
            "helm" = {
              "values" = <<EOF
domain: ${var.domain}
aud: ${var.cloudflare_aud}
teamName: ${var.cloudflare_team_name}
EOF
            }
          }
          "destination" = {
            "server"    = "https://kubernetes.default.svc"
            "namespace" = "{{.path.basename}}"
          }
          "syncPolicy" = {
            "automated" = {}
            "managedNamespaceMetadata" = {
              "labels" = {
                "pod-security.kubernetes.io/enforce" = var.default_pss_profile
              }
            }
            "syncOptions" = [
              "CreateNamespace=true",
              "ServerSideApply=true"
            ]
          }
        }
      }
    }
  }
}