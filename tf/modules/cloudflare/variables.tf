variable "account_id" {
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

variable "allowed_email_addresses" {
  description = "Email addresses allowed to access the Kubernetes apps"
  type        = list(string)
}