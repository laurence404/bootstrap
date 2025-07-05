terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

resource "github_repository" "gitops" {
  name        = var.repo_name
  description = "ArgoCD GitOps repository"
  visibility  = "private"

  template {
    owner                = "laurence404"
    repository           = "gitops-template-kairos"
    include_all_branches = false
  }
}

resource "github_repository_webhook" "argocd" {
  repository = github_repository.gitops.name
  configuration {
    url          = "https://argocd.${var.domain}/api/webhook"
    content_type = "json"
    secret       = var.webhook_secret
  }
  active = true
  events = ["push"]
}

resource "github_repository_webhook" "argocd_applicationset" {
  repository = github_repository.gitops.name
  configuration {
    url          = "https://argocd-applicationset.${var.domain}/api/webhook"
    content_type = "json"
    secret       = var.webhook_secret
  }
  active = true
  events = ["push"]
}

resource "github_dependabot_secret" "dockerhub_pat" {
  count           = var.dockerhub_pat == "" ? 0 : 1
  repository      = github_repository.gitops.name
  secret_name     = "DOCKERHUB_PAT"
  plaintext_value = var.dockerhub_pat
}

resource "github_dependabot_secret" "dockerhub_username" {
  count           = var.dockerhub_username == "" ? 0 : 1
  repository      = github_repository.gitops.name
  secret_name     = "DOCKERHUB_USERNAME"
  plaintext_value = var.dockerhub_username
}

# Generate an ssh key using provider "hashicorp/tls"
resource "tls_private_key" "deploy_key" {
  algorithm = "ED25519"
}

# Add the ssh key as a deploy key
resource "github_repository_deploy_key" "argocd" {
  title      = "ArgoCD deploy key"
  repository = github_repository.gitops.name
  key        = tls_private_key.deploy_key.public_key_openssh
  read_only  = true
}