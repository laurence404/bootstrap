terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

data "cloudflare_zones" "main" {
  account = {
    id = var.account_id
  }
  name = var.domain
}

data "cloudflare_zero_trust_organization" "zero_trust" {
  account_id = var.account_id
}

# https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deployment-guides/terraform/
# Generates a 64-character secret for the tunnel.
# Using `random_password` means the result is treated as sensitive and, thus,
# not displayed in console output. Refer to: https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password
resource "random_password" "tunnel_secret" {
  length = 64
}

# Creates a new locally-managed tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "kubernetes" {
  account_id    = var.account_id
  name          = "Kubernetes"
  config_src    = "local"
  tunnel_secret = base64sha256(random_password.tunnel_secret.result)
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "kubernetes" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.kubernetes.id
}

# Creates the CNAME record that routes *.${var.cloudflare_zone} to the tunnel
# i.e. foo.example.com, bar.example.com and foo.bar.example but not example.com
resource "cloudflare_dns_record" "tunnel" {
  zone_id = data.cloudflare_zones.main.result[0].id
  name    = "*.${var.domain}"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.kubernetes.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "local" {
  zone_id = data.cloudflare_zones.main.result[0].id
  name    = "local.${var.domain}"
  content = var.local_ip
  type    = "A"
  proxied = false
  ttl     = 1
}

resource "cloudflare_dns_record" "local_wildcard" {
  zone_id = data.cloudflare_zones.main.result[0].id
  name    = "*.local.${var.domain}"
  content = var.local_ip
  type    = "A"
  proxied = false
  ttl     = 1
}

# Optional apex redirect
# WARNING: due to a bug in the cloudflare terraform provider this gives an error
# if the terraform is re-applied
# Placeholder A record for the apex domain (@).
# This MUST exist and be proxied for the apex-to-www Page Rule to work.
# Cloudflare intercepts the request before it hits this dummy IP.
resource "cloudflare_dns_record" "apex_placeholder" {
  count   = var.apex_redirect_url == "" ? 0 : 1
  zone_id = data.cloudflare_zones.main.result[0].id
  name    = "@"
  # IP reserved for examples
  content = "192.0.2.1"
  type    = "A"
  proxied = true
  ttl     = 1
  comment = "Placeholder for apex domain to enable Page Rule redirection"
}

# Page Rule: Redirect apex domain (example.com/*) to somewhere else
resource "cloudflare_page_rule" "apex_to_www_redirect" {
  count    = var.apex_redirect_url == "" ? 0 : 1
  zone_id  = data.cloudflare_zones.main.result[0].id
  target   = "${var.domain}/*" # Match apex domain and any path/query string
  priority = 1                 # High priority (runs before other rules)

  actions = {
    forwarding_url = {
      # Forward to the new domain, path and query string in $1
      url = "${var.apex_redirect_url}"
      # Use 301 for a permanent redirect (good for SEO)
      status_code = 301
    }
  }
  # Ensure the rule is active
  status = "active"
}

# https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/github/
resource "cloudflare_zero_trust_access_identity_provider" "github" {
  zone_id = data.cloudflare_zones.main.result[0].id
  name    = "github"
  type    = "github"
  config = {
    client_id     = var.github_oauth_client_id
    client_secret = var.github_oauth_client_secret
  }
}

# Need to manually enable on web console (due to $0 billing)
# https://developers.cloudflare.com/cloudflare-one/policies/access/app-paths/
# i.e. foo.example.com, bar.example.com but not foo.bar.example or example.com 
resource "cloudflare_zero_trust_access_application" "kubernetes_apps" {
  zone_id                   = data.cloudflare_zones.main.result[0].id
  name                      = "Kubernetes apps"
  type                      = "self_hosted"
  domain                    = "*.${var.domain}"
  session_duration          = "24h"
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.github.id]
  auto_redirect_to_identity = true
  policies = [{
    id          = cloudflare_zero_trust_access_policy.interactive.id
    prescedence = 0
    }, {
    id          = cloudflare_zero_trust_access_policy.non_interactive.id
    prescedence = 1
  }]
}

# More specific rule to disable authentication for argocd webhook
resource "cloudflare_zero_trust_access_application" "argocd_webhook" {
  zone_id      = data.cloudflare_zones.main.result[0].id
  name         = "ArgoCD Webhook"
  type         = "self_hosted"
  domain       = "argocd.${var.domain}/api/webhook"
  allowed_idps = [cloudflare_zero_trust_access_identity_provider.github.id]
  policies = [{
    id          = cloudflare_zero_trust_access_policy.everyone.id
    prescedence = 0
  }]
}

# More specific rule to disable authentication for argocd applicationset webhook
resource "cloudflare_zero_trust_access_application" "argocd_applicationset_webhook" {
  zone_id      = data.cloudflare_zones.main.result[0].id
  name         = "ArgoCD ApplicationSet Webhook"
  type         = "self_hosted"
  domain       = "argocd-applicationset.${var.domain}/api/webhook"
  allowed_idps = [cloudflare_zero_trust_access_identity_provider.github.id]
  policies = [{
    id          = cloudflare_zero_trust_access_policy.everyone.id
    prescedence = 0
  }]
}

resource "cloudflare_zero_trust_access_policy" "interactive" {
  account_id = var.account_id
  name       = "Interactive"
  decision   = "allow"

  include = [
    for email in var.allowed_email_addresses : {
      email = {
        email = email
      }
    }
  ]
}

resource "cloudflare_zero_trust_access_policy" "non_interactive" {
  account_id = var.account_id
  name       = "Non interactive"
  decision   = "non_identity"

  include = [{
    any_valid_service_token = {}
  },{
    certificate             = {}
  }]
}

resource "cloudflare_zero_trust_access_policy" "everyone" {
  account_id = var.account_id
  name       = "Everyone"
  decision   = "non_identity"

  include = [{
    everyone = {}
  }]
}

resource "cloudflare_zone_setting" "main" {
  for_each = tomap({
    # https://developers.cloudflare.com/api/resources/zones/subresources/settings/methods/edit/
    always_use_https = "on"
    ssl              = "strict"
    min_tls_version  = "1.2"
  })
  zone_id    = data.cloudflare_zones.main.result[0].id
  setting_id = each.key
  value      = each.value
}

resource "cloudflare_zone_setting" "security_header" {
  zone_id    = data.cloudflare_zones.main.result[0].id
  setting_id = "security_header"
  value = {
    strict_transport_security = {
      enabled            = true
      max_age            = 7776000
      include_subdomains = true
      preload            = false
      nosniff            = true
    }
  }
}

resource "random_password" "webook_secret" {
  length = 16
}

# Use a cloudflare worker to intercept calls to the webhook
# endpoints (publically accessible) and validate them before
# passing onto ArgoCD
resource "cloudflare_workers_script" "github_webhook" {
  account_id  = var.account_id
  script_name = "github-webhook"
  content     = file("${path.module}/github-webhook.js")
  bindings = [{
    name = "WEBHOOK_SECRET"
    type = "secret_text"
    text = random_password.webook_secret.result
  }]
}

resource "cloudflare_workers_route" "argocd_webhook" {
  zone_id = data.cloudflare_zones.main.result[0].id
  pattern = "argocd.${var.domain}/api/webhook"
  script  = cloudflare_workers_script.github_webhook.script_name
}

resource "cloudflare_workers_route" "argocd_applicationset_webhook" {
  zone_id = data.cloudflare_zones.main.result[0].id
  pattern = "argocd-applicationset.${var.domain}/api/webhook"
  script  = cloudflare_workers_script.github_webhook.script_name
}

# https://developers.cloudflare.com/rules/transform/managed-transforms/
resource "cloudflare_managed_transforms" "add_client_certificate" {
  zone_id = data.cloudflare_zones.main.result[0].id
  managed_request_headers = [{
    id      = "add_client_certificate_headers"
    enabled = true
  }]
  managed_response_headers = []
}

# TODO: AI hallucination
# Not supported in terraform - https://github.com/cloudflare/terraform-provider-cloudflare/issues/1044
# Seen this API called from web console
# https://developers.cloudflare.com/api/resources/certificate_authorities/
# https://github.com/cloudflare/cloudflare-typescript/blob/main/src/resources/certificate-authorities/hostname-associations.ts
#resource "cloudflare_certificate_authority_hostname_associations" "hostname_associations" {
#  zone_id = data.cloudflare_zones.main.result[0].id
#  hostname_associations {
#    hostname = var.domain
#  }
#}

data "cloudflare_api_token_permission_groups_list" "all" {
}

locals {
  api_token_zone_permissions_groups_map = {
    for perm in data.cloudflare_api_token_permission_groups_list.all.result :
    perm.name => perm.id
    if contains(perm.scopes, "com.cloudflare.api.account.zone")
  }
}

resource "cloudflare_api_token" "cert_manager" {
  name   = "cert-manager for ${var.domain}"
  status = "active"

  policies = [{
    effect = "allow"
    permission_groups = [
      { "id" = local.api_token_zone_permissions_groups_map["DNS Write"] },
      { "id" = local.api_token_zone_permissions_groups_map["Zone Read"] },
    ]
    resources = {
      "com.cloudflare.api.account.zone.${data.cloudflare_zones.main.result[0].id}" = "*"
    }
  }]
}