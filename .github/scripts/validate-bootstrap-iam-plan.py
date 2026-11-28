#!/usr/bin/env python3
"""Fail closed unless a saved bootstrap plan changes exactly four policy documents."""
import json
import sys

EXPECTED = {
    "pcrp-GitHubDevelopmentTerraformApplyNetwork",
    "pcrp-GitHubDevelopmentTerraformApplyEdge",
    "pcrp-GitHubDevelopmentTerraformApplyData",
    "pcrp-GitHubDevelopmentTerraformApplyObservabilityAudit",
}
BRIDGE = "aws_iam_role.github_development_deployment"
TEMP_POLICY = "PCRPTemporaryBootstrapIamRemediation"


def fail(message):
    raise SystemExit(f"Bootstrap plan rejected: {message}")


def policy_document(raw):
    if not isinstance(raw, str):
        fail("policy document is absent or unknown")
    try:
        value = json.loads(raw)
    except (TypeError, ValueError):
        fail("policy document is not valid JSON")
    if not isinstance(value, dict) or "Statement" not in value:
        fail("policy document does not contain Statement")
    return value


def statement_map(document):
    statements = document["Statement"]
    if not isinstance(statements, list):
        statements = [statements]
    result = {}
    for statement in statements:
        if not isinstance(statement, dict) or not statement.get("Sid"):
            return None
        sid = statement["Sid"]
        if sid in result:
            return None
        result[sid] = statement
    return result


try:
    plan = json.load(sys.stdin)
except (TypeError, ValueError):
    fail("cannot parse Terraform plan JSON")

if str(plan.get("format_version", "")).split(".")[0] != "1":
    fail("unsupported plan JSON format")
if plan.get("errored", False) or plan.get("applyable", True) is False:
    fail("plan is errored or not applyable")
if plan.get("complete", True) is False or plan.get("deferred_changes"):
    fail("plan is incomplete or contains deferred changes")
if len(sys.argv) != 2 or not sys.argv[1].isdigit() or len(sys.argv[1]) != 12:
    fail("expected a 12-digit AWS account ID")
account_id = sys.argv[1]

seen = set()
for resource in plan.get("resource_changes", []):
    if resource.get("mode") != "managed":
        continue
    change = resource.get("change", {})
    address = resource.get("address", "<unknown>")
    if resource.get("previous_address") or change.get("importing"):
        fail(f"unexpected move or import: {address}")
    actions = change.get("actions")
    if actions == ["no-op"]:
        continue
    if actions != ["update"] or resource.get("type") != "aws_iam_policy":
        fail(f"unexpected managed resource action: {address} {actions}")
    before, after = change.get("before"), change.get("after")
    if not isinstance(before, dict) or not isinstance(after, dict):
        fail(f"missing before/after values: {address}")
    name = before.get("name")
    if name not in EXPECTED or name in seen or after.get("name") != name:
        fail(f"unexpected or duplicate policy: {address}")
    expected_arn = f"arn:aws:iam::{account_id}:policy/{name}"
    if before.get("arn") != expected_arn or after.get("arn") != expected_arn:
        fail(f"unexpected policy ARN: {address}")
    if change.get("replace_paths"):
        fail(f"unexpected replacement path: {address}")
    unknown = change.get("after_unknown", {})
    for field in ("arn", "name", "name_prefix", "path", "description", "tags", "tags_all", "policy"):
        if unknown.get(field):
            fail(f"unknown value for {address}.{field}")
    # Permit only the policy document to change among configurable attributes.
    # Ignore provider-computed metadata such as attachment_count and policy_id.
    for field in ("name", "name_prefix", "path", "description", "tags", "tags_all"):
        if before.get(field) != after.get(field):
            fail(f"non-policy attribute changed: {address}.{field}")
    old, new = policy_document(before.get("policy")), policy_document(after.get("policy"))
    if old == new:
        fail(f"no actual policy document change: {address}")
    seen.add(name)
    print(f"ALLOW update: {address} ({name})")
    old_sids, new_sids = statement_map(old), statement_map(new)
    if old_sids is not None and new_sids is not None:
        changed = sorted(s for s in set(old_sids) | set(new_sids) if old_sids.get(s) != new_sids.get(s))
        print("  Changed statement SIDs: " + (", ".join(changed) or "none; review document-level changes"))
    else:
        print("  Statement-level SID summary unavailable; review full plan.")

if seen != EXPECTED:
    fail("expected exactly four policy updates; missing: " + ", ".join(sorted(EXPECTED - seen)))

# An out-of-band, temporary inline policy may be reflected as bridge-role drift.
# Do not accept drift on other resources or unrelated changes to the bridge.
for resource in plan.get("resource_drift", []):
    if resource.get("mode") != "managed":
        continue
    change = resource.get("change", {})
    if change.get("actions") == ["no-op"]:
        continue
    address = resource.get("address", "<unknown>")
    if address != BRIDGE or change.get("actions") != ["update"]:
        fail(f"unexpected managed resource drift: {address}")
    before, after = change.get("before"), change.get("after")
    if not isinstance(before, dict) or not isinstance(after, dict):
        fail("bridge role drift lacks before/after values")
    if {k: v for k, v in before.items() if k != "inline_policy"} != {k: v for k, v in after.items() if k != "inline_policy"}:
        fail("bridge role drift changes something other than inline_policy")
    old_inline = before.get("inline_policy") or []
    new_inline = after.get("inline_policy") or []
    allowed_previous = {TEMP_POLICY, "PCRPTemporaryBootstrapIamTransition"}
    if (
        len(old_inline) > 1
        or any(p.get("name") not in allowed_previous for p in old_inline)
        or len(new_inline) != 1
        or new_inline[0].get("name") != TEMP_POLICY
    ):
        fail("bridge role drift is not an approved temporary inline-policy transition")
    print("NOTICE: approved temporary inline-policy transition in bridge drift")

print("PASS: exactly four existing IAM policy document updates; no other managed resource changes.")
