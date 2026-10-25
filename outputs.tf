output "jenkins_public_ip" {
  description = "Public IP address of the Jenkins VM."
  value       = azurerm_public_ip.jenkins.ip_address
}

output "jenkins_url" {
  description = "Jenkins web interface, restricted to admin_source_cidr."
  value       = "http://${azurerm_public_ip.jenkins.ip_address}:8080"
}

output "ssh_command" {
  description = "SSH command for the VM administrator."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.jenkins.ip_address}"
}
