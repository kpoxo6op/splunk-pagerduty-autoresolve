resource "splunk_saved_searches" "search" {
  name        = "Boris As Code Errors"
  search      = <<-EOT
    | makeresults count=1
    | eval random_number=random() % 2
    | appendpipe [| makeresults count=100 | where random_number == 1]
    | where random_number == 1
    | stats count as event_count
    | eval event_action=case(
        event_count>0, "trigger",
        1=1, "resolve"
      )
    | eval _key="boris_as_code_error_rate"
    | eval date_last_run=now()
    | join type=left _key
        [| inputlookup state_alert
        | rename event_action AS event_action_lookup
        | rename date_last_change AS date_last_change_lookup
        | fields _key, event_action_lookup, date_last_change_lookup]
    | eval date_last_change=case(
        event_action!=event_action_lookup, now(),
        1=1, date_last_change_lookup
      )
    | outputlookup state_alert append=true key_field=_key
    | where event_action!=event_action_lookup
    | table event_action, date_last_run, date_last_change
  EOT
  actions     = "pagerduty"
  description = "Boris As Code Errors Alert resolvable by PagerDuty"
}

resource "splunk_configs_conf" "kvstore-collections-stanza" {
  # /opt/splunk/etc/apps/search/local/collections.conf
  name = "collections/state_alert"
  variables = {
    "field._key" : "string"
    "field.event_action" : "string"
    "field.date_last_change" : "number"
    "field.date_last_run" : "number"
  }
}

resource "splunk_configs_conf" "kvstore-transforms-stanza" {
  # /opt/splunk/etc/apps/search/local/transforms.conf
  name = "transforms/state_alert"
  variables = {
    "collection" : "state_alert"
    "external_type" : "kvstore"
    "fields_list" : "_key,event_action,date_last_change,date_last_run"
  }
}

resource "splunk_configs_conf" "alert" {
  # /opt/splunk/etc/apps/search/local/savedsearches.conf
  name = "savedsearches/Boris As Code Errors Alert (Terraform)"
  variables = {
    "action.pagerduty"                                = "1"
    "action.pagerduty.param.custom_details"           = "{\"action\": \"$result.event_action$\"}"
    "action.pagerduty.param.integration_key_override" = pagerduty_service_integration.splunk.integration_key
    "action.summary_index.inline"                     = "0"
    "action.webhook.enable_allowlist"                 = "0"
    "alert.digest_mode"                               = "0"
    "alert.suppress"                                  = "1"
    "alert.suppress.fields"                           = "*"
    "alert.suppress.period"                           = "60s"
    "alert.track"                                     = "1"
    "cron_schedule"                                   = "* * * * *"
    "description"                                     = "Boris As Code Errors Alert resolvable by PagerDuty"
    "dispatch.earliest_time"                          = "rt"
    "dispatch.indexedRealtime"                        = "0"
    "dispatch.latest_time"                            = "rt"
    "dispatch.lookups"                                = "0"
    "dispatch.spawn_process"                          = "0"
    "display.general.type"                            = "statistics"
    "display.page.search.tab"                         = "statistics"
    "enableSched"                                     = "1"
    "quantity"                                        = "0"
    "realtime_schedule"                               = "0"
    "relation"                                        = "greater than"
    "request.ui_dispatch_app"                         = "search"
    "request.ui_dispatch_view"                        = "search"
    "restart_on_searchpeer_add"                       = "0"
    "search"                                          = <<-EOT
| makeresults count=1
| eval random_number=random() % 2
| appendpipe [| makeresults count=100 | where random_number == 1]
| where random_number == 1
| stats count as event_count
| eval event_action=case(
    event_count>0, "trigger",
    1=1, "resolve"
  )
| eval _key="boris_as_code_error_rate"
| eval date_last_run=now()
| join type=left _key
    [| inputlookup state_alert
    | rename event_action AS event_action_lookup
    | rename date_last_change AS date_last_change_lookup
    | fields _key, event_action_lookup, date_last_change_lookup]
| eval date_last_change=case(
    event_action!=event_action_lookup, now(),
    1=1, date_last_change_lookup
  )
| outputlookup state_alert append=true key_field=_key
| where event_action!=event_action_lookup
| table event_action
EOT
  }
}
