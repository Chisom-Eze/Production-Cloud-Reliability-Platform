#!/usr/bin/env bash
set -euo pipefail

ROOTS=(
  "infrastructure/bootstrap"
  "infrastructure/shared/container-registry"
  "infrastructure/shared/security-audit"
  "infrastructure/environments/development"
)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TFLINT_CONFIG="${REPO_ROOT}/.tflint.hcl"

append_summary() {
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## Terraform Static Quality Gates"
      echo ""
      echo "- Canonical implementation: scripts/terraform-quality.sh"
      echo "- Backend mode: terraform init -backend=false"
      echo "- AWS authentication: not used"
      echo "- Terraform roots:"
      for root in "${ROOTS[@]}"; do
        echo "  - ${root}"
      done
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 2
  fi
}

echo "Terraform quality gates are static checks only."
echo "This script does not run terraform apply, terraform plan, or contact the configured S3 backend."
append_summary

require_command terraform
require_command tflint
require_command trivy

echo "==> terraform fmt -check -recursive infrastructure"
terraform fmt -check -recursive infrastructure

for root in "${ROOTS[@]}"; do
  echo "==> terraform init -backend=false for ${root}"
  if [[ -f "${root}/.terraform.lock.hcl" ]]; then
    terraform -chdir="$root" init -backend=false -lockfile=readonly
  else
    terraform -chdir="$root" init -backend=false
  fi

  echo "==> terraform validate for ${root}"
  terraform -chdir="$root" validate
done

echo "==> tflint --init"
tflint --init --config "$TFLINT_CONFIG"

for root in "${ROOTS[@]}"; do
  echo "==> tflint for ${root}"
  tflint --config "$TFLINT_CONFIG" --chdir="$root"
done

echo "==> trivy config LOW/MEDIUM visibility scan"
trivy config --severity LOW,MEDIUM --exit-code 0 infrastructure

echo "==> trivy config HIGH/CRITICAL blocking scan"
trivy config --severity HIGH,CRITICAL --exit-code 1 infrastructure

echo "Terraform quality gates passed."

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  echo "- Terraform static quality gates: passed" >> "$GITHUB_STEP_SUMMARY"
fi
