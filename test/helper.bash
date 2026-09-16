# Sourced by every .bats file.
# shellcheck shell=bash
# $status and $output are set by bats' `run`.
# shellcheck disable=SC2154

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES="$REPO_ROOT/bin/dotfiles"

# Which bash runs the script under test. script/test sweeps this across the
# versions the tool claims to support; bin/dotfiles itself is `env bash`.
TEST_BASH="${DOTFILES_TEST_BASH:-bash}"

setup() {
  SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")"
  STATE="$SANDBOX/state"
  TARGET="$SANDBOX/target"
  mkdir -p "$STATE" "$TARGET"
  export DOTFILES_STATE="$STATE"
}

teardown() {
  [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ] && rm -rf "$SANDBOX"
  return 0
}

# ------------------------------------------------------------- fixtures ----

# make_repo <name> [migration-id ...] -- a config repo with one stow package
# and a markdown note per id. Echoes its path.
make_repo() {
  local name="$1"; shift
  local dir="$SANDBOX/$name" id
  mkdir -p "$dir/packages/demo" "$dir/migrations"
  printf 'hello\n' >"$dir/packages/demo/.${name}rc"
  cat >"$dir/dotfiles.conf" <<CONF
PACKAGES=(demo)
TARGET="$SANDBOX/target-$name"
CONF
  mkdir -p "$SANDBOX/target-$name"
  for id in "$@"; do
    printf '# Title for %s\n\nBody of %s.\n\n    run-this --now\n' "$id" "$id" \
      >"$dir/migrations/$id.md"
  done
  printf '%s\n' "$dir"
}

# make_git_repo <name> [migration-id ...] -- like make_repo, plus an upstream
# it is cloned from, so `update` has something to pull. Echoes the clone path.
make_git_repo() {
  local name="$1"; shift
  local up; up="$(make_repo "$name-upstream" "$@")"
  git -C "$up" init -q --initial-branch=main .
  git -C "$up" config user.email t@example.com
  git -C "$up" config user.name Test
  git -C "$up" add -A
  git -C "$up" commit -qm initial
  git clone -q "$up" "$SANDBOX/$name"
  git -C "$SANDBOX/$name" config user.email t@example.com
  git -C "$SANDBOX/$name" config user.name Test
  sed -i.bak "s|^TARGET=.*|TARGET=\"$SANDBOX/target-$name\"|" "$SANDBOX/$name/dotfiles.conf"
  rm -f "$SANDBOX/$name/dotfiles.conf.bak"
  mkdir -p "$SANDBOX/target-$name"
  printf '%s\n' "$SANDBOX/$name"
}

# Add a migration to an existing repo (upstream, for update tests to pull).
add_migration() {
  local dir="$1" id="$2"
  printf '# Title for %s\n\nBody of %s.\n' "$id" "$id" >"$dir/migrations/$id.md"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" add -A && git -C "$dir" commit -qm "add $id"
  fi
}

use_repos() {
  local joined
  joined="$(IFS=:; printf '%s' "$*")"
  export DOTFILES_REPOS="$joined"
}

# ------------------------------------------------------------ invocation ----

dotfiles() { run "$TEST_BASH" "$DOTFILES" "$@"; }

# Output with ANSI stripped, for matching against a tty-less run's colour codes.
plain_output() { printf '%s' "$output" | sed -e $'s/\033\\[[0-9;]*m//g'; }

# ------------------------------------------------------------ assertions ----

assert_success() {
  if [ "$status" -ne 0 ]; then
    printf 'expected success, got exit %s\n--- output ---\n%s\n' "$status" "$output" >&2
    return 1
  fi
}

assert_failure() {
  if [ "$status" -eq 0 ]; then
    printf 'expected failure, got exit 0\n--- output ---\n%s\n' "$output" >&2
    return 1
  fi
}

assert_contains() {
  case "$(plain_output)" in
    *"$1"*) return 0 ;;
  esac
  printf 'expected output to contain: %s\n--- output ---\n%s\n' "$1" "$output" >&2
  return 1
}

refute_contains() {
  case "$(plain_output)" in
    *"$1"*)
      printf 'expected output NOT to contain: %s\n--- output ---\n%s\n' "$1" "$output" >&2
      return 1 ;;
  esac
  return 0
}

assert_equal() {
  if [ "$1" != "$2" ]; then
    printf 'expected: [%s]\n     got: [%s]\n' "$2" "$1" >&2
    return 1
  fi
}

# Count lines of stripped output matching an extended regex.
count_matching() { plain_output | grep -cE "$1" || true; }
