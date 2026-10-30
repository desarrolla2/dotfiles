# CLAUDE.md

## Purpose

Personal dotfiles for Daniel González (@desarrolla2), covering several Ubuntu
machines. Cloning this repository and running `./install.sh` should take a
freshly formatted machine to a working state without having to remember
anything.

## Working agreements

- **Everything in this repository is written in English.** Config, comments,
  documentation, commit messages.
- **Everything is kept short.** Explain a decision in one line where it is not
  obvious; drop the rest. Long rationales are what made this repository unusable
  to read.
- **The repository is public and other people use it.** Write for a stranger:
  no private hostnames, no email addresses, no credentials.
- **Recommend the current standard, not the historical one.** This started in
  2014 and accumulated dead tooling. Verify a tool's present state instead of
  recalling it, and say plainly when something should be dropped.
- Give a recommendation, not a list of options. Confirm before applying.

## Environment

Ubuntu 26.04, zsh + oh-my-zsh with a starship prompt, guake, PhpStorm via
JetBrains Toolbox, Docker for every project environment, Dropbox for sync,
Chrome, Claude Code.

`sudo` cannot authenticate non-interactively here. Use `pkexec`, which opens a
graphical dialog.

## Layout

One directory per tool: `apt/ bin/ claude/ docker/ docs/ git/ gnome/ guake/ ssh/ zsh/`,
plus `install.sh` and `INSTALL.md`. See README.md.

Files are symlinked, so editing the live config edits the repository. The one
exception is `docker/daemon.json`, copied to `/etc/docker/` because a root
process reads it and a symlink into `$HOME` would hand the daemon config to
anyone who can write this checkout.

## Machine-local, never committed

`~/.zshrc.local` for shell settings. The git identity lives in `~/.gitconfig`,
which includes `git/gitconfig` and adds the name, addresses and `includeIf`
blocks below it.
