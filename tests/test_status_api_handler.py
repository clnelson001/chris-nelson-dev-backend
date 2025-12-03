import importlib.util
from pathlib import Path

# Smoke tests for helper functions in lambda/status_api_handler.py.


def _load_status_api(monkeypatch):
  # Ensure boto3 has a region before import.
  monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")

  module_path = Path(__file__).resolve().parents[1] / "lambda" / "status_api_handler.py"
  spec = importlib.util.spec_from_file_location("status_api_under_test", module_path)
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  return module


def test_region_name_mapping(monkeypatch):
  status_api = _load_status_api(monkeypatch)

  assert status_api._region_name_from_code("ap-northeast-1") == "Asia Pacific (Tokyo)"
  assert status_api._region_name_from_code("unknown-region") == "unknown-region"


def test_waf_status_messages(monkeypatch):
  status_api = _load_status_api(monkeypatch)

  monkeypatch.setenv("WAF_ENABLED", "true")
  monkeypatch.setenv("WAF_BLOCK_COUNTRIES", "US,DE")
  enabled = status_api.get_waf_status()
  assert enabled["enabled"] is True
  assert enabled["blocked_countries"] == ["US", "DE"]

  monkeypatch.setenv("WAF_ENABLED", "false")
  monkeypatch.setenv("WAF_BLOCK_COUNTRIES", "")
  disabled = status_api.get_waf_status()
  assert disabled["enabled"] is False
  assert disabled["blocked_countries"] == []
