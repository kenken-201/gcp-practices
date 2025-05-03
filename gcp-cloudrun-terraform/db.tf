resource "google_sql_database_instance" "main" {
  project          = var.project_id
  name             = "main-db"
  region           = "us-west1"
  database_version = "MYSQL_8_0"

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      private_network = google_compute_network.vpc_network.id
      # Public IPを持たない、Private IPのみCloudSQLを作成するため、ipv4_enabledはfalse
      ipv4_enabled    = false
    }
  }
}

resource "google_sql_user" "kenken" {
  project = var.project_id

  name     = "kenken"
  instance = google_sql_database_instance.main.name
  password = "password_kenken"
}

resource "google_sql_database" "maindb" {
  project = var.project_id

  name     = "maindb"
  instance = google_sql_database_instance.main.name
}
