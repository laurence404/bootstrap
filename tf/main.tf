module "cloudflare" {
  source                     = "./modules/cloudflare"
  account_id                 = var.cloudflare_account_id
  domain                     = var.domain
  local_ip                   = var.local_ip
  github_oauth_client_id     = var.github_oauth_client_id
  github_oauth_client_secret = var.github_oauth_client_secret
  allowed_email_addresses    = var.allowed_email_addresses
  apex_redirect_url          = var.apex_redirect_url
}

module "kubernetes" {
  source                        = "./modules/kubernetes"
  cloudflare_tunnel_token       = module.cloudflare.tunnel_token
  cloudflare_cert_manager_token = module.cloudflare.cert_manager_token
  cloudflare_aud                = module.cloudflare.aud
  cloudflare_team_name          = module.cloudflare.team_name
  ssh_deploy_key                = module.github.ssh_deploy_key
  ssh_clone_url                 = module.github.ssh_clone_url
  default_pss_profile           = var.default_pss_profile
  domain                        = var.domain
}

module "github" {
  source             = "./modules/github"
  github_token       = var.github_token
  repo_name          = var.github_repo
  domain             = var.domain
  webhook_secret     = module.cloudflare.webhook_secret
  dockerhub_username = var.dockerhub_username
  dockerhub_pat      = var.dockerhub_pat
}