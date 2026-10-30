# Installation

Fresh Ubuntu machine, in order. Every step is idempotent.

Before wiping the old machine, rescue what this repository deliberately cannot
rebuild: unpushed work, `~/.zshrc.local`, the git identity files, the ssh keys,
the guake dconf dump (it exists only in dconf until someone exports it), and a
finished Dropbox sync.

`install.sh` is the source of truth for every automated command. This document
only covers what a script cannot do.

```sh
./install.sh                  # every step, in order
./install.sh --list-steps
./install.sh --step <name>
./install.sh --dry-run        # changes nothing
```

Commands below are written with `sudo`. From a non-interactive session (Claude
Code) `sudo` cannot prompt, so use `pkexec` instead. `install.sh` already tries
root, then `sudo -n`, then `pkexec`.

---

## 1. ssh key

First, because the clone is over SSH. Needs a real terminal for the passphrase
prompt.

```sh
ssh-keygen -t ed25519 -C "you@example.com"      # accept ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub                        # paste at github.com/settings/keys
```

Restoring an old key instead? ssh refuses a private key others can read:

```sh
chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_ed25519
```

## 2. Clone

```sh
mkdir -p ~/Projects/devtia
git clone git@github.com:desarrolla2/dotfiles.git ~/Projects/devtia/dotfiles
cd ~/Projects/devtia/dotfiles
```

The path matters: `git/gitconfig` points `core.excludesFile` at
`~/Projects/devtia/dotfiles/git/gitignore`. Cloning elsewhere means fixing that
line.

## 3. Base packages

```sh
./install.sh --step packages
```

Reads `apt/packages.txt`, one package per line with the reason for each. Do not
add `apt install` lines anywhere else; a package with no candidate is rot and
should be removed rather than carried forward.

## 4. zsh, starship, guake

```sh
./install.sh --step zsh --step starship --step guake
```

- **zsh**: installs oh-my-zsh unattended (`RUNZSH=no CHSH=no KEEP_ZSHRC=yes`),
  clones `zsh-autosuggestions` and `zsh-syntax-highlighting`, links
  `zsh/zshrc.sh` to `~/.zshrc`, sets `/usr/bin/zsh` as login shell. Takes effect
  in new terminals only.
- **starship**: links `starship/starship.toml` to `~/.config/starship.toml`, the
  default preset with the language modules turned off. Also installs
  JetBrainsMono Nerd Font (~124 MB) for the powerline glyphs.
- **guake**: loads `guake/guake.dconf`, with `__HOME__` replaced by the real home
  directory. **Restart guake afterwards.**

Machine-specific settings go in `~/.zshrc.local`, sourced last, never committed.

To save guake changes back into the repository:

```sh
dconf dump /org/guake/ | sed "s|$HOME|__HOME__|g" > guake/guake.dconf
```

## 5. git

```sh
./install.sh --step git
```

`~/.gitconfig` *includes* `git/gitconfig` rather than being a symlink to it,
because `git config --global` writes to `~/.gitconfig` and those writes must not
land in a public repository. The include goes first: git reads keys in order and
the last one wins, so anything below it overrides the defaults.

### The identity, which stays manual

Never versioned, and `install.sh` refuses to write it. GitHub attributes commits
by email address, so a wrong address means the commit does not count as yours.
`includeIf` resolves it from the directory instead of leaving it to be chosen by
hand, repository by repository.

```sh
cat >> ~/.gitconfig <<'EOF'

[user]
	name = Your Name
	email = you@personal.example

[includeIf "gitdir:~/Projects/clientA/"]
	path = ~/.gitconfig-clientA
EOF

printf '[user]\n\temail = you@clienta.example\n' > ~/.gitconfig-clientA
```

The trailing slash in `gitdir:` is required — it is what makes the pattern match
a whole tree. `./bin/doctor` proves each include still fires by resolving the
address against a real repository under that directory.

## 6. ssh config

```sh
./install.sh --step ssh
chmod 600 ssh/config        # what the step does; mandatory, not cosmetic
ssh -T git@github.com       # expects "Hi <user>! You've successfully authenticated"
```

ssh rejects a group- or world-writable config with `Bad owner or permissions`.
Repository files arrive 664 and git does not track that mode, so every fresh
clone needs the `chmod` again.

## 7. docker

```sh
./install.sh --step docker
```

Removes the conflicting packages, adds Docker's own apt repository (Ubuntu's
`docker.io` lags and has no Compose v2), installs the engine and plugins, adds
you to the `docker` group, and copies `docker/daemon.json` to `/etc/docker/`.

**Log out and back in.** Group membership is resolved at login, so every open
shell keeps the old list and `docker ps` fails with `permission denied`.
`newgrp docker` patches one shell meanwhile.

Two things worth knowing: the `docker` group is equivalent to root on the host,
and `daemon.json` is **copied**, not symlinked, because a root process reads it.
Its log limits apply to containers created afterwards, so recreate existing ones
with `docker compose up -d --force-recreate`.

## 8. The four manual apps

See [docs/manual.md](docs/manual.md) for each procedure. Order matters:

1. **Dropbox** — first, its sync takes hours and everything else waits on it. The
   folder must be at `~/Documents/Dropbox`, which can only be set in the setup
   wizard.
2. **Chrome** — before JetBrains, because the next two logins open a browser.
3. **JetBrains Toolbox**, then PhpStorm from it. `zsh/zshrc.sh` and
   `guake/guake.dconf` both reference the launcher path it creates.
4. **Claude Code** — last. Its configuration is not in this repository: it
   arrives through Dropbox (step 11). Never copy `~/.claude/.credentials.json`
   between machines: it is a live OAuth token.

## 9. phpstorm:// links

```sh
./install.sh --step handlers
```

Registers `bin/phpstorm-url-handler` for `phpstorm://` and `pstorm://`, so a
file and line in a stack trace, an Xdebug error page or a CI log opens at that
line. Needs PhpStorm installed first (step 8), because the handler calls the
launcher Toolbox creates.

Test it:

```sh
gio open "phpstorm://open?url=file://$PWD/install.sh&line=35"
```

Not upstream's `sanduhrs/phpstorm-url-handler`, which cannot work with a current
PhpStorm: it runs `phpstorm --line N file`, and the launcher rejects `--line`
unless a project directory comes first. The handler here finds that directory by
walking up for `.idea`, then a git root. Upstream also finishes with `wmctrl`,
which does nothing under Wayland.

A URL handler that fails does so silently, so this one logs every call to
`~/.cache/phpstorm-url-handler.log` and raises a desktop notification on error.
Check that file first when a click does nothing.

## 10. Window shortcuts

```sh
./install.sh --step gnome
```

Links `gnome/window-thirds@desarrolla2` into GNOME Shell's extensions and
enables it. **Log out and back in afterwards**: the shell reads a new extension
only when it starts.

| Keys | Focused window |
|---|---|
| Super+Ctrl+← | two thirds on the left; pressed again, one third, and back |
| Super+Ctrl+→ | the same on the right |
| Super+Ctrl+↑ | maximized; pressed again, back to where it was |
| Super+Ctrl+↓ | two thirds, centred; pressed again, one third, and back |

Super+← and Super+→ stay GNOME's own halves. An extension rather than a
`wmctrl` script because Wayland lets no other process move a window.

Check it:

```sh
gnome-extensions info window-thirds@desarrolla2    # State: ACTIVE
```

## 11. Shared Dropbox symlinks

Per-project Claude config and notes are shared through Dropbox by the Dropbox
`claude` project, which owns its own manifest. Not this repository's job. Needs
Dropbox to report `Up to date` and the project repositories to be cloned:

```sh
sudo apt install make
make symlink-simular    # dry run
make symlink
```

## 12. Verify

```sh
./bin/doctor
```

One line per check, the fix next to each failure, non-zero exit when a hard check
fails. A `WARN` is not a failure — a missing `~/.zshrc.local` and a `docker`
group not yet active in this session are both expected on a fresh machine.

Three checks stay manual because doctor cannot make them: the package list
(step 3), `ssh -T git@github.com` (step 6), and `make symlink-simular` (step 11).
