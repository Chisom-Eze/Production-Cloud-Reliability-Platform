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

# Report every drift entry before checking any individual entry. Never print
# policy documents or raw state values to a public workflow log.
managed_changes = {
    r["address"]: r for r in plan.get("resource_changes", [])
    if r.get("mode") == "managed" and not r.get("deposed")
}
permanent_roles = {
    "aws_iam_role.github_development_terraform_plan": "pcrp-GitHubDevelopmentTerraformPlan",
    "aws_iam_role.github_development_terraform_apply": "pcrp-GitHubDevelopmentTerraformApply",
    "aws_iam_role.github_development_ecr_publisher": "pcrp-GitHubDevelopmentEcrPublisher",
    "aws_iam_role.github_development_ecs_release": "pcrp-GitHubDevelopmentEcsRelease",
}


def changed_fields(before, after):
    return {k for k in before.keys() | after.keys() if before.get(k) != after.get(k)}


def canonical(value):
    # IAM policy arrays describe sets; normalize their order for comparison.
    if isinstance(value, dict):
        return {k: canonical(v) for k, v in value.items()}
    if isinstance(value, list):
        return sorted((canonical(v) for v in value), key=lambda v: json.dumps(v, sort_keys=True))
    return value


def inline_map(items):
    result = {}
    for item in items or []:
        name = item.get("name")
        if not name or name in result:
            fail("missing or duplicate inline-policy name")
        result[name] = canonical(policy_document(item.get("policy")))
    return result


def verify_permanent_role_drift(address, change):
    before, after = change.get("before"), change.get("after")
    if change.get("actions") != ["update"] or not isinstance(before, dict) or not isinstance(after, dict):
        fail(f"unexpected role drift action: {address}")
    name = permanent_roles[address]
    arn = f"arn:aws:iam::{account_id}:role/{name}"
    if any(v.get("name") != name or v.get("arn") != arn for v in (before, after)):
        fail(f"unexpected role identity: {address}")
    role_change = managed_changes.get(address, {}).get("change", {})
    if role_change.get("actions") != ["no-op"]:
        fail(f"role is not an unchanged managed resource: {address}")
    fields = changed_fields(before, after)
    if not fields or fields - {"inline_policy", "managed_policy_arns"}:
        fail(f"unapproved role drift fields: {address}: {', '.join(sorted(fields))}")
    expected_inline = {}
    expected_attached = set()
    for resource in managed_changes.values():
        kind = resource.get("type")
        if kind not in {"aws_iam_role_policy", "aws_iam_role_policy_attachment"}:
            continue
        association = resource.get("change", {})
        values = association.get("after") or {}
        if values.get("role") != name:
            continue
        if association.get("actions") != ["no-op"]:
            fail(f"association is not unchanged: {resource['address']}")
        if kind == "aws_iam_role_policy":
            policy_name = values.get("name")
            if not policy_name or policy_name in expected_inline:
                fail(f"missing or duplicate managed inline policy: {address}")
            expected_inline[policy_name] = canonical(policy_document(values.get("policy")))
        else:
            policy_arn = values.get("policy_arn")
            if not isinstance(policy_arn, str) or not policy_arn:
                fail(f"unknown managed policy ARN: {address}")
            expected_attached.add(policy_arn)
    if "inline_policy" in fields and inline_map(after.get("inline_policy")) != expected_inline:
        fail(f"live inline policies differ from unchanged Terraform-managed policies: {address}")
    if "managed_policy_arns" in fields and set(after.get("managed_policy_arns") or []) != expected_attached:
        fail(f"live managed attachments differ from unchanged Terraform-managed attachments: {address}")
    print(f"NOTICE: verified separately managed policy association drift: {address}")


for resource in plan.get("resource_drift", []):
    if resource.get("mode") != "managed":
        continue
    change = resource.get("change", {})
    before, after = change.get("before"), change.get("after")
    fields = sorted(changed_fields(before, after)) if isinstance(before, dict) and isinstance(after, dict) else ["<missing before/after>"]
    print(f"DRIFT: {resource.get('address')} actions={change.get('actions')} fields={', '.join(fields)}", flush=True)

# An out-of-band, temporary inline policy may be reflected as bridge-role drift.
# Other drift is accepted only for verified, separately managed role associations.
for resource in plan.get("resource_drift", []):
    if resource.get("mode") != "managed":
        continue
    change = resource.get("change", {})
    if change.get("actions") == ["no-op"]:
        continue
    address = resource.get("address", "<unknown>")
    if address in permanent_roles:
        verify_permanent_role_drift(address, change)
        continue
    if address != BRIDGE or change.get("actions") != ["update"]:
        fail(f"unexpected managed resource drift: {address}")
    before, after = change.get("before"), change.get("after")
    if not isinstance(before, dict) or not isinstance(after, dict):
        fail("bridge role drift lacks before/after values")
    if {k: v for k, v in before.items() if k != "inline_policy"} != {k: v for k, v in after.items() if k != "inline_policy"}:
        fail("bridge role drift changes something other than inline_policy")
    old_inline = before.get("inline_policy") or []
    new_inline = after.get("inline_policy") or []
    allowed_previous = {TEMP_POLICY, "PCRPTemporaryBootstrapIamTransition", "pcrp-temporary-bootstrap-dns-transition"}
    if (
        len(old_inline) > 1
        or any(p.get("name") not in allowed_previous for p in old_inline)
        or len(new_inline) != 1
        or new_inline[0].get("name") != TEMP_POLICY
    ):
        fail("bridge role drift is not an approved temporary inline-policy transition")
    print("NOTICE: approved temporary inline-policy transition in bridge drift")

print("PASS: exactly four existing IAM policy document updates; no other managed resource changes.")
