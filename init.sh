#!/usr/bin/env bash
#
# init.sh
#
# One-time (idempotent) setup of the workspace: clones the sub repos next to
# this script and creates the Fabric stage folders.
#
#   dazu-pbi-test  -> clone of stallen-arch/dazu-pbi, branch test (owns .git)
#   dazu-pbi-int   -> git worktree of dazu-pbi-test, branch int
#   dazu-pbi-prod  -> git worktree of dazu-pbi-test, branch prod
#   sap-bo         -> clone of stallen-arch/sap-bo, branch main
#
# It also installs the Python packages (requirements.txt) needed by the scripts
# in sap-bo (generate_*.py, validate_pbir.py).
#
# The sub repos are git-ignored by this parent repo. Re-running the script is
# safe: existing folders are left untouched (use ./pull-all.sh to update them).
#
# Prerequisites: git, Python >= 3.9, SSH access to GitHub (stallen-arch).
#
# Usage:
#   ./init.sh                                   # SSH remotes (default)
#   DAZU_PBI_URL=https://github.com/stallen-arch/dazu-pbi.git \
#   SAP_BO_URL=https://github.com/stallen-arch/sap-bo.git ./init.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAZU_PBI_URL="${DAZU_PBI_URL:-git@github.com:stallen-arch/dazu-pbi.git}"
SAP_BO_URL="${SAP_BO_URL:-git@github.com:stallen-arch/sap-bo.git}"

if ! command -v git > /dev/null; then
  echo "!! git not found in PATH." >&2
  exit 1
fi

failed=0
declare -a RESULTS=()

ok()   { RESULTS+=("$1: $2"); }
fail() { RESULTS+=("$1: FAILED ($2)"); failed=1; }

# --- dazu-pbi-test: main clone ------------------------------------------------
test_dir="${REPO_ROOT}/dazu-pbi-test"
if [[ -e "${test_dir}/.git" ]]; then
  ok dazu-pbi-test "already present"
else
  echo "== Cloning dazu-pbi (branch test) -> dazu-pbi-test"
  if git clone --branch test "${DAZU_PBI_URL}" "${test_dir}"; then
    ok dazu-pbi-test "cloned"
  else
    fail dazu-pbi-test "clone error"
  fi
fi

# --- dazu-pbi-int / dazu-pbi-prod: worktrees of dazu-pbi-test -----------------
for branch in int prod; do
  folder="dazu-pbi-${branch}"
  dir="${REPO_ROOT}/${folder}"

  if [[ -e "${dir}/.git" ]]; then
    ok "${folder}" "already present"
    continue
  fi
  if [[ ! -e "${test_dir}/.git" ]]; then
    fail "${folder}" "dazu-pbi-test missing"
    continue
  fi

  echo "== Creating worktree ${folder} (branch ${branch})"
  git -C "${test_dir}" fetch origin "${branch}" || { fail "${folder}" "fetch error"; continue; }
  # --track creates the local branch from origin/<branch> if it doesn't exist yet
  if git -C "${test_dir}" worktree add --track -B "${branch}" "${dir}" "origin/${branch}"; then
    ok "${folder}" "worktree created"
  else
    fail "${folder}" "worktree error"
  fi
done

# --- sap-bo: independent clone ------------------------------------------------
sap_dir="${REPO_ROOT}/sap-bo"
if [[ -e "${sap_dir}/.git" ]]; then
  ok sap-bo "already present"
else
  echo "== Cloning sap-bo (branch main)"
  if git clone --branch main "${SAP_BO_URL}" "${sap_dir}"; then
    ok sap-bo "cloned"
  else
    fail sap-bo "clone error"
  fi
fi

# --- Python dependencies for the generator/validator scripts in sap-bo --------
# Prefer an interpreter that already has pip; remember a pip-less one as fallback
# (e.g. Git Bash/MSYS python3, embeddable or minimal installs have no pip module).
PY=""
PY_NOPIP=""
for cand in python3 python py; do
  if command -v "${cand}" > /dev/null && "${cand}" -c "import sys; sys.exit(sys.version_info < (3, 9))" 2> /dev/null; then
    if "${cand}" -m pip --version > /dev/null 2>&1; then
      PY="${cand}"
      break
    fi
    [[ -z "${PY_NOPIP}" ]] && PY_NOPIP="${cand}"
  fi
done

if [[ -z "${PY}" && -n "${PY_NOPIP}" ]]; then
  echo "== '${PY_NOPIP}' has no pip module, trying ensurepip"
  if "${PY_NOPIP}" -m ensurepip --user > /dev/null 2>&1 && "${PY_NOPIP}" -m pip --version > /dev/null 2>&1; then
    PY="${PY_NOPIP}"
  else
    fail python "'${PY_NOPIP}' has no pip. Install Python >= 3.9 from python.org (with pip) or run '${PY_NOPIP} -m ensurepip --user'"
  fi
fi

if [[ -z "${PY}" ]]; then
  [[ -z "${PY_NOPIP}" ]] && fail python "Python >= 3.9 not found in PATH"
else
  echo "== Installing Python requirements (${PY})"
  if "${PY}" -m pip install --user -q -r "${REPO_ROOT}/requirements.txt"; then
    ok python "requirements installed"
  else
    fail python "pip install error"
  fi
fi

echo "============================================================"
echo "Summary"
echo "============================================================"
for r in "${RESULTS[@]}"; do
  echo "  - ${r}"
done

exit "${failed}"
