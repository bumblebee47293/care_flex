variable "app_name" {
  description = "Fly.io application name"
  type        = string
  default     = "careflex"
}

variable "fly_org" {
  description = "Fly.io organization slug"
  type        = string
}

variable "primary_region" {
  description = "Primary region for deployment"
  type        = string
  default     = "iad" # US East (Ashburn, VA)
}

variable "secret_key_base" {
  description = "Phoenix secret key base"
  type        = string
  sensitive   = true
}

variable "cloak_key" {
  description = "Cloak encryption key (base64 encoded)"
  type        = string
  sensitive   = true
}

variable "guardian_secret" {
  description = "Guardian JWT secret key"
  type        = string
  sensitive   = true
}

variable "custom_domain" {
  description = "Custom domain for the application (optional)"
  type        = string
  default     = ""
}
