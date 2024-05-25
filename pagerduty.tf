data "pagerduty_service" "default" {
  name = "Default Service"
}

resource "pagerduty_event_orchestration" "resolve" {
  name        = "Resolve Splunk alerts"
  description = "Resolve Splunk alerts by looking into message custom_details"
}

resource "pagerduty_event_orchestration_router" "default_router" {
  event_orchestration = pagerduty_event_orchestration.resolve.id
  set {
    id = "start"
  }
  catch_all {
    actions {
      route_to = data.pagerduty_service.default.id
    }
  }
}

resource "pagerduty_event_orchestration_service" "resolve" {
  service = data.pagerduty_service.default.id
  set {
    id = "start"
    rule {
      label = "Autotoresolve Splunk Alerts"
      condition {
        expression = "event.custom_details.event_action matches 'resolve'"
      }
      actions {
        event_action = "resolve"
      }
    }
  }

  catch_all {
    actions {

    }
  }
}
