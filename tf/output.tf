output "talosconfig" {
  value     = module.talos.talosconfig
  sensitive = true
}

output "luks_passphrase" {
  value     = module.talos.luks_passphrase
  sensitive = true
}