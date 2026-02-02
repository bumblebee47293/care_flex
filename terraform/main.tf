# Terraform Configuration for Fly.io Deployment

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    fly = {
      source  = "fly-apps/fly"
      version = "~> 0.1"
    }
  }
}

# Configure Fly.io provider
provider "fly" {
  # FLY_API_TOKEN environment variable is used for authentication
}

# Fly.io application
resource "fly_app" "careflex" {
  name = var.app_name
  org  = var.fly_org
}

# PostgreSQL database
resource "fly_postgres" "careflex_db" {
  name   = "${var.app_name}-db"
  org    = var.fly_org
  region = var.primary_region
  
  # Production configuration
  vm_size       = "shared-cpu-2x"
  volume_size   = 10
  initial_cluster_size = 2
}

# Attach database to application
resource "fly_postgres_attachment" "careflex_db_attachment" {
  app      = fly_app.careflex.name
  postgres = fly_postgres.careflex_db.name
}

# Application secrets
resource "fly_secret" "secret_key_base" {
  app   = fly_app.careflex.name
  name  = "SECRET_KEY_BASE"
  value = var.secret_key_base
}

resource "fly_secret" "cloak_key" {
  app   = fly_app.careflex.name
  name  = "CLOAK_KEY"
  value = var.cloak_key
}

resource "fly_secret" "guardian_secret" {
  app   = fly_app.careflex.name
  name  = "GUARDIAN_SECRET_KEY"
  value = var.guardian_secret
}

# Application volumes for persistent storage
resource "fly_volume" "careflex_data" {
  name   = "careflex_data"
  app    = fly_app.careflex.name
  size   = 1
  region = var.primary_region
}

# IP addresses
resource "fly_ip" "careflex_ipv4" {
  app  = fly_app.careflex.name
  type = "v4"
}

resource "fly_ip" "careflex_ipv6" {
  app  = fly_app.careflex.name
  type = "v6"
}

# Certificate for custom domain (optional)
resource "fly_cert" "careflex_cert" {
  count    = var.custom_domain != "" ? 1 : 0
  app      = fly_app.careflex.name
  hostname = var.custom_domain
}

# Outputs
output "app_name" {
  value       = fly_app.careflex.name
  description = "Fly.io application name"
}

output "app_url" {
  value       = "https://${fly_app.careflex.name}.fly.dev"
  description = "Application URL"
}

output "database_name" {
  value       = fly_postgres.careflex_db.name
  description = "PostgreSQL database name"
}

output "ipv4_address" {
  value       = fly_ip.careflex_ipv4.address
  description = "IPv4 address"
}

output "ipv6_address" {
  value       = fly_ip.careflex_ipv6.address
  description = "IPv6 address"
}
