# Splunk Docker Compose Setup

## Create a sample KV Store collection using the Splunk REST API:

```sh
# Set variables for convenience
SPLUNK_HOST=localhost
SPLUNK_PORT=8089
SPLUNK_USER=admin
SPLUNK_PASSWORD=changeme123
APP_NAME=kvstoretest
COLLECTION_NAME=kvstorecoll

# Create a new collection
curl -k -u $SPLUNK_USER:$SPLUNK_PASSWORD \
    -d name=$COLLECTION_NAME \
    https://$SPLUNK_HOST:$SPLUNK_PORT/servicesNS/nobody/$APP_NAME/storage/collections/config

# Define the collection schema
curl -k -u $SPLUNK_USER:$SPLUNK_PASSWORD \
    https://$SPLUNK_HOST:$SPLUNK_PORT/servicesNS/nobody/$APP_NAME/storage/collections/config/$COLLECTION_NAME \
    -d 'field.id=number' \
    -d 'field.name=string' \
    -d 'field.address=string' \
    -d 'accelerated_fields.my_accel={"id": 1}'

# Add sample data to the collection
curl -k -u $SPLUNK_USER:$SPLUNK_PASSWORD \
    https://$SPLUNK_HOST:$SPLUNK_PORT/servicesNS/nobody/$APP_NAME/storage/collections/data/$COLLECTION_NAME \
    -H 'Content-Type: application/json' \
    -d '{"name": "Splunk HQ", "id": 123, "address": { "street": "250 Brannan Street", "city": "San Francisco", "state": "CA", "zip": "94107"}}'

# Create the lookup definition
curl -k -u $SPLUNK_USER:$SPLUNK_PASSWORD \
    https://$SPLUNK_HOST:$SPLUNK_PORT/servicesNS/nobody/$APP_NAME/data/transforms/lookups \
    -d "name=kvstorecoll" \
    -d "collection=kvstorecoll" \
    -d "external_type=kvstore" \
    -d "fields_list=id,name,address.street,address.city,address.state,address.zip"
```

## Verify the KV Store Collection

Retrieve the data from the collection:

    ```bash
    curl -k -u $SPLUNK_USER:$SPLUNK_PASSWORD \
        https://$SPLUNK_HOST:$SPLUNK_PORT/servicesNS/nobody/$APP_NAME/storage/collections/data/$COLLECTION_NAME
    ```

This command should return the data you inserted, verifying that the KV Store collection is working correctly.

## Another collection

```sh
COLLECTION_NAME=state_alert
# Create a new collection
curl -k -u $SPLUNK_USER:$SPLUNK_PASSWORD \
    -d name=$COLLECTION_NAME \
    https://$SPLUNK_HOST:$SPLUNK_PORT/servicesNS/nobody/$APP_NAME/storage/collections/config

# Define the collection schema
curl -k -u $SPLUNK_USER:$SPLUNK_PASSWORD \
    https://$SPLUNK_HOST:$SPLUNK_PORT/servicesNS/nobody/$APP_NAME/storage/collections/config/$COLLECTION_NAME \
    -d 'field._key=string' \
    -d 'field.event_action=string' \
    -d 'field.date_last_change=number' \
    -d 'field.date_last_run=number'

# Add sample data to the collection
curl -k -u $SPLUNK_USER:$SPLUNK_PASSWORD \
    https://$SPLUNK_HOST:$SPLUNK_PORT/servicesNS/nobody/$APP_NAME/storage/collections/data/$COLLECTION_NAME \
    -H 'Content-Type: application/json' \
    -d '{"_key": "your_unique_dedup_key", "event_action": "resolve", "date_last_change": 1650000000, "date_last_run": 1650000000}'

# Create the lookup definition
curl -k -u $SPLUNK_USER:$SPLUNK_PASSWORD \
    https://$SPLUNK_HOST:$SPLUNK_PORT/servicesNS/nobody/$APP_NAME/data/transforms/lookups \
    -d "name=$COLLECTION_NAME" \
    -d "collection=$COLLECTION_NAME" \
    -d "external_type=kvstore" \
    -d "fields_list=_key,event_action,date_last_change,date_last_run"

# Test
curl -k -u $SPLUNK_USER:$SPLUNK_PASSWORD \
    https://$SPLUNK_HOST:$SPLUNK_PORT/servicesNS/nobody/$APP_NAME/storage/collections/data/$COLLECTION_NAME
```


# Splunk query to understand

```sh
/* This query aims to detect changes in the state of alerts by comparing the current state of ERROR events with the previous state stored in a KV Store collection. If the state has changed (e.g., from "resolve" to "trigger" or vice versa), it updates the KV Store and ensures that only new state changes trigger alerts, avoiding redundant alerts. */
index=_internal ERROR
| stats count as event_count
| eval dedup_key="your_unique_dedup_key"
| eval severity="warning"
| eval event_action=case(event_count>0, "trigger", 1=1, "resolve")
| eval summary="A summary of this event"
| eval source="servera.example.com"
| eval routing_key="YOUR_PAGERDUTY_ROUTING_KEY"
| eval _key=dedup_key
| eval date_last_run=now()
| join type=left _key
    [| inputlookup state_alert
    | rename event_action AS event_action_lookup
    | rename date_last_change AS date_last_change_lookup
    | fields _key, event_action_lookup, date_last_change_lookup]
| eval event_action_lookup=coalesce(event_action_lookup, "none")
| eval date_last_change=case(event_action!=event_action_lookup, now(), 1=1, date_last_change_lookup)
| outputlookup state_alert append=true key_field=_key
| where event_action!=event_action_lookup
| table dedup_key, severity, event_action, summary, source, routing_key, date_last_run, date_last_change
```