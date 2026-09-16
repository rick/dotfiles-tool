#!/usr/bin/env bats

load helper

@test "help lists every command" {
  dotfiles help
  assert_success
  for cmd in install update migrations link unlink secrets status doctor; do
    assert_contains "  $cmd"
  done
}

@test "no arguments prints help" {
  dotfiles
  assert_success
  assert_contains "usage: dotfiles <command>"
}

@test "unknown command fails" {
  dotfiles frobnicate
  assert_failure
  assert_contains "unknown command: frobnicate"
}

@test "unknown option fails" {
  dotfiles status --nope
  assert_failure
  assert_contains "unknown option: --nope"
}

@test "version prints a version" {
  dotfiles version
  assert_success
  assert_contains "dotfiles "
}

@test "link stows a package into the target" {
  use_repos "$(make_repo one)"
  dotfiles link
  assert_success
  [ -L "$SANDBOX/target-one/.onerc" ]
}

@test "unlink removes it again" {
  use_repos "$(make_repo one)"
  dotfiles link
  dotfiles unlink
  assert_success
  [ ! -e "$SANDBOX/target-one/.onerc" ]
}

@test "status reports linked packages" {
  use_repos "$(make_repo one)"
  dotfiles link
  dotfiles status
  assert_success
  assert_contains "1/1 linked"
}

@test "missing config repo is an error" {
  export DOTFILES_REPOS="$SANDBOX/does-not-exist"
  dotfiles status
  assert_failure
  assert_contains "does not exist"
}
