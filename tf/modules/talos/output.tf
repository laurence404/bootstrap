output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "luks_passphrase" {
  value     = random_password.luks_passphrase.result
  sensitive = true
}