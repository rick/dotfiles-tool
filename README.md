# dotfiles-tool

A small engine for installing dotfiles. It carries **no configuration of its
own** — it knows how to run GNU Stow and `op inject`, and nothing else.

Your actual dotfiles live in one or more separate *config repos*, which can be
public, private, personal, work, per-client, whatever. This repo never needs to
know what is in them.

## Install

```bash
git clone git@github.com:rick/dotfiles-tool.git ~/git/dotfiles-tool
ln -s ~/git/dotfiles-tool/bin/dotfiles ~/bin/dotfiles   # or anywhere on PATH

dotfiles doctor --install     # installs stow + 1password-cli via brew
```

`doctor --install` installs what the engine itself needs. Anything a particular
config repo needs is that repo's business — it declares those in its
`DEPENDENCIES`, and `dotfiles install` puts them in place. Bigger setup jobs
(a Brewfile, mise, whatever) belong in `hooks/post-install`.

## Configure

`~/.config/dotfiles/config` lists the config repos to apply, one path per line,
in order:

```
# work laptop
~/git/dotfiles-work
```

## Use

```bash
dotfiles install          # render secrets, stow everything, run hooks
dotfiles install -n       # same, but change nothing
dotfiles update           # pull each repo, re-apply it, show pending migrations
dotfiles status           # what is configured, what is actually linked
dotfiles migrations       # what still needs doing by hand on this machine
dotfiles link --adopt     # pull pre-existing files into the config repo
dotfiles unlink
```

## Tests

```bash
brew install bats-core
script/test                 # every supported bash
bats test                   # just this machine's bash
bats test/migrations.bats   # one file
```

`script/test` runs the suite once per bash on `PATH` *and* once under
`/bin/bash`, because the tool targets 3.2 and a bash-4-ism would otherwise pass
unnoticed on a machine with a modern bash. CI runs on macOS for the same
reason — a Linux runner has no 3.2 to test against.

The tests drive `bin/dotfiles` as a subprocess against throwaway config repos
in a temp directory, with `DOTFILES_REPOS`/`DOTFILES_STATE` pointed at them, so
nothing touches the machine's real dotfiles. `test/helper.bash` builds the
fixtures; `test/support/ptyrun.py` drives the interactive prompts on a real pty
(`script -q` will not do — it closes stdin, so the child reads EOF instead of
the keystroke).

## Anatomy of a config repo

```
dotfiles-work/
  dotfiles.conf           # describes this repo (sourced as bash)
  packages/               # stow packages: packages/bash/.bashrc -> ~/.bashrc
    bash/
    git/
  templates/              # 1Password templates, rendered on `dotfiles secrets`
    .gitconfig            # ... into ~/.gitconfig
  hooks/
    pre-install           # optional, executable
    post-install
  migrations/             # optional, markdown notes -- see below
    20260915-bash5-login-shell.md
```

### `dotfiles.conf`

Sourced as bash, so it can branch on `$HOST`, `$(uname)`, or anything else.

| variable | default | meaning |
| --- | --- | --- |
| `PACKAGES` | every dir under `packages/` | which packages to stow, in order |
| `TEMPLATES` | every file under `templates/` | which templates to render, relative to `templates/` |
| `DEPENDENCIES` | *(none)* | commands this config needs; installed with brew when missing |
| `OP_VAULT` | *(empty)* | exported to templates as `$OP_VAULT` |
| `OP_ACCOUNT` | *(empty)* | which 1Password account to resolve against |
| `PACKAGES_DIR` | `packages` | |
| `TEMPLATES_DIR` | `templates` | |
| `MIGRATIONS_DIR` | `migrations` | |
| `SECRETS_PACKAGE` | `private` | name of the generated package |
| `TARGET` | `$HOME` | where to link |

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

A missing dependency that will not install is a warning, not a fatal error —
the rest of the config still gets linked.

### Templates and secrets

Every file under `templates/` is rendered through `op inject` and the result is
written to `~/.local/share/dotfiles/<repo>/private/`, which is then stowed as a
normal package. Rendered files are `0600`; the directory is `0700`.

Set `TEMPLATES` to render only some of them — it takes paths relative to
`templates/` and, like `PACKAGES`, can be built up per host:

```bash
TEMPLATES=(.gitconfig)
case "$HOST" in
  work-laptop) ;;
  *) TEMPLATES+=(.s3cfg) ;;   # a secret that stays off the work machine
esac
```

Nothing is written into the config repo itself, so the repo stays clean and
there is no gitignored `private/` directory to accidentally commit.

Two variables are exported for templates to interpolate:

- `$hostname` — short hostname, for per-machine secrets
- `$OP_VAULT` — from `dotfiles.conf`, so one template works across vaults

```gitconfig
[user]
	signingKey = "op://$OP_VAULT/SSH Signing Keys/$hostname"
```

Set `OP_ACCOUNT` whenever more than one 1Password account is signed in on a
machine. A secret reference names a vault but not an account, so an unqualified
reference resolves against whichever account `op` treats as default — and
"Private" is an alias for the personal vault in *every* account, so a reference
meant for one account will happily go looking in another and fail, or worse,
find a same-named item.

Rendering is all-or-nothing. If any template fails — expired `op` session,
renamed item, typo'd reference — nothing is swapped into place and the
previously rendered files stay exactly as they were. This matters: stow
symlinks point into that directory, and a partial write would leave dangling
links across your home directory.

### Migrations

Some changes need a hand on each machine — a new login shell, a stale file to
delete, a `defaults write`. Write a markdown note for it:

```bash
dotfiles migrations new "switch the login shell to bash 5"
# -> migrations/20260915-switch-the-login-shell-to-bash-5.md, opened in $EDITOR
```

The slug is normalised, the date prefix keeps them in order, and the basename
is the id. `--repo <id>` picks the config repo when more than one is
configured; the default is the first. Nothing stops you creating the file by
hand — the helper only saves you typing the date.

```markdown
# Switch the login shell to Homebrew's bash

bash-completion needs 4.2+; stock /bin/bash is 3.2.

    echo /opt/homebrew/bin/bash | sudo tee -a /etc/shells
    chsh -s /opt/homebrew/bin/bash
```

`dotfiles update` prints the ones this machine has not acknowledged and offers
to mark them done. **Nothing is ever executed** — a migration is a note to you,
so it can say things no script could safely do on its own.

```bash
dotfiles migrations              # pending
dotfiles migrations --all        # the whole timeline, done ones included
dotfiles migrations new <slug>   # create one, --repo <id> to choose the repo
dotfiles migrations show         # the first one still pending
dotfiles migrations show <id>
dotfiles migrations show --all   # every pending one
dotfiles migrations done         # mark the first one still pending
dotfiles migrations done <id>
dotfiles migrations done --all   # mark every pending one
```

A migration you have just written counts as pending on your own machine too,
since the tool has no idea whether you did the steps before or after writing
them down. `migrations new` prints the `done` command for exactly that.

`--all` is the summary: everything in order, one line each, with the earliest
pending one marked `next` — the one `show` and `done` act on when given no id.

```
dotfiles-personal
  done  20260915-bash5-login-shell   Switch the login shell to bash 5  (2026-09-15)
  done  20261002-drop-s3cfg          Remove the old ~/.s3cfg           (2026-10-02)
  next  20261110-ripgrep-config      Point ripgrep at the new config file
  todo  20261201-tmux-3-4-bindings   Update the tmux bindings for 3.4
```

Order is always by id, so a migration done out of turn stays where it belongs
on the timeline rather than jumping to the top.

Acknowledgements live in `~/.local/share/dotfiles/<repo>/migrations.applied`,
one `id<TAB>timestamp` per line, per machine. It is plain text on purpose: did
the steps by hand? Append the id. Want a note back? Delete the line.

Being *shown* a migration never marks it done — only you do, which is the whole
point across several machines.

`dotfiles install` baselines instead: a new machine records every existing
migration as already applied without printing any of them, since a migration
describes a transition away from a state that machine never had. "New" means
no `installed` marker beside `migrations.applied` — deleting the
acknowledgements alone brings every note back rather than silently baselining
them away. Clearing the whole state directory does still look like a new
machine. Steps every
machine needs belong in the README or `hooks/post-install` — the login shell
above is genuinely both, so it goes in both places.

### Layering several repos

Stow runs with `--no-folding`, so directories are always real directories and
only leaf files are symlinked. Two repos can therefore both contribute files to
`~/.bash.d/` or `~/bin/` without colliding.

Single-file configs need an escape hatch instead. The usual one:

```gitconfig
# in the shared base repo's .gitconfig
[include]
	path = ~/.gitconfig.local
```

and let the private repo own `~/.gitconfig.local`.

## Later: a Homebrew tap

`Formula/dotfiles.rb` is ready to drop into a tap once the interface settles.
Until then a symlink onto `PATH` avoids having to tag a release for every
tweak.
