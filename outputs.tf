# outputs.tf
# Defines output values that will be displayed after Terraform applies the configuration.

output "web_tier_external_ip" {
  description = "The external (public) IP address of the MyVibe Web Tier instance."
  value       = google_compute_instance.web_instance.network_interface[0].access_config[0].nat_ip
}

output "web_tier_internal_ip" {
  description = "The internal IP address of the MyVibe Web Tier instance."
  value       = google_compute_instance.web_instance.network_interface[0].network_ip
}

output "app_tier_internal_ip" {
  description = "The internal IP address of the MyVibe App Tier instance."
  value       = google_compute_instance.app_instance.network_interface[0].network_ip
}

output "db_tier_internal_ip" {
  description = "The internal IP address of the MyVibe DB Tier instance."
  value       = google_compute_instance.db_instance.network_interface[0].network_ip
}

