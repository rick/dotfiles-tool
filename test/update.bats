#!/usr/bin/env bats

load helper

@test "update pulls a migration added upstream" {
  local clone; clone="$(make_git_repo app 20260101-alpha)"
  use_repos "$clone"
  dotfiles install                      # baseline what exists today
  add_migration "$SANDBOX/app-upstream" 20260202-beta
  dotfiles update
  assert_success
  assert_contains "1 pending migration(s)"
  assert_contains "20260202-beta"
}

@test "update shows a pending migration without marking it" {
  local clone; clone="$(make_git_repo app 20260101-alpha)"
  use_repos "$clone"
  dotfiles update
  assert_contains "1 pending migration(s)"
  dotfiles migrations
  assert_contains "next  20260101-alpha"
}

@test "update nags again on the next run" {
  local clone; clone="$(make_git_repo app 20260101-alpha)"
  use_repos "$clone"
  dotfiles update
  dotfiles update
  assert_contains "1 pending migration(s)"
}

@test "update warns but succeeds on a dirty tree" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  printf 'scratch\n' >"$clone/packages/demo/.scratch"
  dotfiles update
  assert_success
  assert_contains "has uncommitted changes"
  [ -f "$clone/packages/demo/.scratch" ]
}

@test "update warns about unpushed commits" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  git -C "$clone" commit -q --allow-empty -m "local work"
  dotfiles update
  assert_success
  assert_contains "unpushed commit(s)"
}

@test "a failed pull warns and does not abort the run" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  git -C "$clone" remote set-url origin /nonexistent/repo.git
  dotfiles update
  assert_success
  assert_contains "pull failed"
}

@test "a non-git config repo warns and still links" {
  use_repos "$(make_repo plain)"
  dotfiles update
  assert_success
  assert_contains "is not a git checkout"
  [ -L "$SANDBOX/target-plain/.plainrc" ]
}

@test "update -n pulls nothing" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  local before; before="$(git -C "$clone" rev-parse HEAD)"
  add_migration "$SANDBOX/app-upstream" 20260202-beta
  dotfiles update -n
  assert_success
  assert_contains "would git pull"
  assert_equal "$(git -C "$clone" rev-parse HEAD)" "$before"
}

@test "update applies every configured repo" {
  use_repos "$(make_repo one)" "$(make_repo two)"
  dotfiles update
  assert_success
  [ -L "$SANDBOX/target-one/.onerc" ]
  [ -L "$SANDBOX/target-two/.tworc" ]
}
