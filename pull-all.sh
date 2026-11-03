#!/usr/bin/env bash
#
# pull-all.sh
#
# Syncs all three Fabric-connected stages (int / test / prod) of the dazu-pbi
# repo by running `git pull` in each stage's working copy folder.
#
# Each folder below is a working copy checked out to its own branch, which is
# connected to a Fabric workspace via Git integration:
#   dazu-pbi-int   -> branch int
#   dazu-pbi-test  -> branch test   (this is the main clone / git-dir owner)
#   dazu-pbi-prod  -> branch prod
#   sap-bo         -> branch main   (standalone repo, not Fabric-connected)
#
# Note: dazu-pbi-int and dazu-pbi-prod are `git worktree` checkouts that share
# the object store/.git of dazu-pbi-test. That's fine - each still has its own
# independent working tree, index, and branch, so pulling each one here works
# the same as if they were separate clones. sap-bo is a fully independent
# clone with its own .git directory.
#
# Usage:
#   ./pull-all.sh                 # pull all 4 repos/stages
#   ./pull-all.sh int test        # pull only the given stages
#   ./pull-all.sh main            # pull only sap-bo
#
# Safety:
#   - Skips (does not pull) any stage that has uncommitted local changes,
#     so you don't lose in-progress edits made via Fabric Desktop/Git sync.
#   - Verifies the checked-out branch matches the expected branch for that
#     folder before pulling, and warns (without pulling) if it doesn't.
#   - Uses `git pull --ff-only` to avoid creating merge commits; if a fast
#     -forward isn't possible it reports it instead of silently merging.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# stage-folder:expected-branch pairs
STAGES=(
  "dazu-pbi-int:int"
  "dazu-pbi-test:test"
  "dazu-pbi-prod:prod"
  "sap-bo:main"
)

# Allow filtering which stages to sync via args, e.g. ./pull-all.sh int test
FILTER=("$@")

declare -a RESULTS=()

stage_requested() {
  local branch="$1"
  [[ ${#FILTER[@]} -eq 0 ]] && return 0
  for f in "${FILTER[@]}"; do
    [[ "$f" == "$branch" ]] && return 0
  done
  return 1
}

for entry in "${STAGES[@]}"; do
  folder="${entry%%:*}"
  branch="${entry##*:}"

  if ! stage_requested "$branch"; then
    continue
  fi

  echo "============================================================"
  echo "== ${branch} (${folder})"
  echo "============================================================"

  dir="${REPO_ROOT}/${folder}"
  # .git can be a directory (regular clone, e.g. dazu-pbi-test) or a file
  # containing a "gitdir:" pointer (git worktree, e.g. dazu-pbi-int/-prod).
  if [[ ! -e "${dir}/.git" ]]; then
    echo "  !! Skipping: '${folder}' is not a git working copy."
    RESULTS+=("${branch}: SKIPPED (no .git)")
    continue
  fi

  pushd "${dir}" > /dev/null

  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ "${current_branch}" != "${branch}" ]]; then
    echo "  !! Skipping: checked out on '${current_branch}', expected '${branch}'."
    RESULTS+=("${branch}: SKIPPED (on branch ${current_branch})")
    popd > /dev/null
    continue
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "  !! Skipping: uncommitted local changes present. Commit, stash, or"
    echo "     discard them first, then re-run."
    RESULTS+=("${branch}: SKIPPED (dirty working tree)")
    popd > /dev/null
    continue
  fi

  echo "  Fetching..."
  if ! git fetch origin "${branch}"; then
    echo "  !! Fetch failed."
    RESULTS+=("${branch}: FAILED (fetch error)")
    popd > /dev/null
    continue
  fi

  echo "  Pulling (fast-forward only)..."
  if git pull --ff-only origin "${branch}"; then
    RESULTS+=("${branch}: OK")
  else
    echo "  !! Fast-forward not possible (local branch has diverged)."
    echo "     Resolve manually: cd ${folder} && git status"
    RESULTS+=("${branch}: FAILED (diverged / needs manual merge)")
  fi

  popd > /dev/null
  echo
done

echo "============================================================"
echo "Summary"
echo "============================================================"
for r in "${RESULTS[@]}"; do
  echo "  - ${r}"
done

# Exit non-zero if anything failed, so this can be used in CI.
for r in "${RESULTS[@]}"; do
  if [[ "${r}" == *"FAILED"* ]]; then
    exit 1
  fi
done
exit 0



