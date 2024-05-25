resource "splunk_saved_searches" "search" {
  name   = "Boris As Code Errors"
  search = <<-EOT
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
  # actions = "pagerduty"
  # action_pagerduty_integration_url = "https://events.pagerduty.com/integration/92348d67ea9f4b0ed01008c8b440f353/enqueue"
  # cron_schedule = "*/5 * * * *"
  # alert_condition = "search count > 10"
  # description = "Boris As Code Errors Alert resolvable by PagerDuty"
  #{"action": "$result.event_action$"}
  # action_pagerduty_custom_details = "{\"action\": \"$result.event_action$\"}"
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