#!/usr/bin/env bash
set -euo pipefail

host="${HOST:-116}"
base_branch="${GITHUB_BASE_REF:-main}"
base_ref="origin/${base_branch}"
default_china_substituters="https://mirrors.ustc.edu.cn/nix-channels/store https://anyrun.cachix.org https://hyprland.cachix.org"
default_china_extra_trusted_public_keys="anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s= hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
china_substituters="${CHINA_SUBSTITUTERS:-${default_china_substituters}}"
china_extra_trusted_public_keys="${CHINA_EXTRA_TRUSTED_PUBLIC_KEYS:-${default_china_extra_trusted_public_keys}}"
tmp="$(mktemp -d)"

cleanup() {
  git worktree remove --force "${tmp}/base" >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT

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

create_yazelix_stub() {
  local stub="$1"
  mkdir -p "$stub"
  cat > "${stub}/flake.nix" <<'EOF'
{
  outputs = { self }: {
    packages.x86_64-linux.yzn = derivation {
      name = "yzn-ci-stub";
      builder = "/bin/sh";
      args = [
        "-c"
        "mkdir -p $out/bin; printf '#!/bin/sh\nexit 0\n' > $out/bin/yzn; chmod +x $out/bin/yzn"
      ];
      system = "x86_64-linux";
    };
  };
}
EOF
}

collect_blocked_derivations() {
  local repo="$1"
  local output_file="$2"
  local direct_file="$3"
  local dry_run_output="${tmp}/dry-run-$(basename "$repo").log"
  local policy_file="${tmp}/policy-$(basename "$repo").json"

  : > "$output_file"
  : > "$direct_file"

  if [[ -f "${repo}/scripts/maint/policy.json" \
    && ! -f "${repo}/scripts/maint/policy-workstation.json" \
    && ! -f "${repo}/scripts/maint/policy-overrides.json" ]]; then
    # Revisions from before the flake policy interface stored one complete policy.
    cp "${repo}/scripts/maint/policy.json" "$policy_file"
  else
    nix eval \
      --json \
      --override-input yazelix-next "path:${tmp}/yazelix-next-stub" \
      "${repo}#lib.maintenancePolicy" \
      > "$policy_file"
  fi

  if ! (
    cd "$repo"
    nix build \
      --dry-run \
      -L \
      --override-input yazelix-next "path:${tmp}/yazelix-next-stub" \
      --option substituters "$china_substituters" \
      --option extra-substituters "" \
      --option extra-trusted-public-keys "$china_extra_trusted_public_keys" \
      ".#nixosConfigurations.${host}.config.system.build.toplevel"
  ) >"$dry_run_output" 2>&1; then
    cat "$dry_run_output" >&2
    return 1
  fi

  mapfile -t derivations < <(
    awk '/^[[:space:]]*\/nix\/store\/.*\.drv$/ { sub(/^[[:space:]]+/, ""); print }' "$dry_run_output" | sort -u
  )
  mapfile -t allowed_markers < <(
    jq -r '.allowedLocalBuildMarkers[]' "$policy_file"
    printf '%s\n' "-yzn-ci-stub.drv"
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

git fetch --quiet origin "${base_branch}:refs/remotes/origin/${base_branch}"
git worktree add --detach "${tmp}/base" "$base_ref" >/dev/null
create_yazelix_stub "${tmp}/yazelix-next-stub"

base_blocked="${tmp}/base.blocked"
head_blocked="${tmp}/head.blocked"
base_direct="${tmp}/base.direct"
head_direct="${tmp}/head.direct"
new_blocked="${tmp}/new.blocked"
new_direct="${tmp}/new.direct"

collect_blocked_derivations "${tmp}/base" "$base_blocked" "$base_direct"
collect_blocked_derivations "$PWD" "$head_blocked" "$head_direct"

comm -13 "$base_blocked" "$head_blocked" > "$new_blocked"
comm -13 "$base_direct" "$head_direct" > "$new_direct"

{
  echo "### 116 cache gate"
  echo
  echo "- Base blocked derivations: \`$(wc -l < "$base_blocked")\`"
  echo "- Head blocked derivations: \`$(wc -l < "$head_blocked")\`"
  echo "- New blocked derivations: \`$(wc -l < "$new_blocked")\`"
  echo "- New declared direct fetches: \`$(wc -l < "$new_direct")\`"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

if [[ -s "$new_direct" ]]; then
  {
    echo
    echo "New declared direct fetches:"
    sed 's/^/  /' "$new_direct"
  } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
fi

if [[ -s "$new_blocked" ]]; then
  echo "116 cache gate found new unapproved local derivations:" >&2
  sed -n '1,20s/^/  /p' "$new_blocked" >&2
  exit 1
fi
