resource "google_cloud_run_v2_service" "app" {
  name     = "app"
  location = "us-west1"
  # すべてのユーザー（インターネットからのアクセス）がこのCloudRun上で動作するアプリケーションにアクセスできるように
  ingress = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      # テスト用にGCPから提供されているCloudRunのテストイメージを使用
      image = "us-docker.pkg.dev/cloudrun/container/hello"
    }
  }
}
