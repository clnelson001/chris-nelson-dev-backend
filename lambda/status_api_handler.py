import json
import os
import re
import socket
import ssl
import time
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Tuple

import boto3


# The site we are measuring for latency
HOSTNAME = "chris-nelson.dev"
PORT = 443
REQUEST_PATH = "/"

# Route 53 health check id is passed via environment variable
ROUTE53_HEALTH_CHECK_ID = os.environ.get("ROUTE53_HEALTH_CHECK_ID", "")
CF_DISTRIBUTION_ID = os.environ.get("CF_DISTRIBUTION_ID", "")
WAF_WEB_ACL_METRIC_NAME = os.environ.get("WAF_WEB_ACL_METRIC_NAME", "")
WAF_REGION = os.environ.get("WAF_REGION", "Global")
STATUS_API_FUNCTION_NAME = os.environ.get("STATUS_API_FUNCTION_NAME", "")
API_VERSION = os.environ.get("STATUS_API_VERSION", "v1")
# Metrics lookback window (minutes). CloudFront/WAF can be sparse, so use 60m.
METRIC_WINDOW_MINUTES = 60
CLOUDWATCH_REGION = "us-east-1"

route53 = boto3.client("route53")
# CloudFront and WAF metrics are global and must be queried from us-east-1
cloudwatch = boto3.client("cloudwatch", region_name=CLOUDWATCH_REGION)


def _iso_now() -> str:
    """Return current time in ISO 8601 format with UTC timezone."""
    return datetime.now(timezone.utc).isoformat()


def _measure_site() -> Tuple[float, float, int, str, str]:
    """
    Open a real TLS connection to chris-nelson.dev and measure:

    - TLS handshake time (ms)
    - Time to first byte (TTFB, ms, after handshake)
    - HTTP status code
    - HTTP reason phrase
    - Resolved peer IP

    If anything fails, we return synthetic values that clearly indicate
    an unhealthy state, but still conform to expected types.
    """
    try:
        addr_info = socket.getaddrinfo(HOSTNAME, PORT, type=socket.SOCK_STREAM)
        if not addr_info:
            raise RuntimeError("No address info for host")

        family, socktype, proto, _, sockaddr = addr_info[0]

        raw_sock = socket.socket(family, socktype, proto)
        raw_sock.settimeout(5.0)

        handshake_start = time.monotonic()
        raw_sock.connect(sockaddr)

        context = ssl.create_default_context()
        ssl_sock = context.wrap_socket(raw_sock, server_hostname=HOSTNAME)
        handshake_done = time.monotonic()

        tls_ms = (handshake_done - handshake_start) * 1000.0

        request = (
            f"GET {REQUEST_PATH} HTTP/1.1\r\n"
            f"Host: {HOSTNAME}\r\n"
            "Connection: close\r\n"
            "User-Agent: status-lambda/1.0\r\n"
            "\r\n"
        )

        ssl_sock.settimeout(5.0)
        ttfb_start = time.monotonic()
        ssl_sock.sendall(request.encode("ascii"))

        first_chunk = ssl_sock.recv(4096)
        ttfb_done = time.monotonic()

        if not first_chunk:
            raise RuntimeError("No data received from server")

        ttfb_ms = (ttfb_done - ttfb_start) * 1000.0

        first_line = first_chunk.split(b"\r\n", 1)[0].decode(
            "iso-8859-1", errors="replace"
        )
        parts = first_line.split(" ", 3)
        if len(parts) >= 2 and parts[0].startswith("HTTP/"):
            try:
                status_code = int(parts[1])
            except ValueError:
                status_code = 0
            reason = parts[2] if len(parts) >= 3 else ""
        else:
            status_code = 0
            reason = "Invalid HTTP response"

        peer_ip = ssl_sock.getpeername()[0]
        ssl_sock.close()

        return tls_ms, ttfb_ms, status_code, reason, peer_ip

    except Exception as exc:  # noqa: BLE001
        # Fallback synthetic values that clearly show a measurement failure
        return 0.0, 0.0, 503, f"Measurement error: {exc}", ""


def _region_name_from_code(region_code: str) -> str:
    """
    Map Route 53 Region code into a friendly name.
    Fallback to the code itself if we do not recognize it.
    """
    mapping = {
        "ap-northeast-1": "Asia Pacific (Tokyo)",
        "ap-southeast-1": "Asia Pacific (Singapore)",
        "ap-southeast-2": "Asia Pacific (Sydney)",
        "eu-west-1": "EU (Ireland)",
        "sa-east-1": "South America (Sao Paulo)",
        "us-east-1": "US East (N. Virginia)",
        "us-west-1": "US West (N. California)",
        "us-west-2": "US West (Oregon)",
    }
    return mapping.get(region_code, region_code or "")


def get_waf_status() -> Dict[str, Any]:
    """
    Read WAF state from Lambda environment variables so the frontend
    can display whether WAF is enabled and which countries are blocked.
    """
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


def _metric_query(
    query_id: str,
    namespace: str,
    metric_name: str,
    dimensions: List[Dict[str, str]],
    stat: str = "Average",
    period: int = 300,
) -> Dict[str, Any]:
    """Build a single MetricDataQuery."""
    return {
        "Id": query_id,
        "MetricStat": {
            "Metric": {
                "Namespace": namespace,
                "MetricName": metric_name,
                "Dimensions": dimensions,
            },
            "Period": period,
            "Stat": stat,
        },
    }


def _latest_value(result: Dict[str, Any]) -> Optional[float]:
    """
    Extract the most recent value from a MetricDataResults entry.
    Returns None if no datapoints are present.
    """
    timestamps = result.get("Timestamps", []) or []
    values = result.get("Values", []) or []
    if not timestamps or not values:
        return None

    # Timestamps and Values arrays are parallel; pick the latest timestamp
    paired = list(zip(timestamps, values))
    paired.sort(key=lambda p: p[0], reverse=True)
    return float(paired[0][1])


def _fetch_metric_data(queries: List[Dict[str, Any]], minutes: int = METRIC_WINDOW_MINUTES):
    """
    Fetch a bundle of metric queries from CloudWatch with a short time window.
    Returns a tuple of (result_map, error_message, raw_results)
    """
    if not queries:
        return {}, None, []

    end_time = datetime.now(timezone.utc)
    start_time = end_time - timedelta(minutes=minutes)

    try:
        resp = cloudwatch.get_metric_data(
            MetricDataQueries=queries,
            StartTime=start_time,
            EndTime=end_time,
            ScanBy="TimestampDescending",
            MaxDatapoints=500,
        )
    except Exception as exc:  # noqa: BLE001
        return {}, f"Error calling CloudWatch GetMetricData: {exc}", []

    results = resp.get("MetricDataResults", []) or []
    values = {r.get("Id"): _latest_value(r) for r in results}
    return values, None, results


def _build_cloudfront_metrics() -> Dict[str, Any]:
    """Return CloudFront cache/error/latency metrics for the distribution."""
    if not CF_DISTRIBUTION_ID:
        return {"error": "CF_DISTRIBUTION_ID environment variable is not set"}

    dims = [
        {"Name": "DistributionId", "Value": CF_DISTRIBUTION_ID},
        {"Name": "Region", "Value": "Global"},
    ]

    queries = [
        _metric_query("cf4xx", "AWS/CloudFront", "4xxErrorRate", dims, "Average"),
        _metric_query("cf5xx", "AWS/CloudFront", "5xxErrorRate", dims, "Average"),
    ]

    values, err, _ = _fetch_metric_data(queries)
    if err:
        return {"error": err}

    # CloudFront only exposes error rates; derive a success (2xx) rate from 4xx/5xx if present.
    cf4 = values.get("cf4xx")
    cf5 = values.get("cf5xx")
    success_rate = None
    if cf4 is not None and cf5 is not None:
        success_rate = max(0.0, 100.0 - (cf4 + cf5))

    return {
        "distributionId": CF_DISTRIBUTION_ID,
        "windowMinutes": METRIC_WINDOW_MINUTES,
        "error4xxRate": values.get("cf4xx"),
        "error5xxRate": values.get("cf5xx"),
        "success2xxRate": success_rate,
    }





def _build_waf_metrics(waf_status: Dict[str, Any]) -> Dict[str, Any]:
    """
    Return WAF allowed/blocked counts if WAF metrics are configured.
    
    Note: WAF metrics only have WebACL and Rule dimensions (no Region dimension).
    """
    if not WAF_WEB_ACL_METRIC_NAME:
        return {
            "windowMinutes": METRIC_WINDOW_MINUTES,
            "enabled": False,
            "message": "WAF metrics not configured (WAF_WEB_ACL_METRIC_NAME not set)",
        }

    # Query with only WebACL and Rule dimensions (no Region)
    dims = [
        {"Name": "Rule", "Value": "ALL"},
        {"Name": "WebACL", "Value": WAF_WEB_ACL_METRIC_NAME},
    ]
    
    queries = [
        _metric_query("wafallow", "AWS/WAFV2", "AllowedRequests", dims, "Sum", 300),
        _metric_query("wafblock", "AWS/WAFV2", "BlockedRequests", dims, "Sum", 300),
    ]
    
    # Use 60 minute window to capture sparse data
    values, err, raw_results = _fetch_metric_data(queries, minutes=60)
    
    if err:
        return {
            "error": err,
            "enabled": waf_status.get("enabled", False),
            "windowMinutes": METRIC_WINDOW_MINUTES,
        }

    return {
        "windowMinutes": METRIC_WINDOW_MINUTES,
        "enabled": waf_status.get("enabled", False),
        "allowedRequests": values.get("wafallow"),
        "blockedRequests": values.get("wafblock"),
        "message": waf_status.get("message", ""),
        "webAclMetric": WAF_WEB_ACL_METRIC_NAME,
        "region": WAF_REGION,
    }


def _build_lambda_metrics(function_name: Optional[str]) -> Dict[str, Any]:
    """Return recent metrics for the status API Lambda itself."""
    fn = function_name or os.environ.get("AWS_LAMBDA_FUNCTION_NAME", "")
    if not fn:
        return {"error": "Function name unavailable for Lambda metrics"}

    dims = [{"Name": "FunctionName", "Value": fn}]

    queries = [
        _metric_query("lambdainv", "AWS/Lambda", "Invocations", dims, "Sum"),
        _metric_query("lambdaerr", "AWS/Lambda", "Errors", dims, "Sum"),
        _metric_query("lambdams", "AWS/Lambda", "Duration", dims, "Average"),
        _metric_query("lambdatro", "AWS/Lambda", "Throttles", dims, "Sum"),
    ]

    values, err, _ = _fetch_metric_data(queries)
    if err:
        return {"error": err, "functionName": fn}

    return {
        "windowMinutes": METRIC_WINDOW_MINUTES,
        "functionName": fn,
        "invocations": values.get("lambdainv"),
        "errors": values.get("lambdaerr"),
        "avgDurationMs": values.get("lambdams"),
        "throttles": values.get("lambdatro"),
    }


def _build_metrics_response(context) -> Dict[str, Any]:
    """
    Bundle CloudFront, WAF, and Lambda metrics to give a quick
    performance/security/reliability snapshot.
    """
    waf_status = get_waf_status()

    return {
        "version": API_VERSION,
        "generatedAt": _iso_now(),
        "cloudfront": _build_cloudfront_metrics(),
        "waf": _build_waf_metrics(waf_status),
        "lambda": _build_lambda_metrics(STATUS_API_FUNCTION_NAME or getattr(context, "function_name", None)),
        "windowMinutes": METRIC_WINDOW_MINUTES,
    }


def _build_latency_response() -> Dict[str, Any]:
    """
    Build latency response using only real measurements from this Lambda's region.

    A single TLS + TTFB measurement is taken against chris-nelson.dev and returned
    alongside the AWS region the function is running in. No synthetic regional data.
    """
    tls_ms, ttfb_ms, status_code, reason, peer_ip = _measure_site()

    return {
        "version": API_VERSION,
        "generatedAt": _iso_now(),
        "lambdaRegion": os.environ.get("AWS_REGION", ""),
        "targetHost": HOSTNAME,
        "targetPort": PORT,
        "sslHandshakeMs": tls_ms,
        "timeToFirstByteMs": ttfb_ms,
        "statusCode": status_code,
        "statusReason": reason,
        "peerIp": peer_ip,
        "measurementOk": status_code != 503 and tls_ms > 0 and ttfb_ms > 0,
    }


def _build_health_response() -> Dict[str, Any]:
    """
    Build health response by calling Route 53 GetHealthCheckStatus.

    This lets the page show exactly the same per region messages you see
    in the AWS console, including DNS resolution failures and HTTP errors.
    """
    now = _iso_now()
    waf = get_waf_status()

    if not ROUTE53_HEALTH_CHECK_ID:
        return {
            "generatedAt": now,
            "regions": [],
            "error": "ROUTE53_HEALTH_CHECK_ID environment variable is not set on the Lambda function",
            "waf": waf,
        }

    try:
        resp = route53.get_health_check_status(HealthCheckId=ROUTE53_HEALTH_CHECK_ID)
        observations = resp.get("HealthCheckObservations", [])
    except Exception as exc:  # noqa: BLE001
        return {
            "version": API_VERSION,
            "generatedAt": now,
            "regions": [],
            "error": f"Error calling Route 53 get_health_check_status: {exc}",
            "waf": waf,
        }

    regions: List[Dict[str, Any]] = []

    for obs in observations:
        region_code = obs.get("Region")
        ip = obs.get("IPAddress", "")
        report = obs.get("StatusReport", {}) or {}
        status_text = report.get("Status", "") or ""
        checked_time = report.get("CheckedTime")

        # Map Route 53 status text to a simple HEALTHY or UNHEALTHY
        if status_text.startswith("Success"):
            overall = "HEALTHY"
        else:
            overall = "UNHEALTHY"

        # Try to extract an HTTP status code from the message, if present
        http_code = None
        m = re.search(r"HTTP Status Code\s+(\d+)", status_text)
        if m:
            try:
                http_code = int(m.group(1))
            except ValueError:
                http_code = None

        regions.append(
            {
                "regionCode": region_code,
                "regionName": _region_name_from_code(region_code or ""),
                "ip": ip,
                "status": overall,
                "httpStatusCode": http_code,
                "message": status_text,
                "checkedTime": checked_time.isoformat()
                if hasattr(checked_time, "isoformat")
                else None,
            }
        )

    return {
        "version": API_VERSION,
        "generatedAt": now,
        "regions": regions,
        "waf": waf,
    }


def _get_path(event: Dict[str, Any]) -> str:
    """
    Safely extract the request path across different API Gateway event shapes.
    """
    return (
        event.get("rawPath")
        or event.get("path")
        or event.get("requestContext", {}).get("http", {}).get("path", "")
        or ""
    )


def lambda_handler(event, context):
    """
    Single Lambda entrypoint that handles three logical endpoints:

    - GET /status/latency
    - GET /status/health-checkers
    - GET /status/metrics
    """
    path = _get_path(event)

    if path.endswith("/status/latency"):
        body = _build_latency_response()
        status_code = 200
    elif path.endswith("/status/health-checkers"):
        body = _build_health_response()
        status_code = 200
    elif path.endswith("/status/metrics"):
        body = _build_metrics_response(context)
        status_code = 200
    else:
        body = {
            "message": "Not found",
            "path": path,
        }
        status_code = 404

    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "https://chris-nelson.dev",
            "Access-Control-Allow-Headers": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
        },
        "body": json.dumps(body),
    }
