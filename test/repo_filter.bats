#!/usr/bin/env bats

load helper

both() { use_repos "$(make_repo one 20260101-alpha)" "$(make_repo two 20260202-beta)"; }

@test "--repo narrows status to one repo" {
  both
  dotfiles status --repo one
  assert_success
  assert_contains "one"
  refute_contains "two"
}

@test "--repo narrows link" {
  both
  dotfiles link --repo two
  assert_success
  [ -L "$SANDBOX/target-two/.tworc" ]
  [ ! -e "$SANDBOX/target-one/.onerc" ]
}

@test "--repo narrows update" {
  both
  dotfiles update --repo two
  assert_success
  assert_contains "updating two"
  refute_contains "updating one"
}

@test "--repo narrows install, and only that repo is baselined" {
  both
  dotfiles install --repo one
  assert_success
  [ -f "$STATE/one/installed" ]
  [ ! -f "$STATE/two/installed" ]
}

@test "--repo narrows the migrations listing" {
  both
  dotfiles migrations --repo two
  assert_success
  assert_contains "20260202-beta"
  refute_contains "20260101-alpha"
}

@test "--repo narrows which repo done acts on" {
  both
  dotfiles migrations done --repo two
  assert_success
  assert_contains "two: marked 20260202-beta done"
  dotfiles migrations --repo one
  assert_contains "next  20260101-alpha"
}

@test "--repo still chooses where a new note lands" {
  both
  dotfiles migrations new "lands in two" --repo two
  assert_success
  [ -f "$SANDBOX/two/migrations/$(date '+%Y%m%d')-lands-in-two.md" ]
  [ ! -f "$SANDBOX/one/migrations/$(date '+%Y%m%d')-lands-in-two.md" ]
}

@test "an unknown --repo fails for any command, not just new" {
  both
  dotfiles status --repo nosuchrepo
  assert_failure
  assert_contains "no configured repo named 'nosuchrepo'"
}

@test "--repo with no value fails" {
  both
  dotfiles status --repo
  assert_failure
  assert_contains "--repo needs a repo id"
}
