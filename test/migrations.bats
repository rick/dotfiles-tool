#!/usr/bin/env bats

load helper

# A repo with three notes, none acknowledged.
three() { use_repos "$(make_repo one 20260101-alpha 20260202-beta 20260303-gamma)"; }

@test "list shows nothing when the repo has no migrations dir" {
  use_repos "$(make_repo one)"
  dotfiles migrations
  assert_success
  assert_contains "no pending migrations"
}

@test "list marks the earliest pending as next and the rest todo" {
  three
  dotfiles migrations
  assert_success
  assert_contains "next  20260101-alpha"
  assert_contains "todo  20260202-beta"
  assert_contains "todo  20260303-gamma"
}

@test "list shows titles, not filenames" {
  three
  dotfiles migrations
  assert_contains "Title for 20260101-alpha"
}

@test "--all includes applied ones with their date" {
  three
  dotfiles migrations done 20260101-alpha
  dotfiles migrations --all
  assert_success
  assert_contains "done  20260101-alpha"
  assert_contains "next  20260202-beta"
}

@test "--all keeps id order when one is done out of turn" {
  three
  dotfiles migrations done 20260303-gamma
  dotfiles migrations --all
  assert_equal "$(plain_output | grep -cE '^  (done|next|todo)')" "3"
  # gamma is last by id and must stay last despite being the only applied one
  assert_equal "$(plain_output | grep -E '^  (done|next|todo)' | tail -1 | awk '{print $2}')" "20260303-gamma"
  assert_contains "next  20260101-alpha"
}

@test "show with no id renders the first pending" {
  three
  dotfiles migrations show
  assert_success
  assert_contains "20260101-alpha"
  refute_contains "20260202-beta"
}

@test "show advances as migrations are marked done" {
  three
  dotfiles migrations done
  dotfiles migrations show
  assert_contains "20260202-beta"
  refute_contains "Body of 20260101-alpha"
}

@test "show takes an explicit id, including an applied one" {
  three
  dotfiles migrations done 20260101-alpha
  dotfiles migrations show 20260101-alpha
  assert_success
  assert_contains "Body of 20260101-alpha"
}

@test "show --all renders every pending one" {
  three
  dotfiles migrations show --all
  assert_success
  assert_contains "Body of 20260101-alpha"
  assert_contains "Body of 20260202-beta"
  assert_contains "Body of 20260303-gamma"
}

@test "show of an unknown id fails" {
  three
  dotfiles migrations show no-such-id
  assert_failure
  assert_contains "no such migration: no-such-id"
}

@test "show on an empty list succeeds quietly" {
  three
  dotfiles migrations done --all
  dotfiles migrations show
  assert_success
  assert_contains "no pending migrations"
}

@test "done with no id marks the first pending" {
  three
  dotfiles migrations done
  assert_success
  assert_contains "marked 20260101-alpha done"
  dotfiles migrations
  assert_contains "next  20260202-beta"
}

@test "done walks the list one at a time" {
  three
  dotfiles migrations done
  dotfiles migrations done
  dotfiles migrations
  assert_equal "$(count_matching '^  (next|todo)')" "1"
}

@test "done is idempotent for an id already applied" {
  three
  dotfiles migrations done 20260101-alpha
  dotfiles migrations done 20260101-alpha
  assert_success
  assert_contains "was already done"
  assert_equal "$(grep -c 20260101-alpha "$STATE/one/migrations.applied")" "1"
}

@test "done --all marks everything" {
  three
  dotfiles migrations done --all
  assert_success
  dotfiles migrations
  assert_contains "no pending migrations"
}

@test "done of an unknown id fails" {
  three
  dotfiles migrations done no-such-id
  assert_failure
  assert_contains "no such migration: no-such-id"
}

@test "done on an empty list succeeds quietly" {
  three
  dotfiles migrations done --all
  dotfiles migrations done
  assert_success
  assert_contains "no pending migrations"
}

@test "acknowledgements are id TAB timestamp" {
  three
  dotfiles migrations done 20260101-alpha
  run awk -F'\t' 'NR==1 { print NF, $1, ($2 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}T/) }' \
    "$STATE/one/migrations.applied"
  assert_equal "$output" "2 20260101-alpha 1"
}

@test "the state file is hand-editable: removing a line brings the note back" {
  three
  dotfiles migrations done --all
  grep -v 20260202-beta "$STATE/one/migrations.applied" >"$STATE/one/tmp"
  mv "$STATE/one/tmp" "$STATE/one/migrations.applied"
  dotfiles migrations
  assert_contains "next  20260202-beta"
}

@test "unknown migrations subcommand fails" {
  three
  dotfiles migrations wat
  assert_failure
  assert_contains "unknown migrations subcommand: wat"
}
