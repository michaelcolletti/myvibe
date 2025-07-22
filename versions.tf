# versions.tf
# Specifies the required Terraform version and provider versions.
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0" # Use a compatible version for the Google Cloud provider
    }
  }
  required_version = ">= 1.0.0" # Minimum Terraform CLI version
}
