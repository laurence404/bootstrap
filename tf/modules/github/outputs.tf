output "ssh_deploy_key" {
  value     = tls_private_key.deploy_key.private_key_openssh
  sensitive = true
}

output "ssh_clone_url" {
  value = github_repository.gitops.ssh_clone_url
}