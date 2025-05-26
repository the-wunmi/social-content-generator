variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "app_name" {
  description = "The name of the application"
  type        = string
  default     = "social-content-generator"
}

variable "app_domain" {
  description = "The domain where the app will be hosted"
  type        = string
}

variable "database_name" {
  description = "The name of the database"
  type        = string
  default     = "social_content_generator_prod"
}

variable "database_user" {
  description = "The database user"
  type        = string
  default     = "postgres"
}

variable "database_password" {
  description = "The database password"
  type        = string
  sensitive   = true
}

variable "secret_key_base" {
  description = "Phoenix secret key base"
  type        = string
  sensitive   = true
}

variable "db_tier" {
  description = "The database tier"
  type        = string
  default     = "db-f1-micro"
} 