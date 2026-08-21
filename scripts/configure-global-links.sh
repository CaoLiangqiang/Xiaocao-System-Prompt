#!/usr/bin/env bash
set -uo pipefail

usage() {
  printf '%s\n' \
    'Usage: configure-global-links.sh --check|--install' \
    'Checks or installs global Agent instruction links from this repository.'
}

case "${1:-}" in
  --check|--install)
    action="$1"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_dir="$(cd "$script_dir/.." && pwd -P)"
user_root="${AI_BUILD_UP_HOME:-${HOME:?HOME is not set}}"
codex_root="${CODEX_HOME:-$user_root/.codex}"
kiro_root="${KIRO_HOME:-$user_root/.kiro}"
hermes_root="${HERMES_HOME:-$user_root/.hermes}"
state_root="${XDG_STATE_HOME:-$user_root/.local/state}/ai-build-up"
backup_dir=''

labels=(codex-agents claude-guidance kiro-steering hermes-soul)
sources=(
  "$repo_dir/AGENTS.md"
  "$repo_dir/CLAUDE.md"
  "$repo_dir/KIRO.md"
  "$repo_dir/SOUL.md"
)
targets=(
  "$codex_root/AGENTS.md"
  "$user_root/.claude/CLAUDE.md"
  "$kiro_root/steering/AGENTS.md"
  "$hermes_root/SOUL.md"
)

is_current_link() {
  local source="$1"
  local target="$2"
  [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]
}

ensure_backup_dir() {
  if [ -z "$backup_dir" ]; then
    backup_dir="$state_root/backups/$(date -u +%Y%m%dT%H%M%SZ)-$$-system-prompt"
    mkdir -p "$backup_dir"
  fi
}

backup_target() {
  local label="$1"
  local target="$2"
  ensure_backup_dir
  mv "$target" "$backup_dir/$label"
  printf '[BACKUP] %s -> %s\n' "$target" "$backup_dir/$label"
}

check_links() {
  local failures=0
  local index

  for index in "${!sources[@]}"; do
    if is_current_link "${sources[$index]}" "${targets[$index]}"; then
      printf '[OK]      %s -> %s\n' "${targets[$index]}" "${sources[$index]}"
    elif [ -e "${targets[$index]}" ] || [ -L "${targets[$index]}" ]; then
      printf '[DRIFT]   %s is not linked to %s\n' "${targets[$index]}" "${sources[$index]}"
      failures=$((failures + 1))
    else
      printf '[MISSING] %s\n' "${targets[$index]}"
      failures=$((failures + 1))
    fi
  done

  [ "$failures" -eq 0 ]
}

install_links() {
  local index

  for source in "${sources[@]}"; do
    if [ ! -f "$source" ]; then
      printf 'Required source file is missing: %s\n' "$source" >&2
      return 1
    fi
  done

  for index in "${!sources[@]}"; do
    if is_current_link "${sources[$index]}" "${targets[$index]}"; then
      printf '[OK]      %s\n' "${targets[$index]}"
      continue
    fi

    mkdir -p "$(dirname "${targets[$index]}")"
    if [ -e "${targets[$index]}" ] || [ -L "${targets[$index]}" ]; then
      backup_target "${labels[$index]}" "${targets[$index]}"
    fi
    ln -s "${sources[$index]}" "${targets[$index]}"
    printf '[LINKED]  %s -> %s\n' "${targets[$index]}" "${sources[$index]}"
  done

  if [ -n "$backup_dir" ]; then
    printf 'Previous targets were preserved in %s\n' "$backup_dir"
  fi
}

if [ "$action" = '--check' ]; then
  check_links
else
  install_links && check_links
fi
