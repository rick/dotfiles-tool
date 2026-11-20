#!/usr/bin/env bats

load helper

# make_secrets_repo <name> <template-body> [conf-line ...] -- a repo with one
# template next to its package. Echoes its path.
make_secrets_repo() {
  local name="$1" body="$2"; shift 2
  local dir; dir="$(make_repo "$name")"
  mkdir -p "$dir/templates"
  printf '%s\n' "$body" >"$dir/templates/.${name}-secret"
  local line
  for line in "$@"; do printf '%s\n' "$line" >>"$dir/dotfiles.conf"; done
  printf '%s\n' "$dir"
}

@test "a template without op:// references is rendered and linked" {
  use_repos "$(make_secrets_repo one 'plain value')"
  dotfiles install
  assert_success
  [ -L "$SANDBOX/target-one/.one-secret" ]
  [ "$(cat "$SANDBOX/target-one/.one-secret")" = "plain value" ]
}

@test "SECRETS=0 renders and links nothing, and needs no op" {
  use_repos "$(make_secrets_repo one 'op://Vault/item/field' 'SECRETS=0')"
  PATH="/usr/bin:/bin:$(dirname "$(command -v stow)"):$(dirname "$(command -v rsync)")" \
    dotfiles install
  assert_success
  [ -L "$SANDBOX/target-one/.onerc" ]
  [ ! -e "$SANDBOX/target-one/.one-secret" ]
  [ ! -d "$STATE/one/private" ]
  refute_contains "no generated secrets yet"
}

@test "SECRETS=0 does not link secrets rendered earlier" {
  local repo; repo="$(make_secrets_repo one 'plain value')"
  use_repos "$repo"
  dotfiles install
  dotfiles unlink
  printf 'SECRETS=0\n' >>"$repo/dotfiles.conf"
  dotfiles link
  assert_success
  [ -L "$SANDBOX/target-one/.onerc" ]
  [ ! -e "$SANDBOX/target-one/.one-secret" ]
}

@test "status reports secrets as off" {
  use_repos "$(make_secrets_repo one 'op://Vault/item/field' 'SECRETS=0')"
  dotfiles link
  dotfiles status
  assert_success
  assert_contains "off (SECRETS=0)"
}
