terraform {
  required_version = ">= 1.0"
  
  backend "gcs" {
    bucket = "acoustic-arch-460909-u4-terraform-state"
    prefix = "terraform/state"
  }
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "sql-component.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com"
  ])

  service = each.value
  project = var.project_id

  disable_dependent_services = true
}

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "app_repo" {
  location      = var.region
  repository_id = "${var.app_name}-repo"
  description   = "Docker repository for ${var.app_name}"
  format        = "DOCKER"

  depends_on = [google_project_service.apis]
}

# Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "postgres" {
  name             = "${var.app_name}-db"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = var.db_tier
    
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = 7
      }
    }

    ip_configuration {
      ipv4_enabled    = true
      authorized_networks {
        value = "0.0.0.0/0"
        name  = "all"
      }
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }

  deletion_protection = false

  depends_on = [google_project_service.apis]
}

# Database
resource "google_sql_database" "database" {
  name     = var.database_name
  instance = google_sql_database_instance.postgres.name
}

# Database user
resource "google_sql_user" "user" {
  name     = var.database_user
  instance = google_sql_database_instance.postgres.name
  password = var.database_password
}

# Secret Manager secrets
resource "google_secret_manager_secret" "database_url" {
  secret_id = "${var.app_name}-database-url"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret = google_secret_manager_secret.database_url.id
  secret_data = "postgresql://${var.database_user}:${var.database_password}@${google_sql_database_instance.postgres.public_ip_address}:5432/${var.database_name}"
  
  depends_on = [
    google_sql_database.database,
    google_sql_user.user
  ]
}

resource "google_secret_manager_secret" "postgres_password" {
  secret_id = "${var.app_name}-postgres-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "postgres_password" {
  secret = google_secret_manager_secret.postgres_password.id
  secret_data = var.database_password
}

resource "google_secret_manager_secret" "secret_key_base" {
  secret_id = "${var.app_name}-secret-key-base"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "secret_key_base" {
  secret = google_secret_manager_secret.secret_key_base.id
  secret_data = var.secret_key_base
}

# Additional secrets for your application
resource "google_secret_manager_secret" "openai_api_key" {
  secret_id = "${var.app_name}-openai-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "openai_base_url" {
  secret_id = "${var.app_name}-openai-base-url"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "openai_model" {
  secret_id = "${var.app_name}-openai-model"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "openai_max_tokens" {
  secret_id = "${var.app_name}-openai-max-tokens"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "openai_temperature" {
  secret_id = "${var.app_name}-openai-temperature"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

# Create empty secrets - values will be set manually in GCP Console
resource "google_secret_manager_secret_version" "openai_api_key" {
  secret = google_secret_manager_secret.openai_api_key.id
  secret_data = "PLACEHOLDER_SET_IN_GCP_CONSOLE"
  
  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_version" "openai_base_url" {
  secret = google_secret_manager_secret.openai_base_url.id
  secret_data = "PLACEHOLDER_SET_IN_GCP_CONSOLE"
  
  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_version" "openai_model" {
  secret = google_secret_manager_secret.openai_model.id
  secret_data = "PLACEHOLDER_SET_IN_GCP_CONSOLE"
  
  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_version" "openai_max_tokens" {
  secret = google_secret_manager_secret.openai_max_tokens.id
  secret_data = "PLACEHOLDER_SET_IN_GCP_CONSOLE"
  
  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_version" "openai_temperature" {
  secret = google_secret_manager_secret.openai_temperature.id
  secret_data = "PLACEHOLDER_SET_IN_GCP_CONSOLE"
  
  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret" "google_client_id" {
  secret_id = "${var.app_name}-google-client-id"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "google_client_id" {
  secret = google_secret_manager_secret.google_client_id.id
  secret_data = "PLACEHOLDER_SET_IN_GCP_CONSOLE"
  
  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret" "google_client_secret" {
  secret_id = "${var.app_name}-google-client-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "google_client_secret" {
  secret = google_secret_manager_secret.google_client_secret.id
  secret_data = "PLACEHOLDER_SET_IN_GCP_CONSOLE"
  
  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret" "recall_api_key" {
  secret_id = "${var.app_name}-recall-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "recall_api_key" {
  secret = google_secret_manager_secret.recall_api_key.id
  secret_data = "PLACEHOLDER_SET_IN_GCP_CONSOLE"
  
  lifecycle {
    ignore_changes = [secret_data]
  }
}

# Cloud Run service
resource "google_cloud_run_v2_service" "app" {
  name     = var.app_name
  location = var.region

  template {
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app_repo.repository_id}/${var.app_name}:latest"
      
      ports {
        container_port = 4000
      }

      env {
        name  = "PHX_HOST"
        value = var.app_domain
      }

      env {
        name  = "PORT"
        value = "4000"
      }

      env {
        name  = "MIX_ENV"
        value = "prod"
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "POSTGRES_HOST"
        value = google_sql_database_instance.postgres.public_ip_address
      }

      env {
        name  = "POSTGRES_DB"
        value = var.database_name
      }

      env {
        name  = "POSTGRES_USER"
        value = var.database_user
      }

      env {
        name = "POSTGRES_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.postgres_password.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "POSTGRES_PORT"
        value = "5432"
      }

      env {
        name  = "INSTANCE_CONNECTION_NAME"
        value = google_sql_database_instance.postgres.connection_name
      }

      env {
        name = "SECRET_KEY_BASE"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.secret_key_base.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "OPENAI_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.openai_api_key.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "OPENAI_BASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.openai_base_url.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "OPENAI_MODEL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.openai_model.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "OPENAI_MAX_TOKENS"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.openai_max_tokens.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "OPENAI_TEMPERATURE"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.openai_temperature.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "GOOGLE_CLIENT_ID"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.google_client_id.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "GOOGLE_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.google_client_secret.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "RECALL_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.recall_api_key.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [google_project_service.apis]
}

# IAM policy for Cloud Run (allow public access)
resource "google_cloud_run_service_iam_member" "public" {
  location = google_cloud_run_v2_service.app.location
  project  = google_cloud_run_v2_service.app.project
  service  = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
} 