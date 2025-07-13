terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0-alpha.0"
    }
  }
}

resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.local_ip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [var.local_ip]
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.local_ip
  config_patches = [
    file("${path.module}/files/cp-scheduling.yaml"),
    file("${path.module}/files/delete-label.yaml"),
    file("${path.module}/files/argocd.yaml"),
    file("${path.module}/files/sysctl.yaml"),
    file("${path.module}/files/cilium.yaml"),
    templatefile("${path.module}/templates/secrets.yaml.tmpl", {
      ssh_clone_url                 = var.ssh_clone_url
      ssh_deploy_key                = indent(12, var.ssh_deploy_key)
      cloudflare_cert_manager_token = var.cloudflare_cert_manager_token
      cloudflare_tunnel_token       = var.cloudflare_tunnel_token
    }),
    templatefile("${path.module}/templates/argocd.yaml.tmpl", {
      ssh_clone_url       = var.ssh_clone_url
      domain              = var.domain
      aud                 = var.cloudflare_aud
      teamname            = var.cloudflare_team_name
      default_pss_profile = var.default_pss_profile
    }),
    yamlencode({
      machine = {
        install = {
          disk = var.disk
        }
      }
    }),
    file("${path.module}/files/volumeconfig.yaml"),
    file("${path.module}/files/uservolumeconfig.yaml"),
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.local_ip
}