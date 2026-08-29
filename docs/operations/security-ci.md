# Application And Supply-Chain Security CI

## Purpose

This stage adds application and supply-chain security gates without changing promoted application, Docker, Nginx, Terraform, or deployment code.

The workflow answers five questions:

- Does Python contain suspicious security patterns?
- Do Python dependencies contain known vulnerabilities?
- Has a secret been committed?
- Do the Dockerfiles contain unsafe or poor practices?
- Do final container images contain known vulnerabilities?

It does not deploy anything, authenticate to AWS, access ECR, run Terraform, or modify production code.

## Ruff Vs Bandit

Ruff primarily checks Python quality, correctness, style, and maintainability rules.

Bandit performs Python SAST. It scans Python source for security-relevant patterns such as unsafe subprocess usage, weak cryptography, insecure temporary files, hardcoded passwords, and risky deserialization.

Ruff and Bandit are complementary. Ruff can keep code tidy; Bandit looks for security smells.

## pytest Vs Security Testing

`pytest` proves expected behavior. It can show that endpoints, services, and worker logic behave correctly.

Security scanners ask different questions. A test can pass while the code still contains an insecure pattern, vulnerable dependency, leaked secret, or vulnerable base image.

## pip-audit Dependency Scanning

`pip-audit` scans Python dependencies from the repository's actual dependency manifest, `requirements.txt`.

It reports vulnerable package names, resolved or installed versions, vulnerability IDs, and fixed versions when available. The workflow reports findings but does not upgrade dependencies automatically. The operator decides remediation because dependency upgrades can change runtime behavior.

## Gitleaks Secret Scanning

Gitleaks scans repository history for accidentally committed secrets such as AWS access keys, API keys, private keys, tokens, passwords, and database credentials.

The workflow checks out full Git history with `fetch-depth: 0` and runs Gitleaks with redacted output. Raw discovered credentials must never be printed or uploaded.

OIDC removes the need for long-lived AWS keys in GitHub, but it does not eliminate secret-scanning needs. Developers can still accidentally commit unrelated tokens, private keys, database passwords, or legacy credentials.

## Hadolint Dockerfile Analysis

Hadolint evaluates Dockerfile construction practices. It can detect risky or low-quality patterns such as missing version pinning, bad shell practices, unnecessary package cache retention, or incorrect instruction usage.

Hadolint does not replace image vulnerability scanning. It checks how images are built, not every package vulnerability inside the final image.

## Trivy Image Vulnerability Scanning

Trivy scans the final built API and worker images. The workflow also scans the upstream `nginx:1.30.4-alpine` runtime image because the repository uses that exact image in Docker Compose instead of building a custom Nginx image.

The workflow runs two Trivy passes:

- Visibility scan: records HIGH and CRITICAL findings, including unfixed vulnerabilities, without blocking.
- Blocking scan: fails on HIGH and CRITICAL vulnerabilities that have available fixes by using `--ignore-unfixed`.

This keeps unfixed risk visible without silently hiding it, while still blocking issues the team can reasonably remediate.

## Docker Compose Validation Vs Image Vulnerability Scanning

Docker Compose validation proves the service topology is syntactically valid. Integration CI proves containers work together at runtime.

Neither one is a vulnerability scan. Security CI complements them by scanning Dockerfiles, built images, dependencies, source security patterns, and repository secrets.

## Blocking Vs Informational Findings

Initial blocking gates:

- Bandit MEDIUM/HIGH severity with MEDIUM/HIGH confidence.
- Any `pip-audit` vulnerability.
- Any Gitleaks finding.
- Any Hadolint failure.
- Trivy HIGH/CRITICAL image vulnerabilities with available fixes.

Informational evidence:

- Trivy HIGH/CRITICAL vulnerabilities without known fixes remain visible in reports.

## Why Scanners Must Not Rewrite Production Code

Security CI should report evidence and block unsafe changes. It should not automatically rewrite promoted implementation because automatic fixes can alter behavior, hide risk, or make the reviewed source differ from the tested source.

If a scanner finds an issue in stable code, the finding should be reviewed, prioritized, and fixed deliberately in a separate remediation change.

## Security Evidence In GitHub Actions

GitHub Actions is the observability layer for this stage. The workflow provides:

- Job status.
- Step logs.
- `GITHUB_STEP_SUMMARY` entries.
- Non-sensitive report artifacts.

Gitleaks reports must stay redacted. Raw detected secrets must not be uploaded.

## Local WSL Verification

The local parity script does not install tools automatically. Install these first in WSL or another Linux environment:

- Bandit
- pip-audit
- Gitleaks
- Hadolint
- Trivy
- Docker

Run:

```bash
cd /mnt/c/Users/AGU/Documents/Codex/2026-08-20/re
bash scripts/security-quality.sh
```

Optional report directory:

```bash
REPORT_DIR=/tmp/security-reports bash scripts/security-quality.sh
```

## Deferred Controls

- SBOM generation
- Artifact signing
- Provenance and attestation
- Dependabot or Renovate strategy
- CodeQL
- GitHub Action SHA pinning
- Authenticated Terraform plan
- ECR scanning
- Drift detection

