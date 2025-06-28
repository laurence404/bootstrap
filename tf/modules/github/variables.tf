variable "repo_name" {
  description = "Name of the repository to create"
  type        = string
}

variable "domain" {
  description = "Domain name"
  type        = string
}

variable "webhook_secret" {
  description = "Webhook secret"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "dockerhub_username" {
  description = "Docker Hub username (used by Dependabot)"
  type        = string
}

variable "dockerhub_pat" {
  description = "Docker Hub PAT (used by Dependabot)"
  type        = string
  sensitive   = true
}