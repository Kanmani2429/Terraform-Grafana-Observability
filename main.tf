terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "4.53.0"
    }
  }
}



provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_auth
}



resource "grafana_folder" "my_folder" {
  title = "Payments Trend"
}

resource "grafana_dashboard" "my_dashboard" {
  folder = grafana_folder.my_folder.uid

  config_json = file("${path.module}/dashboard.json")
}

resource "grafana_contact_point" "slack_alerts" {
  name = "Slack_Terraform_Alerts"

  slack {
    url   = var.slack_webhook_url
    title = "{{ template \"default.title\" . }}"
    text  = "{{ template \"default.message\" . }}"
  }
}

resource "grafana_rule_group" "my_rule_group" {
  org_id           = 1
  name             = "Evaluation_TF"
  folder_uid       = grafana_folder.my_folder.uid
  interval_seconds = var.interval_seconds
  depends_on = [
    grafana_contact_point.slack_alerts
  ]

  rule {
    name      = "Payments Trend by Country"
    condition = "C"

    data {
      ref_id = "A"

      relative_time_range {
        from = 21600
        to   = 0
      }

      datasource_uid = "PBFA97CFB590B2093"
      model = jsonencode({
        datasource = {
          type = "prometheus"
          uid  = "PBFA97CFB590B2093"
        }

        expr           = "sum(rate(shoehub_payments[5m])) by (CountryCode)"
        format         = "time_series"
        instant        = true
        interval       = ""
        intervalFactor = 1
        intervalMs     = 15000
        legendFormat   = "{{CountryCode}}"
        maxDataPoints  = 43200
        range          = false
        refId          = "A"
      })
    }
    data {
      ref_id     = "C"
      query_type = "expression"

      relative_time_range {
        from = 0
        to   = 0
      }

      datasource_uid = "__expr__"
      model = jsonencode({
        conditions = [{
          evaluator = {
            params = [200]
            type   = "gt"
          }

          operator = {
            type = "and"
          }

          query = {
            params = ["A"]
          }

          reducer = {
            params = []
            type   = "last"
          }

          type = "query"
        }]

        datasource = {
          type = "__expr__"
          uid  = "__expr__"
        }

        expression    = "A"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "NoData"
    exec_err_state = "Error"
    for            = "30s"
    annotations = {
      __dashboardUid__ = grafana_dashboard.my_dashboard.uid
      __panelId__      = "7"
    }
    labels    = {}
    is_paused = false

    notification_settings {
      contact_point = grafana_contact_point.slack_alerts.name

      group_by = [
        "alertname",
        "grafana_folder"
      ]

      group_wait      = var.group_wait
      group_interval  = var.group_interval
      repeat_interval = var.repeat_interval
    }


  }
}