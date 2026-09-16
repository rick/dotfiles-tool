#!/usr/bin/env bats

load helper

setup_file() { export EDITOR="" VISUAL=""; }

@test "new creates a dated, slugified note" {
  use_repos "$(make_repo one)"
  dotfiles migrations new "Switch the LOGIN shell!! to bash 5"
  assert_success
  local today; today="$(date '+%Y%m%d')"
  [ -f "$SANDBOX/one/migrations/$today-switch-the-login-shell-to-bash-5.md" ]
}

@test "new seeds a title derived from the slug" {
  use_repos "$(make_repo one)"
  dotfiles migrations new "drop the old s3cfg"
  run head -1 "$SANDBOX/one/migrations/$(date '+%Y%m%d')-drop-the-old-s3cfg.md"
  assert_equal "$output" "# Drop the old s3cfg"
}

@test "a new note is immediately pending" {
  use_repos "$(make_repo one)"
  dotfiles migrations new "do a thing"
  dotfiles migrations
  assert_contains "next  $(date '+%Y%m%d')-do-a-thing"
}

@test "new refuses to overwrite an existing id" {
  use_repos "$(make_repo one)"
  dotfiles migrations new "same name"
  dotfiles migrations new "same name"
  assert_failure
  assert_contains "already exists"
}

@test "new rejects a slug that reduces to nothing" {
  use_repos "$(make_repo one)"
  dotfiles migrations new "!!!"
  assert_failure
  assert_contains "usage: dotfiles migrations new"
}

@test "new with no slug fails" {
  use_repos "$(make_repo one)"
  dotfiles migrations new
  assert_failure
  assert_contains "usage: dotfiles migrations new"
}

@test "new -n creates nothing" {
  use_repos "$(make_repo one)"
  dotfiles migrations new "not for real" -n
  assert_success
  assert_contains "would create"
  assert_equal "$(ls "$SANDBOX/one/migrations" | wc -l | tr -d ' ')" "0"
}

@test "new defaults to the first configured repo" {
  use_repos "$(make_repo first)" "$(make_repo second)"
  dotfiles migrations new "lands in first"
  assert_success
  [ -f "$SANDBOX/first/migrations/$(date '+%Y%m%d')-lands-in-first.md" ]
  [ ! -f "$SANDBOX/second/migrations/$(date '+%Y%m%d')-lands-in-first.md" ]
}

@test "--repo picks the config repo" {
  use_repos "$(make_repo first)" "$(make_repo second)"
  dotfiles migrations new "lands in second" --repo second
  assert_success
  [ -f "$SANDBOX/second/migrations/$(date '+%Y%m%d')-lands-in-second.md" ]
}

@test "--repo with an unknown id fails" {
  use_repos "$(make_repo first)"
  dotfiles migrations new "nope" --repo nosuchrepo
  assert_failure
  assert_contains "no configured repo named 'nosuchrepo'"
}

@test "--repo with no value fails" {
  use_repos "$(make_repo first)"
  dotfiles migrations new "nope" --repo
  assert_failure
  assert_contains "--repo needs a repo id"
}

@test "new does not source the config of repos it was not asked about" {
  local first second
  first="$(make_repo first)"
  second="$(make_repo second)"
  # A repo whose conf has an observable side effect when sourced.
  printf 'touch "%s/sourced-second"\n' "$SANDBOX" >>"$second/dotfiles.conf"
  use_repos "$first" "$second"
  dotfiles migrations new "only touches first"
  assert_success
  [ ! -e "$SANDBOX/sourced-second" ]
}

@test "EDITOR is not launched when not interactive" {
  use_repos "$(make_repo one)"
  export EDITOR="$SANDBOX/should-not-run"
  printf '#!/bin/sh\ntouch "%s/editor-ran"\n' "$SANDBOX" >"$EDITOR"
  chmod +x "$EDITOR"
  dotfiles migrations new "no editor please"
  assert_success
  [ ! -e "$SANDBOX/editor-ran" ]
}
