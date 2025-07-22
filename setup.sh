#!/bin/bash

# enable_gcp_services.sh
# This script enables necessary GCP APIs and validates the Terraform plan.

# --- Configuration ---
# Replace 'YOUR_GCP_PROJECT_ID' with your actual GCP project ID.
# Alternatively, the script will try to use the currently configured gcloud project.
GCP_PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null)}"

# List of required GCP services (APIs)
REQUIRED_SERVICES=(
  "compute.googleapis.com" # Required for Compute Engine instances, networks, firewalls
  "iam.googleapis.com"     # Required for Service Accounts and IAM roles
)

# --- Functions ---

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to enable a single service
enable_service() {
  local service_name=$1
  echo "Attempting to enable service: ${service_name}..."
  if gcloud services enable "${service_name}" --project="${GCP_PROJECT_ID}" --async; then
    echo "Service ${service_name} enablement initiated successfully (asynchronous)."
  else
    echo "Error enabling service: ${service_name}. Please check permissions or try again."
    return 1
  fi
}

# --- Main Script Logic ---

echo "--- GCP Service Enablement and Terraform Validation Script ---"

# 1. Validate gcloud CLI presence
if ! command_exists gcloud; then
  echo "Error: gcloud CLI not found. Please install it to proceed."
  exit 1
fi

# 2. Validate Terraform CLI presence
if ! command_exists terraform; then
  echo "Error: Terraform CLI not found. Please install it to proceed."
  exit 1
fi

# 3. Set and confirm GCP Project ID
if [ -z "${GCP_PROJECT_ID}" ]; then
  echo "Error: GCP Project ID not set. Please provide it as an argument or configure gcloud."
  echo "Usage: ./enable_gcp_services.sh [YOUR_GCP_PROJECT_ID]"
  exit 1
fi

echo "Using GCP Project ID: ${GCP_PROJECT_ID}"
gcloud config set project "${GCP_PROJECT_ID}"

# 4. Enable Required Services
echo ""
echo "--- Enabling required GCP APIs ---"
ALL_SERVICES_ENABLED=true
for service in "${REQUIRED_SERVICES[@]}"; do
  enable_service "${service}" || ALL_SERVICES_ENABLED=false
done

if [ "$ALL_SERVICES_ENABLED" = true ]; then
  echo ""
  echo "All service enablement requests sent. It may take a few moments for them to become active."
  echo "Waiting for services to become active (this can take 1-2 minutes)..."
  # A brief sleep to allow asynchronous operations to start
  sleep 60
else
  echo ""
  echo "Some services failed to initiate enablement. Please review the errors above."
  echo "You might need to manually enable them or check your permissions."
  exit 1
fi

# 5. Initialize Terraform (if not already initialized)
echo ""
echo "--- Initializing Terraform ---"
if [ ! -d ".terraform" ]; then
  echo "Terraform not initialized. Running 'terraform init'..."
  terraform init
  if [ $? -ne 0 ]; then
    echo "Error: 'terraform init' failed. Please resolve the issue."
    exit 1
  fi
else
  echo "Terraform already initialized."
fi

# 6. Validate Terraform Plan
echo ""
echo "--- Validating Terraform Plan ---"
echo "Running 'terraform plan' to check for deployment readiness..."
terraform plan -var="project_id=${GCP_PROJECT_ID}"

if [ $? -eq 0 ]; then
  echo ""
  echo "-------------------------------------------------------------------"
  echo "SUCCESS: GCP services are enabled (or enablement initiated) and"
  echo "         Terraform plan ran successfully. You are ready to deploy!"
  echo "         Run 'terraform apply -var=\"project_id=${GCP_PROJECT_ID}\"' to deploy."
  echo "-------------------------------------------------------------------"
else
  echo ""
  echo "-------------------------------------------------------------------"
  echo "ERROR: Terraform plan failed. Please review the output above for errors."
  echo "       Common issues include: permissions, quota, or syntax errors."
  echo "-------------------------------------------------------------------"
  exit 1
fi


