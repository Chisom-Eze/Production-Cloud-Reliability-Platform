#!/usr/bin/env bash
set -euo pipefail

# Repository Integrity Guard
#
# Detects likely unresolved Git merge-conflict blocks in tracked files.
# A file fails only when it contains both an opening and closing conflict
# marker, which substantially reduces false positives from documentation
# that merely mentions one of the marker forms.

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "ERROR: repository-integrity.sh must run inside a Git repository." >&2
  exit 2
}

cd "$repo_root"

left_marker="$(printf '%*s' 7 '' | tr ' ' '<')"
right_marker="$(printf '%*s' 7 '' | tr ' ' '>')"

failed=0

while IFS= read -r -d '' file; do
  # Skip non-regular files.
  [ -f "$file" ] || continue

  if grep -Iq . "$file"; then
    if grep -Eq "^${left_marker}( |$)" "$file" &&
       grep -Eq "^${right_marker}( |$)" "$file"; then

      echo "ERROR: possible unresolved merge-conflict block detected:"
      echo "  $file"
      echo

      grep -nE \
        "^(${left_marker}|${right_marker})( |$)" \
        "$file" || true

      echo
      failed=1
    fi
  fi
done < <(git ls-files -z)

if [ "$failed" -ne 0 ]; then
  echo "Repository integrity check failed."
  echo "Inspect the files above before committing or merging."
  exit 1
fi

echo "Repository integrity check passed: no unresolved merge-conflict blocks detected."