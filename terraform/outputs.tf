output "app_url" {
  description = "The URL of the deployed application"
  value       = google_cloud_run_v2_service.app.uri
}

output "database_connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.connection_name
}

output "database_ip" {
  description = "The IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.ip_address
}

output "artifact_registry_url" {
  description = "The URL of the Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app_repo.repository_id}"
} 