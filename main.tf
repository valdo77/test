# This file is used to initialize the deployment

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.0.0"
    }
  }
}

provider "google" {
  project = "<GCP_PROJECT_ID>"
}

variable "database_choosed" {
  type = object(
    {
      sql       = bool
      firestore = bool
    }
  )
  default = {
    sql       = "PostgreSQL" == "PostgreSQL" || "PostgreSQL" == "Both" ? true : false
    firestore = "PostgreSQL" == "Firestore" || "PostgreSQL" == "Both" ? true : false
  }
}

# Deploy the SQL instance if choosed from cookiecutter
resource "google_sql_database_instance" "instance" {
  count            = var.database_choosed.sql ? 1 : 0
  name             = "fastapi-template-instance"
  project          = "<GCP_PROJECT_ID>"
  region           = "europe-west9"
  database_version = "POSTGRES_15"
  settings {
    tier = "db-f1-micro"
  }

  deletion_protection = "false"
}
resource "google_sql_database" "database" {
  count    = var.database_choosed.sql ? 1 : 0
  name     = "fastapi_template_db"
  instance = google_sql_database_instance.instance[0].name
}
resource "google_sql_user" "updated_user" {
  count    = var.database_choosed.sql ? 1 : 0
  name     = "postgres"
  instance = google_sql_database_instance.instance[0].name
  password = "postgres"
}

# Deploy the Firestore instance if choosed from cookiecutter
resource "google_firestore_database" "database" {
  count       = var.database_choosed.firestore ? 1 : 0
  project     = "<GCP_PROJECT_ID>"
  name        = "(default)"
  location_id = "eur3"
  type        = "FIRESTORE_NATIVE"
}

resource "google_firestore_document" "user_doc_exemple" {
  count       = var.database_choosed.firestore ? 1 : 0
  project     = "<GCP_PROJECT_ID>"
  database    = google_firestore_database.database[0].name
  collection  = "Users"
  document_id = "jean.dupont@gmail.com"
  fields = jsonencode({
    "created_at" = { timestampValue = timestamp() }, // Replace with actual creation timestamp
    "updated_at" = { timestampValue = timestamp() }, // Replace with actual update timestamp
    "first_name" = { stringValue = "Jean" },
    "last_name"  = { stringValue = "Dupont" },
    "email"      = { stringValue = "jean.dupont@gmail.com" },
  })
}

resource "google_artifact_registry_repository" "cookiecutter-repo" {
  location      = "europe"
  repository_id = "fastapi-template-repository"
  description   = "Images for building fastapi-template Cloud Run service"
  format        = "DOCKER"
}

resource "null_resource" "build_push_image" {
  provisioner "local-exec" {
    command = <<-EOT
      gcloud auth configure-docker europe-docker.pkg.dev
      docker build --platform linux/amd64 -t "europe-docker.pkg.dev/<GCP_PROJECT_ID>/fastapi-template-repository/fastapi-template" -f Dockerfile.prod .
      docker push "europe-docker.pkg.dev/<GCP_PROJECT_ID>/fastapi-template-repository/fastapi-template"
    EOT
  }
}

resource "google_cloud_run_service" "backend_service" {
  name     = "fastapi-template"
  location = "europe-west9"

  template {
    spec {
      containers {
        image = "europe-docker.pkg.dev/<GCP_PROJECT_ID>/fastapi-template-repository/fastapi-template"
      }
    }
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"      = "1000"
        "run.googleapis.com/cloudsql-instances" = var.database_choosed.sql ? google_sql_database_instance.instance[0].connection_name : ""
        "run.googleapis.com/client-name"        = "terraform"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [null_resource.build_push_image]
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_service.backend_service.location
  project  = google_cloud_run_service.backend_service.project
  service  = google_cloud_run_service.backend_service.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_secret_manager_secret" "backend_secret" {
  secret_id = "fastapi-template"

  replication {
    auto {}
  }
}

# Cloud Build Trigger exemple
resource "google_cloudbuild_trigger" "cloudbuild_trigger" {
  name = "fastapi-template"
  trigger_template {
    branch_name = "main"
    repo_name   = "valdo77/test"
  }
  filename = ".cloudbuild/cloudbuild.yaml"
}
