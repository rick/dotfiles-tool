#!/usr/bin/env bats

load helper

@test "adopts a file into a new package and links it back" {
  use_repos "$(make_repo one)"
  mkdir -p "$SANDBOX/target-one/.claude"
  printf 'my instructions\n' > "$SANDBOX/target-one/.claude/NOTES.md"
  dotfiles adopt llm "$SANDBOX/target-one/.claude/NOTES.md"
  assert_success
  # moved into the package
  [ -f "$SANDBOX/one/packages/llm/.claude/NOTES.md" ]
  assert_equal "$(cat "$SANDBOX/one/packages/llm/.claude/NOTES.md")" "my instructions"
  # and linked back
  [ -L "$SANDBOX/target-one/.claude/NOTES.md" ]
  assert_equal "$(cat "$SANDBOX/target-one/.claude/NOTES.md")" "my instructions"
}

@test "the link points into the config repo" {
  use_repos "$(make_repo one)"
  printf 'x\n' > "$SANDBOX/target-one/.thing"
  dotfiles adopt llm "$SANDBOX/target-one/.thing"
  run readlink "$SANDBOX/target-one/.thing"
  assert_contains "packages/llm/.thing"
}

@test "file mode is preserved" {
  use_repos "$(make_repo one)"
  printf '#!/bin/sh\n' > "$SANDBOX/target-one/.script"
  chmod 700 "$SANDBOX/target-one/.script"
  dotfiles adopt llm "$SANDBOX/target-one/.script"
  run stat -f '%Lp' "$SANDBOX/one/packages/llm/.script"
  assert_equal "$output" "700"
}

@test "adopts several files at once" {
  use_repos "$(make_repo one)"
  printf 'a\n' > "$SANDBOX/target-one/.a"
  printf 'b\n' > "$SANDBOX/target-one/.b"
  dotfiles adopt llm "$SANDBOX/target-one/.a" "$SANDBOX/target-one/.b"
  assert_success
  [ -L "$SANDBOX/target-one/.a" ] && [ -L "$SANDBOX/target-one/.b" ]
}

@test "warns when PACKAGES is explicit and omits the package" {
  use_repos "$(make_repo one)"   # make_repo writes PACKAGES=(demo)
  printf 'x\n' > "$SANDBOX/target-one/.thing"
  dotfiles adopt llm "$SANDBOX/target-one/.thing"
  assert_success
  assert_contains "does not list 'llm'"
  assert_contains "PACKAGES=(... llm)"
}

@test "no warning when the package is already listed" {
  use_repos "$(make_repo one)"
  printf 'x\n' > "$SANDBOX/target-one/.thing"
  dotfiles adopt demo "$SANDBOX/target-one/.thing"
  assert_success
  refute_contains "does not list"
}

@test "-n moves nothing" {
  use_repos "$(make_repo one)"
  printf 'x\n' > "$SANDBOX/target-one/.thing"
  dotfiles adopt llm "$SANDBOX/target-one/.thing" -n
  assert_success
  assert_contains "would adopt"
  [ ! -L "$SANDBOX/target-one/.thing" ]
  [ ! -e "$SANDBOX/one/packages/llm/.thing" ]
}

@test "refuses a file that is already a symlink" {
  use_repos "$(make_repo one)"
  printf 'x\n' > "$SANDBOX/real"
  ln -s "$SANDBOX/real" "$SANDBOX/target-one/.linked"
  dotfiles adopt llm "$SANDBOX/target-one/.linked"
  assert_failure
  assert_contains "already a symlink"
}

@test "refuses a directory" {
  use_repos "$(make_repo one)"
  mkdir -p "$SANDBOX/target-one/.adir"
  dotfiles adopt llm "$SANDBOX/target-one/.adir"
  assert_failure
  assert_contains "only regular files"
}

@test "refuses a file outside the target" {
  use_repos "$(make_repo one)"
  printf 'x\n' > "$SANDBOX/outside"
  dotfiles adopt llm "$SANDBOX/outside"
  assert_failure
  assert_contains "not under"
}

@test "refuses a missing file" {
  use_repos "$(make_repo one)"
  dotfiles adopt llm "$SANDBOX/target-one/.nope"
  assert_failure
  assert_contains "no such file"
}

@test "refuses to clobber a file already in the package" {
  use_repos "$(make_repo one)"
  mkdir -p "$SANDBOX/one/packages/llm"
  printf 'existing\n' > "$SANDBOX/one/packages/llm/.thing"
  printf 'new\n' > "$SANDBOX/target-one/.thing"
  dotfiles adopt llm "$SANDBOX/target-one/.thing"
  assert_failure
  assert_contains "already in the 'llm' package"
  assert_equal "$(cat "$SANDBOX/one/packages/llm/.thing")" "existing"
}

@test "refuses a package name with a slash" {
  use_repos "$(make_repo one)"
  printf 'x\n' > "$SANDBOX/target-one/.thing"
  dotfiles adopt llm/sub "$SANDBOX/target-one/.thing"
  assert_failure
  assert_contains "not a package name"
}

@test "needs both a package and a path" {
  use_repos "$(make_repo one)"
  dotfiles adopt llm
  assert_failure
  assert_contains "usage: dotfiles adopt"
}

@test "--repo picks which config repo receives the file" {
  use_repos "$(make_repo one)" "$(make_repo two)"
  printf 'x\n' > "$SANDBOX/target-two/.thing"
  dotfiles adopt llm "$SANDBOX/target-two/.thing" --repo two
  assert_success
  [ -f "$SANDBOX/two/packages/llm/.thing" ]
  [ ! -e "$SANDBOX/one/packages/llm/.thing" ]
}
