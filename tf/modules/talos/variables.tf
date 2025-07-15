variable "local_ip" {
  description = "Local IP of server"
  type        = string
}

variable "cluster_name" {
  description = "Name of Kubernetes cluster"
  type        = string
}

variable "cloudflare_tunnel_token" {
  description = "Token for cloudflared tunnel"
  type        = string
  sensitive   = true
}

variable "cloudflare_cert_manager_token" {
  description = "Token for cert manager"
  type        = string
  sensitive   = true
}

variable "ssh_deploy_key" {
  description = "SSH deploy key for github gitops repo"
  type        = string
  sensitive   = true
}

variable "ssh_clone_url" {
  description = "URL to clone git repo"
  type        = string
}

variable "domain" {
  description = "Domain name of homelab"
  type        = string
}

variable "cloudflare_aud" {
  description = "aud tag of cloudflare JWT"
  type        = string
}

variable "cloudflare_team_name" {
  description = "Cloudflare team name"
  type        = string
}

variable "default_pss_profile" {
  description = "Default pod security standard policy on namespaces"
  type        = string
}

variable "disk" {
  description = "Device to install talos onto"
  type        = string
}

variable "disk_encryption" {
  description = "If true, encrypt disks with TPM sealed key"
  type        = bool
}

variable "image" {
  description = "Talos install image"
  type        = string
}