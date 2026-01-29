# ============================================
# GCP Terraform Tutorial
# ============================================
# Creates real GCP resources (Cloud Storage bucket)
# Cost: Free tier / minimal
# ============================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# ============================================
# PROVIDER CONFIGURATION
# ============================================

provider "google" {
  project = var.project_id
  region  = var.region
}

# ============================================
# VARIABLES
# ============================================

variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "GCP region"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment (dev, staging, prod)"
}

# ============================================
# LOCALS
# ============================================

locals {
  # Bucket names must be globally unique
  bucket_prefix = "tf-learn-${var.project_id}"
}

# ============================================
# RESOURCES
# ============================================

# Random suffix for globally unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Cloud Storage Bucket
resource "google_storage_bucket" "demo" {
  name          = "${local.bucket_prefix}-${random_id.bucket_suffix.hex}"
  location      = var.region
  force_destroy = true  # Allow deletion even if not empty (for learning)

  # Use Standard storage class (free tier eligible)
  storage_class = "STANDARD"

  # Enable versioning (best practice)
  versioning {
    enabled = true
  }

  # Lifecycle rule: delete old versions after 30 days
  lifecycle_rule {
    condition {
      age = 30
      with_state = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # Labels for organization
  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "learning"
  }

  # Uniform bucket-level access (recommended)
  uniform_bucket_level_access = true
}

# Upload a sample file to the bucket
resource "google_storage_bucket_object" "sample" {
  name    = "hello.txt"
  bucket  = google_storage_bucket.demo.name
  content = <<-EOT
    Hello from Terraform!

    Bucket: ${google_storage_bucket.demo.name}
    Region: ${var.region}
    Environment: ${var.environment}
    Created: ${timestamp()}
  EOT
}

# ============================================
# OUTPUTS
# ============================================

output "bucket_name" {
  value       = google_storage_bucket.demo.name
  description = "The name of the created bucket"
}

output "bucket_url" {
  value       = google_storage_bucket.demo.url
  description = "The URL of the bucket"
}

output "bucket_self_link" {
  value       = google_storage_bucket.demo.self_link
  description = "The self link of the bucket"
}

output "sample_file_url" {
  value       = "gs://${google_storage_bucket.demo.name}/${google_storage_bucket_object.sample.name}"
  description = "GCS URL of the sample file"
}

output "console_url" {
  value       = "https://console.cloud.google.com/storage/browser/${google_storage_bucket.demo.name}?project=${var.project_id}"
  description = "URL to view bucket in GCP Console"
}
