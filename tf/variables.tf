variable "cloudflare_api_key" {
  description = "Cloudflare global API key from https://dash.cloudflare.com/profile/api-tokens"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_email" {
  description = "Cloudflare account email address"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Account ID for your Cloudflare account"
  sensitive   = true
}

variable "domain" {
  description = "Domain name"
  type        = string
}

variable "apex_redirect_url" {
  description = "URL to redirect apex to (path and query string in $1)"
  type        = string
  default     = ""
}

variable "local_ip" {
  description = "Local IP of server"
  type        = string
}

variable "github_oauth_client_id" {
  description = "GitHub OAuth client ID"
  type        = string
}

variable "github_oauth_client_secret" {
  description = "GitHub OAuth client secret"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub PAT"
  type        = string
  sensitive   = true
}

variable "dockerhub_username" {
  description = "Docker Hub username (used by Dependabot)"
  type        = string
  default     = ""
}

variable "dockerhub_pat" {
  description = "Docker Hub PAT (used by Dependabot)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_repo" {
  description = "Name of git repo"
  type        = string
  default     = "gitops"
}

variable "allowed_email_addresses" {
  description = "Email addresses allowed to access the Kubernetes apps"
  type        = list(string)
}

variable "default_pss_profile" {
  description = "Default pod security standard policy on namespaces"
  type        = string
  default     = "privileged"
}

variable "cluster_name" {
  description = "Name of Kubernetes cluster"
  type        = string
  default     = "homecloudlab"
}

variable "disk" {
  description = "Device to install talos onto"
  type        = string
}

variable "disk_encryption" {
  description = "If true, encrypt disks with TPM sealed key"
  type        = bool
  default     = false
}

variable "image" {
  description = "Talos install image"
  type        = string
  default     = "ghcr.io/siderolabs/installer:v1.12.0"
}