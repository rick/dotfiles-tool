# dotfiles-tool

An engine for installing dotfiles. It carries **no configuration of its own** —
it knows how to run GNU Stow and `op inject`, and nothing else.

Your dotfiles live in one or more separate *config repos*: public, private,
personal, work, per-client, whatever. This repo never needs to know what is in
them.

## Quick start

```bash
# 1. the engine
git clone git@github.com:rick/dotfiles-tool.git ~/git/dotfiles-tool
ln -s ~/git/dotfiles-tool/bin/dotfiles ~/bin/dotfiles   # or anywhere on PATH
dotfiles doctor --install                               # stow, 1password-cli, rsync, git

# 2. point it at your config repos, in the order they should apply
mkdir -p ~/.config/dotfiles
printf '%s\n' ~/git/dotfiles-personal ~/git/dotfiles-work > ~/.config/dotfiles/config

# 3. sign in, then apply
op signin
dotfiles install
```

Then, day to day:

```bash
dotfiles update     # pull every repo, re-apply, list anything needing a hand
```

New machine? Steps 1–3 again. Nothing else is needed.

## Commands

```bash
dotfiles install            # deps, secrets, stow, hooks
dotfiles update             # git pull each repo, re-apply, show pending migrations
dotfiles status             # what is configured, what is actually linked
dotfiles doctor             # check dependencies and configuration
dotfiles doctor --install   # ...and brew install whatever is missing
dotfiles link               # stow only
dotfiles unlink             # unstow
dotfiles secrets            # render templates/ only
dotfiles migrations         # notes still to act on by hand
```

Global options: `-n`/`--dry-run` (change nothing), `-v`/`--verbose`, and
`--repo <id>` to act on one config repo instead of all of them.

### Common tasks

```bash
# See what a command would do first
dotfiles install -n

# Adopt files already in $HOME into the config repo, rather than clobbering them
dotfiles link --adopt

# Re-render secrets after editing a template or rotating an item
dotfiles secrets

# Work on one repo only -- handy when another has a slow or unreachable remote
dotfiles update --repo dotfiles-work

# Work through the notes waiting on this machine
dotfiles migrations             # what is outstanding
dotfiles migrations show        # read the next one
dotfiles migrations done        # tick it off

# Leave a note for your other machines
dotfiles migrations new "switch the login shell to bash 5"
```

### Environment

| variable | default | |
| --- | --- | --- |
| `DOTFILES_CONFIG` | `~/.config/dotfiles/config` | list of config repos |
| `DOTFILES_STATE` | `~/.local/share/dotfiles` | rendered secrets and migration state |
| `DOTFILES_REPOS` | *(unset)* | colon-separated repo list, overrides the config file |

## Config repos

`~/.config/dotfiles/config` lists them, one path per line, applied in order:

```
# work laptop
~/git/dotfiles-personal
~/git/dotfiles-work
```

Each repo describes itself:

```
dotfiles-work/
  dotfiles.conf           # describes this repo (sourced as bash)
  packages/               # stow packages: packages/bash/.bashrc -> ~/.bashrc
    bash/
    git/
  templates/              # 1Password templates, rendered by `dotfiles secrets`
    .gitconfig            # ... into ~/.gitconfig
  hooks/
    pre-install           # optional, executable
    post-install
  migrations/             # optional, markdown notes
    20260915-bash5-login-shell.md
```

### `dotfiles.conf`

Sourced as bash, so it can branch on `$HOST`, `$(uname)`, or anything else.

| variable | default | meaning |
| --- | --- | --- |
| `PACKAGES` | every dir under `packages/` | which packages to stow, in order |
| `TEMPLATES` | every file under `templates/` | which templates to render, relative to `templates/` |
| `DEPENDENCIES` | *(none)* | commands this config needs; brew-installed when missing |
| `OP_VAULT` | *(empty)* | exported to templates as `$OP_VAULT` |
| `OP_ACCOUNT` | *(empty)* | which 1Password account to resolve against |
| `TARGET` | `$HOME` | where to link |
| `SECRETS_PACKAGE` | `private` | name of the generated package |
| `PACKAGES_DIR` | `packages` | |
| `TEMPLATES_DIR` | `templates` | |
| `MIGRATIONS_DIR` | `migrations` | |

```bash
OP_VAULT="Work"
PACKAGES=(bash git tmux vim)

# "command [brew package] [cask]" -- package defaults to the command name.
DEPENDENCIES=(
  "starship"
  "op 1password-cli cask"
)

case "$HOST" in
  some-laptop) PACKAGES+=(docker) ;;
esac
```

A dependency that will not install is a warning, not a fatal error — the rest
of the config still gets linked. Bigger setup jobs (a Brewfile, mise, whatever)
belong in `hooks/post-install`, which runs with `DOTFILES_REPO`,
`DOTFILES_TARGET`, `DOTFILES_HOST` and `OP_VAULT` in its environment.

### Templates and secrets

Every file under `templates/` is rendered through `op inject` into
`~/.local/share/dotfiles/<repo>/private/`, which is then stowed as a normal
package. Rendered files are `0600`, the directory `0700`. Nothing is written
into the config repo, so there is no gitignored `private/` to commit by
accident.

Set `TEMPLATES` to render only some of them, per host if you like:

```bash
TEMPLATES=(.gitconfig)
case "$HOST" in
  work-laptop) ;;
  *) TEMPLATES+=(.s3cfg) ;;   # a secret that stays off the work machine
esac
```

Templates can interpolate `$hostname` (short hostname, for per-machine
secrets), `$DOTFILES_HOST` (the same value) and `$OP_VAULT`, so one template
works across machines and vaults:

```gitconfig
[user]
	signingKey = "op://$OP_VAULT/SSH Signing Keys/$hostname"
```

A file with no `op://` reference is copied verbatim and needs no 1Password
session.

**Set `OP_ACCOUNT` whenever more than one account is signed in.** A secret
reference names a vault but not an account, so an unqualified one resolves
against whichever account `op` treats as default — and "Private" is an alias
for the personal vault in *every* account. A reference meant for one account
will go looking in another and fail, or worse, find a same-named item.

Rendering is all-or-nothing. If any template fails — expired session, renamed
item, typo'd reference — nothing is swapped into place and the previous files
stay as they were. Stow symlinks point into that directory, so a partial write
would leave dangling links across your home directory.

### Migrations

Some changes need a hand on each machine: a new login shell, a stale file to
delete, a `defaults write`. Leave a note.

```bash
dotfiles migrations new "switch the login shell to bash 5"
# -> migrations/20260915-switch-the-login-shell-to-bash-5.md, opened in $EDITOR
```

The slug is normalised and the date prefix keeps them in order; the basename is
the id. The note lands in the first configured repo unless `--repo <id>` says
otherwise. Writing the file by hand works just as well.

```markdown
# Switch the login shell to Homebrew's bash

bash-completion needs 4.2+; stock /bin/bash is 3.2.

    echo /opt/homebrew/bin/bash | sudo tee -a /etc/shells
    chsh -s /opt/homebrew/bin/bash
```

`dotfiles update` prints the notes this machine has not acknowledged and offers
to mark them done. **Nothing is ever executed** — a migration is a note to you,
so it can ask for things no script could safely do on its own.

```bash
dotfiles migrations              # pending
dotfiles migrations --all        # whole timeline, done ones included
dotfiles migrations show         # read the next pending one
dotfiles migrations show <id>    # read a specific one
dotfiles migrations done         # mark the next pending one done
dotfiles migrations done <id>    # mark a specific one
dotfiles migrations done --all   # mark every pending one
dotfiles migrations new <slug>   # write one, --repo <id> to pick the repo
```

`--all` is the summary — everything in id order, one line each, the earliest
pending marked `next`. That is the one `show` and `done` act on when given no
id.

```
dotfiles-personal
  done  20260915-bash5-login-shell   Switch the login shell to bash 5  (2026-09-15)
  done  20261002-drop-s3cfg          Remove the old ~/.s3cfg           (2026-10-02)
  next  20261110-ripgrep-config      Point ripgrep at the new config file
  todo  20261201-tmux-3-4-bindings   Update the tmux bindings for 3.4
```

A note done out of turn keeps its place on the timeline rather than jumping to
the top. A note you have just written counts as pending on your own machine
too — the tool cannot know whether you did the steps before or after writing
them down, so `migrations new` prints the `done` command for it.

Acknowledgements live in `~/.local/share/dotfiles/<repo>/migrations.applied`,
one `id<TAB>timestamp` per line, per machine. Plain text on purpose: did the
steps by hand? Append the id. Want a note back? Delete the line. Being *shown*
a note never marks it done — only you do, which is the point across several
machines.

A new machine is baselined instead: `install` records every existing note as
applied without printing any, since a migration describes a transition away
from a state that machine never had. "New" means no `installed` marker beside
`migrations.applied`, so deleting the acknowledgements brings the notes back
rather than silently discarding them. Clearing the whole state directory does
still look new.

Steps *every* machine needs belong in this README or `hooks/post-install`, not
only in a migration. The login shell above is genuinely both.

### Layering several repos

Stow runs with `--no-folding`, so directories are always real directories and
only leaf files are symlinked. Two repos can both contribute to `~/.bash.d/` or
`~/bin/` without colliding.

Single-file configs need an escape hatch instead:

```gitconfig
# in the shared base repo's .gitconfig
[include]
	path = ~/.gitconfig.local
```

and let the private repo own `~/.gitconfig.local`.

## Tests

```bash
brew install bats-core
script/test                 # every supported bash
bats test                   # just this machine's bash
bats test/migrations.bats   # one file
```

`script/test` runs the suite under `/bin/bash` as well as the `bash` on `PATH`:
the tool targets 3.2, and a bash-4-ism would otherwise pass unnoticed on a
modern machine. CI runs on macOS for the same reason.

Tests drive `bin/dotfiles` as a subprocess against throwaway config repos in a
temp directory, so they never touch real dotfiles. `test/helper.bash` builds the
fixtures; `test/support/ptyrun.py` drives the interactive prompts on a real pty.
