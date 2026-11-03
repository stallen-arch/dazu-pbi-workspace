#!/usr/bin/env bash
#
# push-all.sh
#
# Counterpart to pull-all.sh: commits local changes (if any) and pushes all
# Fabric-connected stages (int / test / prod) plus sap-bo to origin.
#
# Folder / branch layout (same as pull-all.sh):
#   dazu-pbi-int   -> branch int
#   dazu-pbi-test  -> branch test   (main clone / git-dir owner)
#   dazu-pbi-prod  -> branch prod
#   sap-bo         -> branch main   (standalone repo, not Fabric-connected)
#
# Usage:
#   ./push-all.sh                          # commit + push all 4 repos/stages
#   ./push-all.sh -m "Add TGRE model"      # custom commit message
#   ./push-all.sh -m "msg" int test        # only the given stages
#   ./push-all.sh -n                       # dry run: show what would happen
#   ./push-all.sh main                     # only sap-bo
#
# Safety:
#   - Verifies the checked-out branch matches the expected branch, otherwise
#     skips the stage.
#   - Skips a stage if origin has commits that are not yet local (e.g. made via
#     Fabric "Commit"). Run ./pull-all.sh first, then re-run. Never force-pushes.
#   - Uncommitted changes are staged with `git add -A` and committed using the
#     given message (default: "Update <stage> <timestamp>").
#   - Nothing is pushed for stages without local commits.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STAGES=(
  "dazu-pbi-int:int"
  "dazu-pbi-test:test"
  "dazu-pbi-prod:prod"
  "sap-bo:main"
)

MESSAGE=""
DRY_RUN=0
FILTER=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message)
      if [[ $# -lt 2 ]]; then
        echo "Option $1 requires an argument." >&2
        exit 2
      fi
      MESSAGE="$2"
      shift 2
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      sed -n '2,29p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      FILTER+=("$1")
      shift
      ;;
  esac
done

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
  # .git is a directory (clone) or a "gitdir:" file (worktree).
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

  echo "  Fetching..."
  if ! git fetch origin "${branch}"; then
    echo "  !! Fetch failed."
    RESULTS+=("${branch}: FAILED (fetch error)")
    popd > /dev/null
    continue
  fi

  # Commits on origin that we don't have yet -> pull first.
  behind="$(git rev-list --count "HEAD..origin/${branch}" 2>/dev/null || echo 0)"
  if [[ "${behind}" -gt 0 ]]; then
    echo "  !! Skipping: origin/${branch} is ${behind} commit(s) ahead."
    echo "     Run ./pull-all.sh ${branch} first, then re-run."
    RESULTS+=("${branch}: SKIPPED (behind origin by ${behind})")
    popd > /dev/null
    continue
  fi

  committed="no"
  if [[ -n "$(git status --porcelain)" ]]; then
    msg="${MESSAGE:-Update ${branch} $(date '+%Y-%m-%d %H:%M')}"
    echo "  Uncommitted changes:"
    git status --short | sed 's/^/    /'
    if [[ ${DRY_RUN} -eq 1 ]]; then
      echo "  [dry-run] would commit with message: ${msg}"
      committed="would"
    else
      git add -A
      if git commit -m "${msg}"; then
        committed="yes"
      else
        echo "  !! Commit failed."
        RESULTS+=("${branch}: FAILED (commit error)")
        popd > /dev/null
        continue
      fi
    fi
  fi

  ahead="$(git rev-list --count "origin/${branch}..HEAD" 2>/dev/null || echo 0)"
  if [[ "${ahead}" -eq 0 && "${committed}" != "would" ]]; then
    echo "  Nothing to push."
    RESULTS+=("${branch}: UP TO DATE")
    popd > /dev/null
    echo
    continue
  fi

  if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "  [dry-run] would push ${ahead} existing commit(s)$([[ "${committed}" == "would" ]] && echo " + 1 new commit") to origin/${branch}."
    RESULTS+=("${branch}: DRY-RUN")
  else
    echo "  Pushing ${ahead} commit(s)..."
    if git push origin "${branch}"; then
      RESULTS+=("${branch}: PUSHED (${ahead} commit(s))")
    else
      echo "  !! Push failed. Resolve manually: cd ${folder} && git status"
      RESULTS+=("${branch}: FAILED (push error)")
    fi
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

