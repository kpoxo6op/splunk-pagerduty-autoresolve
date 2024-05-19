# Splunk Docker Compose Setup

## Terraform

Create seach and KV store with Terraform

## Test Collection

```sh
export APP_NAME=search
export COLLECTION=state_alert
export BASE_URL=https://localhost:8089/servicesNS/nobody/$APP_NAME
export CREDS="admin:abcd1234"

# Write
curl -k -u $CREDS \
    $BASE_URL/storage/collections/data/$COLLECTION \
    -H 'Content-Type: application/json' \
    -d '{"_key": "your_unique_dedup_key", "event_action": "resolve", "date_last_change": 1650000000, "date_last_run": 1650000000}'

# Get
curl -k -u $CREDS $BASE_URL/storage/collections/data/$COLLECTION | jq

# Delete
curl -k -u $CREDS -X DELETE $BASE_URL/storage/collections/data/$COLLECTION

# Splunk config reload required
# http://localhost:8000/en-GB/debug/refresh
```

# 