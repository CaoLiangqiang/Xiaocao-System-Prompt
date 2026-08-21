#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d)"
workstation_root="$test_root/workstation"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$workstation_root/.codex"
printf 'previous Codex guidance\n' > "$workstation_root/.codex/AGENTS.md"

run_manager() {
  env -u CODEX_HOME -u KIRO_HOME -u HERMES_HOME -u XDG_STATE_HOME \
    AI_BUILD_UP_HOME="$workstation_root" \
    bash "$repo_dir/scripts/configure-global-links.sh" "$@"
}

run_manager --install
run_manager --check

expected_sources=(
  "$repo_dir/AGENTS.md"
  "$repo_dir/CLAUDE.md"
  "$repo_dir/KIRO.md"
  "$repo_dir/SOUL.md"
)
installed_targets=(
  "$workstation_root/.codex/AGENTS.md"
  "$workstation_root/.claude/CLAUDE.md"
  "$workstation_root/.kiro/steering/AGENTS.md"
  "$workstation_root/.hermes/SOUL.md"
)

for index in "${!expected_sources[@]}"; do
  [ -L "${installed_targets[$index]}" ]
  [ "$(readlink "${installed_targets[$index]}")" = "${expected_sources[$index]}" ]
done

backup_file="$(find "$workstation_root/.local/state/ai-build-up/backups" -type f -name codex-agents -print -quit)"
[ -n "$backup_file" ]
grep -F 'previous Codex guidance' "$backup_file" >/dev/null

backup_count_before="$(find "$workstation_root/.local/state/ai-build-up/backups" -type f | wc -l)"
run_manager --install
backup_count_after="$(find "$workstation_root/.local/state/ai-build-up/backups" -type f | wc -l)"
[ "$backup_count_before" -eq "$backup_count_after" ]

printf 'PASS: global instruction links are backed up, installed, checked, and idempotent\n'
