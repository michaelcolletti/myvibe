# variables.tf
# Defines input variables for the Terraform configuration.

variable "project_id" {
  description = "The GCP project ID where resources will be deployed."
  type        = string
}

variable "region" {
  description = "The GCP region for deploying resources (e.g., us-central1, us-east1)."
  type        = string
  default     = "us-central1" # A common free-tier eligible region
}

variable "zone" {
  description = "The GCP zone within the specified region for VM instances."
  type        = string
  default     = "us-central1-a" # A common free-tier eligible zone
}

