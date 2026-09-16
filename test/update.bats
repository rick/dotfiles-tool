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

@test "a failed pull warns and exits non-zero" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  git -C "$clone" remote set-url origin /nonexistent/repo.git
  dotfiles update
  assert_failure
  assert_contains "pull failed"
  assert_contains "some repos were not updated"
}

@test "a failed pull does not stop the other repos being applied" {
  local broken; broken="$(make_git_repo app)"
  git -C "$broken" remote set-url origin /nonexistent/repo.git
  use_repos "$broken" "$(make_repo other)"
  dotfiles update
  assert_failure
  [ -L "$SANDBOX/target-other/.otherrc" ]
}

@test "a clean update exits zero" {
  use_repos "$(make_git_repo app)"
  dotfiles update
  assert_success
  assert_contains "done"
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
