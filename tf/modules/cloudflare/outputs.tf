output "webhook_secret" {
  value     = random_password.webook_secret.result
  sensitive = true
}

output "tunnel_token" {
  value     = data.cloudflare_zero_trust_tunnel_cloudflared_token.kubernetes.token
  sensitive = true
}

output "cert_manager_token" {
  value     = cloudflare_api_token.cert_manager.value
  sensitive = true
}

output "aud" {
  value = cloudflare_zero_trust_access_application.kubernetes_apps.aud
}

output "team_name" {
  value = split(".", data.cloudflare_zero_trust_organization.zero_trust.auth_domain)[0]
}