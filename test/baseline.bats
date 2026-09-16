#!/usr/bin/env bats

load helper

two() { use_repos "$(make_repo one 20260101-alpha 20260202-beta)"; }

@test "install baselines a new machine silently" {
  two
  dotfiles install
  assert_success
  assert_contains "baselined 2 migration(s)"
  dotfiles migrations
  assert_contains "no pending migrations"
}

@test "install records the installed marker" {
  two
  dotfiles install
  [ -f "$STATE/one/installed" ]
}

@test "install -n baselines nothing and writes no state" {
  two
  dotfiles install -n
  assert_success
  assert_contains "would baseline 2 migration(s)"
  [ ! -f "$STATE/one/installed" ]
  [ ! -f "$STATE/one/migrations.applied" ]
}

@test "a second install does not re-baseline" {
  two
  dotfiles install
  dotfiles migrations done --all 2>/dev/null || true
  dotfiles install
  refute_contains "baselined"
}

@test "deleting acknowledgements does NOT re-baseline an installed machine" {
  two
  dotfiles install
  rm -f "$STATE/one/migrations.applied"
  dotfiles install
  assert_success
  refute_contains "baselined"
  dotfiles migrations
  assert_contains "next  20260101-alpha"
}

@test "a machine predating the marker is not re-baselined" {
  two
  # Simulates state written before `installed` existed.
  mkdir -p "$STATE/one"
  printf '20260101-alpha\t2026-01-01T00:00:00Z\n' >"$STATE/one/migrations.applied"
  dotfiles install
  assert_success
  refute_contains "baselined"
  dotfiles migrations
  assert_contains "next  20260202-beta"
}

@test "an installed machine still sees migrations added later" {
  two
  dotfiles install
  add_migration "$SANDBOX/one" 20260303-gamma
  dotfiles migrations
  assert_contains "next  20260303-gamma"
}

@test "update never baselines" {
  two
  dotfiles update
  assert_success
  refute_contains "baselined"
  assert_contains "2 pending migration(s)"
}

@test "update records the installed marker too" {
  two
  dotfiles update
  [ -f "$STATE/one/installed" ]
}

@test "a repo with no migrations dir gets no state file" {
  use_repos "$(make_repo bare)"
  rmdir "$SANDBOX/bare/migrations"
  dotfiles install
  assert_success
  [ ! -f "$STATE/bare/migrations.applied" ]
}
