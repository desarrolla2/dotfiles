# dotfiles

My Ubuntu configuration: zsh, starship, guake, git, ssh, docker and Claude Code.
Clone it on a freshly formatted machine, run the installer, and the machine is
back to work.

Public since 2014. Take what you find useful.

## Install

```sh
git clone https://github.com/desarrolla2/dotfiles.git ~/Projects/devtia/dotfiles
cd ~/Projects/devtia/dotfiles
./install.sh --dry-run    # shows what it would do, changes nothing
./install.sh
./bin/doctor              # checks the result
```

Steps run in this order and each one is idempotent:

```
packages  zsh  starship  guake  git  ssh  docker  claude  handlers
```

Run one on its own with `./install.sh --step docker`. Nothing is ever deleted:
whatever is in the way of a symlink is moved to `~/.backup/`.

[INSTALL.md](INSTALL.md) covers the parts a script cannot do — the ssh key, the
git identity, and the four apps that end in an account login.

## What is here

| Path | |
|---|---|
| `apt/packages.txt` | every apt package, with the reason for each |
| `bin/doctor` | checks the machine matches the docs |
| `bin/phpstorm-url-handler` | opens `phpstorm://file&line` links at that line |
| `claude/` | Claude Code global config |
| `docker/` | daemon config: log rotation, live-restore |
| `docs/manual.md` | Dropbox, Chrome, JetBrains Toolbox, Claude Code |
| `git/` | shared git config and global gitignore |
| `guake/` | guake settings, as a dconf dump |
| `ssh/` | ssh client config |
| `starship/` | prompt config: the default preset, no language modules |
| `zsh/zshrc.sh` | the zshrc |
| `install.sh` | the installer |

Files are symlinked, so editing the live config edits the repository. The one
exception is `docker/daemon.json`, copied to `/etc/docker/` because a root
process reads it.

## If you fork this

- `git/gitconfig` points `core.excludesFile` at
  `~/Projects/devtia/dotfiles/git/gitignore`. Clone elsewhere and you have to fix
  that line.
- `guake/guake.dconf` and `zsh/zshrc.sh` expect PhpStorm from JetBrains Toolbox.
- Everything machine-specific goes in `~/.zshrc.local`, sourced last.

## Not managed here, on purpose

PhpStorm settings and Chrome (they sync through their own accounts), the git
identity and any address (this repository is public), and PHP and Composer
versions (per project, in Docker).

## Licence

MIT. See [LICENSE](LICENSE).
