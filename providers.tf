terraform {
  required_providers {
    splunk = {
      source  = "splunk/splunk"
      version = "1.4.22"
    }
    pagerduty = {
      source  = "pagerduty/pagerduty"
      version = ">= 2.2.1"
    }
  }
}

provider "splunk" {
  url                  = "localhost:8089"
  username             = var.splunk_username
  password             = var.splunk_password
  insecure_skip_verify = true
}

provider "pagerduty" {
  token = var.pagerduty_token
}
