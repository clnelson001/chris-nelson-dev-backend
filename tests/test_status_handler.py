import importlib.util
from pathlib import Path

# Smoke tests for helper functions in lambda/status_handler.py.


def _load_status_handler(monkeypatch):
  # Ensure boto3 has a region and required env vars before import.
  monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
  monkeypatch.setenv("ALARM_NAME", "dummy-alarm")

  module_path = Path(__file__).resolve().parents[1] / "lambda" / "status_handler.py"
  spec = importlib.util.spec_from_file_location("status_handler_under_test", module_path)
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  return module


def test_waf_disabled(monkeypatch):
  status_handler = _load_status_handler(monkeypatch)

  monkeypatch.setenv("WAF_ENABLED", "false")
  monkeypatch.setenv("WAF_BLOCK_COUNTRIES", "")

  result = status_handler.get_waf_status()
  assert result["enabled"] is False
  assert result["blocked_countries"] == []
  assert "WAF disabled" in result["message"]


def test_waf_enabled_with_blocks(monkeypatch):
  status_handler = _load_status_handler(monkeypatch)

  monkeypatch.setenv("WAF_ENABLED", "true")
  monkeypatch.setenv("WAF_BLOCK_COUNTRIES", "US,DE")

  result = status_handler.get_waf_status()
  assert result["enabled"] is True
  assert result["blocked_countries"] == ["US", "DE"]
  assert "geo blocking" in result["message"]
