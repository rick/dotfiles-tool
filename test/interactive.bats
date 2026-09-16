#!/usr/bin/env bats

load helper

three() { use_repos "$(make_repo one 20260101-alpha 20260202-beta 20260303-gamma)"; }

# Drive `dotfiles update` on a pty, answering the prompts in order.
answer() {
  local answers="$1"
  run "$REPO_ROOT/test/support/ptyrun.py" "$answers" "$TEST_BASH" "$DOTFILES" update
  [ "$status" -ne 75 ] || { echo "pty driver timed out"; return 1; }
  # Without this a crashed driver yields empty output, which every refute_ passes.
  assert_contains "pending migration(s)"
}

pending_count() {
  "$TEST_BASH" "$DOTFILES" migrations 2>/dev/null |
    sed -e $'s/\033\\[[0-9;]*m//g' | grep -cE '^  (next|todo)' || true
}

@test "y marks the migration done" {
  three
  answer y
  assert_contains "marked 20260101-alpha done"
  assert_equal "$(pending_count)" "2"
}

@test "n leaves it pending" {
  three
  answer n
  refute_contains "marked"
  assert_equal "$(pending_count)" "3"
}

@test "an empty answer defaults to no" {
  three
  answer ""
  assert_equal "$(pending_count)" "3"
}

@test "a marks every remaining migration" {
  three
  answer a
  assert_equal "$(pending_count)" "0"
  assert_equal "$(count_matching 'mark as done\?')" "1"
}

@test "a carries across repos" {
  use_repos "$(make_repo one 20260101-alpha)" "$(make_repo two 20260202-beta)"
  answer a
  assert_equal "$(count_matching 'mark as done\?')" "1"
  assert_contains "marked 20260101-alpha done"
  assert_contains "marked 20260202-beta done"
}

@test "q stops prompting" {
  three
  answer q
  assert_equal "$(count_matching 'mark as done\?')" "1"
  assert_equal "$(pending_count)" "3"
}

@test "q stops rendering, it does not just stop asking" {
  three
  answer q
  assert_contains "Body of 20260101-alpha"
  refute_contains "Body of 20260202-beta"
  refute_contains "Body of 20260303-gamma"
}

@test "q skips later repos entirely" {
  use_repos "$(make_repo one 20260101-alpha)" "$(make_repo two 20260202-beta)"
  answer q
  refute_contains "pending migration(s) for two"
}

@test "answers are taken one prompt at a time" {
  three
  answer y,n,y
  assert_equal "$(pending_count)" "1"
}

@test "without a tty nothing is marked and the hint is printed" {
  three
  dotfiles update
  assert_success
  refute_contains "marked"
  assert_contains "mark them done with"
  assert_equal "$(pending_count)" "3"
}
