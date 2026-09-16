#!/usr/bin/env bats

load helper

# A git checkout standing in for the tool's own, with an upstream to pull from.
# Nothing executes out of it: the running script is still bin/dotfiles, so a
# self-update in here is observable without swapping the code under the test.
make_tool_repo() {
  local up="$SANDBOX/tool-upstream"
  mkdir -p "$up"
  printf 'v1\n' >"$up/VERSION"
  git -C "$up" init -q --initial-branch=main .
  git -C "$up" config user.email t@example.com
  git -C "$up" config user.name Test
  git -C "$up" add -A
  git -C "$up" commit -qm initial
  git clone -q "$up" "$SANDBOX/tool"
  git -C "$SANDBOX/tool" config user.email t@example.com
  git -C "$SANDBOX/tool" config user.name Test
  export DOTFILES_TOOL_REPO="$SANDBOX/tool"
}

tool_commit_upstream() {
  printf 'v2\n' >"$SANDBOX/tool-upstream/VERSION"
  git -C "$SANDBOX/tool-upstream" add -A
  git -C "$SANDBOX/tool-upstream" commit -qm "tool change"
}

@test "update pulls the tool's own checkout" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  make_tool_repo
  tool_commit_upstream
  dotfiles update
  assert_success
  assert_contains "updating dotfiles"
  assert_equal "$(cat "$SANDBOX/tool/VERSION")" v2
}

@test "a tool already current does not restart the run" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  make_tool_repo
  dotfiles update
  assert_success
  refute_contains "restarting"
}

@test "a pulled tool restarts the run exactly once" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  make_tool_repo
  tool_commit_upstream
  dotfiles update
  assert_success
  assert_contains "restarting"
  assert_equal "$(count_matching '^==> updating dotfiles \(')" 1
}

@test "a dirty tool checkout is left alone" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  make_tool_repo
  tool_commit_upstream
  printf 'local work\n' >>"$SANDBOX/tool/VERSION"
  dotfiles update
  assert_success
  assert_contains "uncommitted changes; not updating itself"
  assert_equal "$(head -1 "$SANDBOX/tool/VERSION")" v1
}

@test "an untracked file counts as dirty" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  make_tool_repo
  tool_commit_upstream
  printf 'scratch\n' >"$SANDBOX/tool/notes.txt"
  dotfiles update
  assert_contains "not updating itself"
  assert_equal "$(cat "$SANDBOX/tool/VERSION")" v1
}

@test "--skip-tool leaves the tool unpulled" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  make_tool_repo
  tool_commit_upstream
  dotfiles update --skip-tool
  assert_success
  refute_contains "updating dotfiles"
  assert_equal "$(cat "$SANDBOX/tool/VERSION")" v1
}

@test "a detached branch with no upstream is left alone" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  make_tool_repo
  git -C "$SANDBOX/tool" checkout -q -b local-only
  dotfiles update
  assert_success
  assert_contains "no upstream; not updating itself"
}

@test "update -n pulls the tool no more than it pulls a repo" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  make_tool_repo
  tool_commit_upstream
  dotfiles update -n
  assert_success
  assert_contains "would git pull --rebase"
  assert_equal "$(cat "$SANDBOX/tool/VERSION")" v1
}

@test "a tool checkout that is not a git repo is skipped quietly" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  mkdir -p "$SANDBOX/plain"
  export DOTFILES_TOOL_REPO="$SANDBOX/plain"
  dotfiles update
  assert_success
  refute_contains "updating dotfiles"
}

@test "other commands never touch the tool checkout" {
  local clone; clone="$(make_git_repo app)"
  use_repos "$clone"
  make_tool_repo
  tool_commit_upstream
  dotfiles link
  assert_success
  assert_equal "$(cat "$SANDBOX/tool/VERSION")" v1
}
