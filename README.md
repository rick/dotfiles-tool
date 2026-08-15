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

`doctor --install` installs only what the engine itself needs. Anything else a
machine wants (a Brewfile, mise, whatever) belongs in a config repo's
`hooks/post-install`, not here.

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
dotfiles status           # what is configured, what is actually linked
dotfiles link --adopt     # pull pre-existing files into the config repo
dotfiles unlink
```

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
```

### `dotfiles.conf`

Sourced as bash, so it can branch on `$HOST`, `$(uname)`, or anything else.

| variable | default | meaning |
| --- | --- | --- |
| `PACKAGES` | every dir under `packages/` | which packages to stow, in order |
| `OP_VAULT` | *(empty)* | exported to templates as `$OP_VAULT` |
| `PACKAGES_DIR` | `packages` | |
| `TEMPLATES_DIR` | `templates` | |
| `SECRETS_PACKAGE` | `private` | name of the generated package |
| `TARGET` | `$HOME` | where to link |

```bash
OP_VAULT="Work"
PACKAGES=(bash git tmux vim)

case "$HOST" in
  some-laptop) PACKAGES+=(docker) ;;
esac
```

### Templates and secrets

Every file under `templates/` is rendered through `op inject` and the result is
written to `~/.local/share/dotfiles/<repo>/private/`, which is then stowed as a
normal package. Rendered files are `0600`; the directory is `0700`.

Nothing is written into the config repo itself, so the repo stays clean and
there is no gitignored `private/` directory to accidentally commit.

Two variables are exported for templates to interpolate:

- `$hostname` — short hostname, for per-machine secrets
- `$OP_VAULT` — from `dotfiles.conf`, so one template works across vaults

```gitconfig
[user]
	signingKey = "op://$OP_VAULT/SSH Signing Keys/$hostname"
```

Rendering is all-or-nothing. If any template fails — expired `op` session,
renamed item, typo'd reference — nothing is swapped into place and the
previously rendered files stay exactly as they were. This matters: stow
symlinks point into that directory, and a partial write would leave dangling
links across your home directory.

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
