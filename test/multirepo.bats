#!/usr/bin/env bats

load helper

both() {
  use_repos "$(make_repo one 20260101-alpha)" "$(make_repo two 20260202-beta)"
}

@test "list reports each repo separately" {
  both
  dotfiles migrations
  assert_contains "one"
  assert_contains "20260101-alpha"
  assert_contains "two"
  assert_contains "20260202-beta"
}

@test "each repo marks next independently" {
  both
  dotfiles migrations
  assert_equal "$(count_matching '^  next')" "2"
}

@test "show with no id takes the first repo in config order" {
  both
  dotfiles migrations show
  assert_contains "20260101-alpha"
  refute_contains "20260202-beta"
}

@test "config order decides, not id order" {
  use_repos "$(make_repo two 20260202-beta)" "$(make_repo one 20260101-alpha)"
  dotfiles migrations show
  assert_contains "20260202-beta"
  refute_contains "20260101-alpha"
}

@test "show falls through when the first repo is clear" {
  both
  dotfiles migrations done 20260101-alpha
  dotfiles migrations show
  assert_contains "20260202-beta"
}

@test "done with no id acts on one repo at a time" {
  both
  dotfiles migrations done
  assert_equal "$(count_matching 'marked .* done')" "1"
  dotfiles migrations done
  dotfiles migrations
  assert_contains "no pending migrations"
}

@test "an explicit id is found in whichever repo holds it" {
  both
  dotfiles migrations done 20260202-beta
  assert_success
  assert_contains "two: marked 20260202-beta done"
}

@test "each repo keeps its own state file" {
  both
  dotfiles migrations done --all
  [ -f "$STATE/one/migrations.applied" ]
  [ -f "$STATE/two/migrations.applied" ]
  assert_equal "$(grep -c . "$STATE/one/migrations.applied")" "1"
}

@test "baselining one repo does not touch the other" {
  both
  rm -rf "$STATE/two"
  dotfiles install
  [ -f "$STATE/two/installed" ]
}
