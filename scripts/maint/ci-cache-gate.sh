#!/usr/bin/env bash
set -euo pipefail

host="${HOST:-116}"
default_china_substituters="https://mirrors.ustc.edu.cn/nix-channels/store https://cache.numtide.com https://anyrun.cachix.org https://hyprland.cachix.org https://yazelix.cachix.org"
default_china_extra_trusted_public_keys="niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g= anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s= hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc= yazelix.cachix.org-1:ZgxIjQvaP0VTWL8Racx27mpUNzDJ97xC2y7QWYjmGNM="
china_substituters="${CHINA_SUBSTITUTERS:-${default_china_substituters}}"
china_extra_trusted_public_keys="${CHINA_EXTRA_TRUSTED_PUBLIC_KEYS:-${default_china_extra_trusted_public_keys}}"
tmp="$(mktemp -d)"
if [[ -n "${RUNNER_TEMP:-}" ]]; then
  diagnostics="${RUNNER_TEMP}/cache-gate-116-diagnostics"
  mkdir -p "$diagnostics"
else
  diagnostics="$(mktemp -d)"
  echo "Cache gate diagnostics: $diagnostics"
fi

event="${GITHUB_EVENT_NAME:-local}"
head_sha="$(git rev-parse HEAD)"
nix_version="$(nix --version 2>&1)"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
started_ns="$(date +%s%N)"
base_sha="pending"
base_mode="delta"
base_collected=false
head_collected=false
diff_completed=false

printf 'event\t%s\nhost\t%s\nbase_sha\t%s\nhead_sha\t%s\nnix_version\t%s\ncomparison\t%s\nsubstituters\t%s\nfinal_exit_status\tpending\n' \
  "$event" "$host" "$base_sha" "$head_sha" "$nix_version" "$base_mode" "$china_substituters" > "$diagnostics/metadata.txt"
printf 'stage\tstarted_utc\tended_utc\telapsed_seconds\texit_status\n' > "$diagnostics/timings.tsv"

stage_start() {
  stage_name="$1"
  stage_started_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  stage_started_ns="$(date +%s%N)"
  echo "Cache gate: starting $stage_name"
}

stage_finish() {
  local stage_rc="$1" ended_utc ended_ns elapsed
  ended_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ended_ns="$(date +%s%N)"
  elapsed="$(awk -v start="$stage_started_ns" -v end="$ended_ns" 'BEGIN { printf "%.3f", (end-start)/1000000000 }')"
  printf '%s\t%s\t%s\t%s\t%s\n' "$stage_name" "$stage_started_utc" "$ended_utc" "$elapsed" "$stage_rc" >> "$diagnostics/timings.tsv"
  echo "Cache gate: finished $stage_name (exit $stage_rc, ${elapsed}s)"
}

contains_marker() {
  local text="$1"
  shift
  local marker
  for marker in "$@"; do
    if [[ "$text" == *"$marker"* ]]; then
      return 0
    fi
  done
  return 1
}

collect_blocked_derivations() {
  local label="$1" repo="$2" output_file="$3" direct_file="$4"
  local policy_file="$diagnostics/$label.policy.json" dry_run_output="$diagnostics/$label.dry-run.log"
  local policy_err="$diagnostics/$label.policy.err" stage_rc
  shift 4

  stage_start "$label policy eval"
  if nix eval --json "$@" "${repo}#lib.maintenancePolicy" > "$policy_file" 2> "$policy_err"; then
    stage_rc=0
  else
    stage_rc=$?
  fi
  stage_finish "$stage_rc"
  if [[ "$stage_rc" -ne 0 ]]; then
    return "$stage_rc"
  fi

  stage_start "$label dry-run"
  if (
    cd "$repo"
    nix build \
      --dry-run \
      -L \
      --option substituters "$china_substituters" \
      --option extra-substituters "" \
      --option extra-trusted-public-keys "$china_extra_trusted_public_keys" \
      "$@" \
      ".#nixosConfigurations.${host}.config.system.build.toplevel"
  ) >"$dry_run_output" 2>&1; then
    stage_rc=0
  else
    stage_rc=$?
  fi
  stage_finish "$stage_rc"
  if [[ "$stage_rc" -ne 0 ]]; then
    return 1
  fi

  : > "$output_file"
  : > "$direct_file"
  mapfile -t derivations < <(
    awk '/^[[:space:]]*\/nix\/store\/.*\.drv$/ { sub(/^[[:space:]]+/, ""); print }' "$dry_run_output" | sort -u
  )
  mapfile -t allowed_markers < <(
    jq -r '.allowedLocalBuildMarkers[]' "$policy_file"
  )
  mapfile -t direct_markers < <(jq -r '.allowedDirectFetchMarkers[]' "$policy_file")

  local drv
  for drv in "${derivations[@]}"; do
    if contains_marker "$drv" "${allowed_markers[@]}"; then
      continue
    elif contains_marker "$drv" "${direct_markers[@]}"; then
      printf '%s\n' "$drv" >> "$direct_file"
    else
      printf '%s\n' "$drv" >> "$output_file"
    fi
  done

  sort -u "$output_file" -o "$output_file"
  sort -u "$direct_file" -o "$direct_file"
}

write_summary() {
  local final_status="$1" new_blocked_count="not completed" new_direct_count="not completed"
  local label blocked direct count shown
  {
    echo "### 116 cache gate diagnostics"
    echo
    printf '%s\n' "- Event: \`$event\`" "- Host: \`$host\`" "- Base SHA: \`$base_sha\`" "- Head SHA: \`$head_sha\`" "- Nix: \`$nix_version\`" "- Comparison: \`$base_mode\`" "- Substituters: \`$china_substituters\`" "- Gate exit status: \`$final_status\`" "- Total elapsed seconds: \`$(awk -v start="$started_ns" -v end="$(date +%s%N)" 'BEGIN { printf "%.3f", (end-start)/1000000000 }')\`"
    echo
    echo '| Stage | Started (UTC) | Ended (UTC) | Seconds | Exit |'
    echo '|---|---|---|---:|---:|'
    if [[ -f "$diagnostics/timings.tsv" ]]; then
      tail -n +2 "$diagnostics/timings.tsv" | while IFS=$'\t' read -r stage start end seconds status; do
        printf '| %s | %s | %s | %s | %s |\n' "$stage" "$start" "$end" "$seconds" "$status"
      done
    fi
    echo
    for label in base head; do
      collected_var="${label}_collected"
      if [[ "${!collected_var}" == true ]]; then
        blocked="$diagnostics/$label.blocked.txt"
        direct="$diagnostics/$label.direct.txt"
        printf '%s\n' "- ${label^} blocked derivations: \`$(wc -l < "$blocked")\`" "- ${label^} direct derivations: \`$(wc -l < "$direct")\`"
      else
        printf '%s\n' "- ${label^} derivation lists: not completed"
      fi
    done
    if [[ "$diff_completed" == true ]]; then
      new_blocked_count="$(wc -l < "$diagnostics/new.blocked.txt")"
      new_direct_count="$(wc -l < "$diagnostics/new.direct.txt")"
    fi
    printf '%s\n' "- New blocked derivations: \`$new_blocked_count\`" "- New direct derivations: \`$new_direct_count\`"
    for pair in 'new blocked:new.blocked.txt' 'new direct:new.direct.txt'; do
      label="${pair%%:*}"
      blocked="$diagnostics/${pair#*:}"
      if [[ -f "$blocked" && -s "$blocked" ]]; then
        count="$(wc -l < "$blocked")"
        shown="$(head -n 20 "$blocked" | sed 's/^/  - /')"
        printf '\n%s (showing at most 20 of %s):\n%s\n' "$label" "$count" "$shown"
        if [[ "$count" -gt 20 ]]; then echo '  - ... truncated; full list is in the attachment'; fi
      fi
    done
  } > "$diagnostics/summary.md"
}

cleanup() {
  local status="$?"
  trap - EXIT
  set +e
  stage_name="gate total"
  stage_started_utc="$started_at"
  stage_started_ns="$started_ns"
  stage_finish "$status" >/dev/null
  printf 'event\t%s\nhost\t%s\nbase_sha\t%s\nhead_sha\t%s\nnix_version\t%s\ncomparison\t%s\nsubstituters\t%s\nfinal_exit_status\t%s\n' \
    "$event" "$host" "$base_sha" "$head_sha" "$nix_version" "$base_mode" "$china_substituters" "$status" > "$diagnostics/metadata.txt"
  write_summary "$status" || true
  git worktree remove --force "${tmp}/base" >/dev/null 2>&1 || true
  rm -rf "$tmp"
  exit "$status"
}
trap cleanup EXIT

case "${GITHUB_EVENT_NAME:-}" in
  pull_request)
    base_sha="$(git rev-parse HEAD^1)"
    ;;
  merge_group)
    base_sha="$(jq -er '.merge_group.base_sha' "$GITHUB_EVENT_PATH")"
    ;;
  workflow_dispatch)
    base_sha="$(git rev-parse origin/main)"
    ;;
  *)
    echo "Unsupported GitHub event: ${GITHUB_EVENT_NAME:-<unset>}" >&2
    exit 1
    ;;
esac

git worktree add --detach "${tmp}/base" "$base_sha" >/dev/null

base_blocked="$diagnostics/base.blocked.txt"
head_blocked="$diagnostics/head.blocked.txt"
base_direct="$diagnostics/base.direct.txt"
head_direct="$diagnostics/head.direct.txt"
new_blocked="$diagnostics/new.blocked.txt"
new_direct="$diagnostics/new.direct.txt"

base_mode="delta"
base_source=()
if [[ "$(jq -r '.nodes.yazelix.locked.rev' "${tmp}/base/flake.lock")" == "16dae898bc79e47f55f729f93cd2a8fc40209a4e" ]]; then
  # Its private Zellij fork was merged upstream; keep the old Yazelix package for comparison.
  base_source=(--override-input yazelix/yazelixZellij github:zellij-org/zellij/81f56e1aed4e17b822af5cb382a8f524e35f3eae)
  base_mode="delta (public Zellij source for historical base)"
fi
collect_blocked_derivations base "${tmp}/base" "$base_blocked" "$base_direct" "${base_source[@]}"
base_collected=true
collect_blocked_derivations head "$PWD" "$head_blocked" "$head_direct"
head_collected=true

stage_start "final difference"
if comm -13 "$base_blocked" "$head_blocked" > "$new_blocked" && comm -13 "$base_direct" "$head_direct" > "$new_direct"; then
  stage_rc=0
else
  stage_rc=$?
fi
stage_finish "$stage_rc"
if [[ "$stage_rc" -ne 0 ]]; then
  exit "$stage_rc"
fi
diff_completed=true

if [[ -s "$new_direct" ]]; then
  echo "New declared direct fetches:"
  sed -n '1,20s/^/  /p' "$new_direct"
fi

if [[ -s "$new_blocked" ]]; then
  echo "116 cache gate found unapproved local derivations:" >&2
  sed -n '1,20s/^/  /p' "$new_blocked" >&2
  exit 1
fi
