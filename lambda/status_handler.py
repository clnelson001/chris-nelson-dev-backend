import json
import os
import boto3
from datetime import datetime

cloudwatch = boto3.client("cloudwatch")
ALARM_NAME = os.environ["ALARM_NAME"]


def lambda_handler(event, context):
    resp = cloudwatch.describe_alarms(AlarmNames=[ALARM_NAME])
    alarms = resp.get("MetricAlarms", [])

    if not alarms:
        status = "UNKNOWN"
        reason = "Alarm not found"
        updated = None
    else:
        alarm = alarms[0]
        status = alarm.get("StateValue", "UNKNOWN")  # OK, ALARM, INSUFFICIENT_DATA
        reason = alarm.get("StateReason", "")
        updated_ts = alarm.get("StateUpdatedTimestamp")
        if isinstance(updated_ts, datetime):
            updated = updated_ts.isoformat()
        else:
            updated = None

    body = {
        "status": status,
        "reason": reason,
        "updated": updated,
    }

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }


def get_waf_status():
    enabled = os.getenv("WAF_ENABLED", "false").lower() == "true"
    countries_raw = os.getenv("WAF_BLOCK_COUNTRIES", "")
    blocked_countries = [c for c in countries_raw.split(",") if c]

    if not enabled:
        return {
            "enabled": False,
            "blocked_countries": [],
            "message": "WAF disabled in infrastructure configuration",
        }

    if not blocked_countries:
        return {
            "enabled": True,
            "blocked_countries": [],
            "message": "WAF enabled with no geo blocking",
        }

    return {
        "enabled": True,
        "blocked_countries": blocked_countries,
        "message": "WAF enabled with geo blocking",
    }

