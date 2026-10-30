#!/usr/bin/env bash
#
# Installer for this dotfiles repository. See INSTALL.md for the manual steps.
#
# Every step is idempotent: a second run changes nothing. Nothing is ever
# deleted; whatever is in the way of a symlink is moved to ~/.backup/.
#
#   ./install.sh                  every step, in order
#   ./install.sh --list-steps
#   ./install.sh --step ssh       one step, repeatable
#   ./install.sh --dry-run        print what would happen
#
set -euo pipefail

DOTFILES="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
BACKUP_DIR="$HOME/.backup"

# Order matters: later steps need packages installed by earlier ones.
STEPS=(packages zsh starship guake git ssh docker handlers gnome)

OMZ_DIR="$HOME/.oh-my-zsh"
OMZ_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
OMZ_PLUGINS=(zsh-autosuggestions zsh-syntax-highlighting)
LOGIN_SHELL="/usr/bin/zsh"

NERD_FONT_VERSION="v3.4.0"
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.zip"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"

DOCKER_KEYRING="/etc/apt/keyrings/docker.asc"
DOCKER_SOURCES="/etc/apt/sources.list.d/docker.sources"
DOCKER_PACKAGES=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
# Ubuntu's docker packages and the podman shim conflict with Docker's own.
DOCKER_CONFLICTS=(docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc)

DRY_RUN=0

# ok = already correct, do = changing something, skip/warn/fail = self-evident.
say()  { printf '       %s\n' "$*"; }
ok()   { printf '  ok   %s\n' "$*"; }
act()  { printf '  do   %s\n' "$*"; }
skip() { printf '  skip %s\n' "$*"; }
warn() { printf '  warn %s\n' "$*"; }
fail() { printf '  fail %s\n' "$*" >&2; }

# Plain commands only; anything with a pipe guards on $DRY_RUN itself.
run() {
  if ((DRY_RUN)); then printf '  dry  %s\n' "$*"; return 0; fi
  "$@"
}

# On these workstations sudo cannot authenticate non-interactively, so pkexec
# and its graphical prompt is the path that actually runs. Root first, for CI.
as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"
  elif sudo -n true 2>/dev/null; then sudo "$@"
  else pkexec "$@"
  fi
}

# False in CI, which has no D-Bus session, no login session to change and no
# reason to download 124 MB of font.
is_workstation() { [[ -z "${CI:-}" ]]; }

# The one symlink rule for the whole repository.
link() {
  local src="$1" dst="$2" rel backup

  [[ -e "$src" ]] || { fail "link source missing: $src"; return 1; }

  if [[ -L "$dst" ]] && [[ "$(readlink -f -- "$dst")" == "$(readlink -f -- "$src")" ]]; then
    ok "$dst -> $src"
    return 0
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    rel="${dst#"$HOME"/}"
    backup="$BACKUP_DIR/${rel#/}"
    if ((DRY_RUN)); then
      act "would move $dst to $backup, then link it"
      return 0
    fi
    mkdir -p -- "$(dirname -- "$backup")"
    [[ -e "$backup" ]] && backup="$backup.$(date +%Y%m%d%H%M%S)"
    mv -- "$dst" "$backup"
    act "moved $dst to $backup"
  fi

  if ((DRY_RUN)); then act "would link $dst -> $src"; return 0; fi
  mkdir -p -- "$(dirname -- "$dst")"
  ln -s -- "$src" "$dst"
  act "linked $dst -> $src"
}

installed() {
  [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true)" == "install ok installed" ]]
}

# One apt transaction, and no apt-get update unless something is missing.
apt_install() {
  local missing=() p
  for p in "$@"; do installed "$p" || missing+=("$p"); done
  if ((${#missing[@]} == 0)); then ok "already installed: $*"; return 0; fi
  act "apt install: ${missing[*]}"
  run as_root apt-get update
  run as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
}

# ------------------------------------------------------------------ packages --

step_packages() {
  local file="$DOTFILES/apt/packages.txt" list=()

  [[ -f "$file" ]] || { fail "$file not found"; return 1; }

  # Strip comments, then split on whitespace.
  mapfile -t list < <(sed 's/#.*//' "$file" | tr -s '[:space:]' '\n' | grep -v '^$' || true)
  ((${#list[@]})) || { warn "the package list is empty"; return 0; }

  say "${#list[@]} packages from apt/packages.txt"
  apt_install "${list[@]}"
}

# ----------------------------------------------------------------------- zsh --

step_zsh() {
  apt_install zsh fzf

  if [[ -d "$OMZ_DIR" ]]; then
    ok "oh-my-zsh present"
  elif ((DRY_RUN)); then
    act "would install oh-my-zsh (RUNZSH=no CHSH=no KEEP_ZSHRC=yes)"
  else
    # All three flags matter: this script owns the login shell and the zshrc.
    act "installing oh-my-zsh"
    local installer
    installer="$(mktemp)"
    curl -fsSL "$OMZ_URL" -o "$installer"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$installer"
    rm -f -- "$installer"
  fi

  # zshrc.sh only adds these to $plugins when present, so a failed clone
  # degrades instead of breaking every new terminal.
  local plugin dir
  for plugin in "${OMZ_PLUGINS[@]}"; do
    dir="$OMZ_DIR/custom/plugins/$plugin"
    if [[ -d "$dir" ]]; then
      ok "plugin $plugin"
    else
      act "cloning $plugin"
      run git clone --depth 1 "https://github.com/zsh-users/$plugin" "$dir"
    fi
  done

  link "$DOTFILES/zsh/zshrc.sh" "$HOME/.zshrc"

  local user current
  user="$(id -un)"
  current="$(getent passwd "$user" | cut -d: -f7)"
  if [[ "$current" == "$LOGIN_SHELL" ]]; then
    ok "login shell is $LOGIN_SHELL"
  elif ! is_workstation; then
    skip "login shell: no login session in CI"
  elif [[ ! -x "$LOGIN_SHELL" ]]; then
    warn "$LOGIN_SHELL not installed, login shell left as $current"
  else
    act "setting the login shell to $LOGIN_SHELL (was $current); affects new terminals"
    run as_root usermod -s "$LOGIN_SHELL" "$user"
  fi

  say "machine-local settings belong in ~/.zshrc.local"
}

# ------------------------------------------------------------------ starship --

step_starship() {
  apt_install starship unzip

  link "$DOTFILES/starship/starship.toml" "$HOME/.config/starship.toml"

  if compgen -G "$FONT_DIR/*.ttf" >/dev/null; then
    ok "JetBrainsMono Nerd Font installed"
    return 0
  fi
  if ! is_workstation; then
    skip "Nerd Font: 124 MB, and CI renders nothing"
    return 0
  fi
  if ((DRY_RUN)); then
    act "would install JetBrainsMono Nerd Font into $FONT_DIR"
    return 0
  fi

  # The default starship preset draws powerline separators and tool icons.
  act "downloading JetBrainsMono Nerd Font $NERD_FONT_VERSION (~124 MB)"
  local zip
  zip="$(mktemp --suffix=.zip)"
  curl -fL -o "$zip" "$NERD_FONT_URL"
  mkdir -p -- "$FONT_DIR"
  unzip -o -j "$zip" '*.ttf' -d "$FONT_DIR"
  rm -f -- "$zip"
  fc-cache -f
  act "font cache rebuilt"
}

# --------------------------------------------------------------------- guake --

step_guake() {
  apt_install guake

  local dump="$DOTFILES/guake/guake.dconf" expected current
  [[ -f "$dump" ]] || { warn "$dump not found"; return 0; }

  if ! is_workstation; then skip "guake dconf: no D-Bus session in CI"; return 0; fi
  command -v dconf >/dev/null || { warn "dconf not installed, cannot restore guake"; return 0; }

  # The dump stores __HOME__ so it works for any user.
  expected="$(sed "s|__HOME__|$HOME|g" "$dump")"
  current="$(dconf dump /org/guake/ 2>/dev/null || true)"

  if [[ "$current" == "$expected" ]]; then
    ok "guake configuration matches guake/guake.dconf"
  elif ((DRY_RUN)); then
    act "would load guake/guake.dconf (the live configuration differs)"
  else
    act "loading guake/guake.dconf"
    printf '%s\n' "$expected" | dconf load /org/guake/
    say "restart guake for this to take effect"
  fi

  local hotkey="$DOTFILES/guake/hotkey.dconf" media=/org/gnome/settings-daemon/plugins/media-keys/
  [[ -f "$hotkey" ]] || { warn "$hotkey not found"; return 0; }

  if [[ "$(dconf read "${media}custom-keybindings/guake/binding" 2>/dev/null)" == "'F12'" ]]; then
    ok "F12 opens guake through GNOME"
  elif ((DRY_RUN)); then
    act "would load guake/hotkey.dconf (F12 is not bound to guake)"
  else
    act "loading guake/hotkey.dconf"
    dconf load "$media" < "$hotkey"
  fi
}

# ----------------------------------------------------------------------- git --

step_git() {
  local gitconfig="$HOME/.gitconfig" target="$DOTFILES/git/gitconfig" shown name email

  [[ -f "$target" ]] || { fail "$target not found"; return 1; }

  shown="$target"
  [[ "$target" == "$HOME"/* ]] && shown="~/${target#"$HOME"/}"

  if [[ -f "$gitconfig" ]] && git config --file "$gitconfig" --get-all include.path 2>/dev/null |
    grep -qxF -e "$shown" -e "$target"; then
    ok "~/.gitconfig includes $shown"
  elif ((DRY_RUN)); then
    act "would add an [include] of $shown to ~/.gitconfig"
  elif [[ ! -f "$gitconfig" ]]; then
    printf '[include]\n\tpath = %s\n' "$shown" >"$gitconfig"
    act "created ~/.gitconfig with an [include] of $shown"
  else
    # The include goes first: git reads keys in order and the last wins, so
    # whatever is already there has to stay below it and keep overriding.
    local tmp backup="$BACKUP_DIR/.gitconfig"
    mkdir -p -- "$BACKUP_DIR"
    [[ -e "$backup" ]] && backup="$backup.$(date +%Y%m%d%H%M%S)"
    cp -p -- "$gitconfig" "$backup"
    tmp="$(mktemp)"
    printf '[include]\n\tpath = %s\n\n' "$shown" >"$tmp"
    cat -- "$gitconfig" >>"$tmp"
    cat -- "$tmp" >"$gitconfig"
    rm -f -- "$tmp"
    act "prepended the [include] to ~/.gitconfig (backup in $backup)"
  fi

  # Never written by this script: the identity is per machine and this
  # repository is public. See INSTALL.md step 5.
  name="$(git config --global user.name 2>/dev/null || true)"
  email="$(git config --global user.email 2>/dev/null || true)"
  if [[ -n "$name" && -n "$email" ]]; then
    ok "git identity resolves to $name <$email>"
  else
    warn "git identity not set, this is a manual step (INSTALL.md step 5)"
  fi
}

# ----------------------------------------------------------------------- ssh --

step_ssh() {
  local config="$DOTFILES/ssh/config" mode

  [[ -f "$config" ]] || { fail "$config not found"; return 1; }

  # Mandatory: ssh refuses a group-writable config with "Bad owner or
  # permissions", and every fresh clone arrives 664.
  mode="$(stat -c '%a' "$config")"
  if [[ "$mode" == "600" ]]; then
    ok "ssh/config is mode 600"
  else
    act "chmod 600 ssh/config (was $mode)"
    run chmod 600 "$config"
  fi

  if [[ -d "$HOME/.ssh" ]]; then
    ok "~/.ssh exists"
  else
    act "creating ~/.ssh mode 700"
    if ! ((DRY_RUN)); then
      mkdir -p -- "$HOME/.ssh"
      chmod 700 -- "$HOME/.ssh"
    fi
  fi

  link "$config" "$HOME/.ssh/config"

  # Key generation needs a passphrase prompt, and the public key has to be
  # registered on GitHub by hand.
  if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
    ok "~/.ssh/id_ed25519 present"
  else
    warn "~/.ssh/id_ed25519 missing, this is a manual step (INSTALL.md step 1)"
  fi
}

# -------------------------------------------------------------------- docker --

step_docker() {
  local conflicts=() p codename arch expected repo_added=0 user
  local src="$DOTFILES/docker/daemon.json" dst="/etc/docker/daemon.json"

  for p in "${DOCKER_CONFLICTS[@]}"; do
    installed "$p" && conflicts+=("$p")
  done
  if ((${#conflicts[@]} == 0)); then
    ok "no conflicting docker packages"
  else
    act "removing: ${conflicts[*]}"
    run as_root env DEBIAN_FRONTEND=noninteractive apt-get remove -y "${conflicts[@]}"
  fi

  # Docker's own repository, not Ubuntu's docker.io: that one lags badly and
  # ships no Compose v2 plugin.
  apt_install ca-certificates curl

  if [[ -s "$DOCKER_KEYRING" ]]; then
    ok "docker apt key present"
  else
    act "adding the docker apt signing key"
    run as_root install -m 0755 -d /etc/apt/keyrings
    run as_root curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$DOCKER_KEYRING"
    run as_root chmod a+r "$DOCKER_KEYRING"
    repo_added=1
  fi

  codename="$(. /etc/os-release && printf '%s' "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
  arch="$(dpkg --print-architecture)"
  expected="Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $codename
Components: stable
Architectures: $arch
Signed-By: $DOCKER_KEYRING"

  if [[ -f "$DOCKER_SOURCES" ]] && [[ "$(cat "$DOCKER_SOURCES")" == "$expected" ]]; then
    ok "$DOCKER_SOURCES up to date (suite $codename, arch $arch)"
  elif ((DRY_RUN)); then
    act "would write $DOCKER_SOURCES (suite $codename, arch $arch)"
  else
    act "writing $DOCKER_SOURCES (suite $codename, arch $arch)"
    local tmp
    tmp="$(mktemp)"
    printf '%s\n' "$expected" >"$tmp"
    as_root install -o root -g root -m 644 "$tmp" "$DOCKER_SOURCES"
    rm -f -- "$tmp"
    repo_added=1
  fi

  ((repo_added)) && run as_root apt-get update
  apt_install "${DOCKER_PACKAGES[@]}"

  # The docker group is equivalent to root on the host: the daemon runs as root
  # and bind-mounts anything for whoever reaches its socket. Needed either way.
  user="$(id -un)"
  if ! getent group docker >/dev/null 2>&1; then
    warn "no docker group, skipping the membership"
  elif getent group docker | cut -d: -f4 | tr ',' '\n' | grep -qxF "$user"; then
    ok "$user is in the docker group"
    id -nG "$user" | tr ' ' '\n' | grep -qxF docker ||
      warn "not active in this session yet: log out and back in, or use 'newgrp docker'"
  else
    act "adding $user to the docker group"
    run as_root usermod -aG docker "$user"
    warn "log out and back in: group membership is resolved at login"
  fi

  # Copied, not symlinked: a root process reads it, and a symlink into $HOME
  # would hand the daemon config to anyone who can write this repository.
  [[ -f "$src" ]] || { warn "$src not found, leaving $dst alone"; return 0; }

  # A malformed daemon.json stops docker from starting at all.
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$src" 2>/dev/null ||
      { fail "$src is not valid JSON, refusing to install it"; return 1; }
    ok "docker/daemon.json parses"
  fi

  if [[ -r "$dst" ]] && cmp -s "$src" "$dst"; then
    ok "$dst matches, daemon not restarted"
    return 0
  fi
  if ((DRY_RUN)); then
    act "would install docker/daemon.json to $dst and restart docker"
    return 0
  fi

  act "installing docker/daemon.json to $dst as root:root 644"
  as_root install -o root -g root -m 644 "$src" "$dst"

  # Only restarted because the file changed.
  if [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null 2>&1; then
    act "restarting the docker daemon"
    as_root systemctl restart docker
  else
    skip "docker restart: no systemd here"
  fi
  say "log limits apply to new containers; recreate existing ones with"
  say "'docker compose up -d --force-recreate'"
}

# ------------------------------------------------------------------ handlers --

# Registers bin/phpstorm-url-handler for phpstorm:// and pstorm:// links, so a
# file:line in a stack trace or an Xdebug error page opens at that line.
step_handlers() {
  local handler="$DOTFILES/bin/phpstorm-url-handler"
  local apps="$HOME/.local/share/applications"
  local desktop="$apps/phpstorm-url-handler.desktop"
  local scheme expected current

  [[ -f "$handler" ]] || { warn "$handler not found, nothing to register"; return 0; }

  if [[ ! -x "$handler" ]]; then
    act "chmod +x bin/phpstorm-url-handler"
    run chmod +x "$handler"
  fi

  for scheme in xdg-mime update-desktop-database; do
    command -v "$scheme" >/dev/null ||
      { warn "$scheme not installed, cannot register the URL handler"; return 0; }
  done

  # Generated rather than tracked: Exec has to be an absolute path, because the
  # desktop session's PATH has neither ~/.local/bin nor the Toolbox scripts
  # directory, and a desktop file expands neither ~ nor $HOME.
  expected="[Desktop Entry]
Version=1.0
Type=Application
Name=PhpStorm URL Handler
Comment=Handle phpstorm://open?url=file://@file&line=@line
Icon=phpstorm
NoDisplay=true
Categories=TextEditor;Utility;
Terminal=false
MimeType=x-scheme-handler/phpstorm;x-scheme-handler/pstorm;
Exec=$handler %u"

  current="$(cat "$desktop" 2>/dev/null || true)"
  if [[ "$current" == "$expected" ]]; then
    ok "$desktop up to date"
  elif ((DRY_RUN)); then
    act "would write $desktop"
  else
    mkdir -p -- "$apps"
    printf '%s\n' "$expected" >"$desktop"
    act "wrote $desktop"
    run update-desktop-database "$apps"
  fi

  for scheme in phpstorm pstorm; do
    if [[ "$(xdg-mime query default "x-scheme-handler/$scheme" 2>/dev/null)" == "phpstorm-url-handler.desktop" ]]; then
      ok "$scheme:// handled by phpstorm-url-handler"
    else
      act "registering $scheme:// "
      run xdg-mime default phpstorm-url-handler.desktop "x-scheme-handler/$scheme"
    fi
  done
}

# --------------------------------------------------------------------- gnome --

# Links the window-thirds extension and enables it. GNOME Shell reads a new
# extension only when it starts, so it works from the next login.
step_gnome() {
  local uuid="window-thirds@desarrolla2"
  local src="$DOTFILES/gnome/$uuid"
  local schema="$src/schemas/org.gnome.shell.extensions.window-thirds.gschema.xml"
  local enabled

  link "$src" "$HOME/.local/share/gnome-shell/extensions/$uuid"

  if ! is_workstation; then skip "gnome extension: no GNOME session in CI"; return 0; fi
  command -v glib-compile-schemas >/dev/null ||
    { warn "glib-compile-schemas not installed, cannot build the extension's settings"; return 0; }

  if [[ "$src/schemas/gschemas.compiled" -nt "$schema" ]]; then
    ok "window-thirds settings compiled"
  else
    act "compiling the window-thirds settings"
    run glib-compile-schemas "$src/schemas"
  fi

  if [[ "$(gsettings get org.gnome.shell disable-user-extensions 2>/dev/null)" == "true" ]]; then
    warn "GNOME has user extensions turned off: gsettings set org.gnome.shell disable-user-extensions false"
  fi

  enabled="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || true)"
  if [[ "$enabled" == *"'$uuid'"* ]]; then
    ok "$uuid enabled"
  elif ((DRY_RUN)); then
    act "would enable $uuid"
  else
    if [[ -z "$enabled" || "$enabled" == "@as []" ]]; then enabled="['$uuid']"
    else enabled="${enabled%]}, '$uuid']"; fi
    gsettings set org.gnome.shell enabled-extensions "$enabled"
    act "enabled $uuid; log out and back in to load it"
  fi
}

# ---------------------------------------------------------------------- main --

usage() {
  cat <<EOF
Installer for this dotfiles repository. See INSTALL.md for the manual steps.

  ./install.sh                          every step, in order
  ./install.sh --list-steps
  ./install.sh --step NAME [--step ...]  only these, in the order given
  ./install.sh --dry-run                print what would happen
  ./install.sh -h

Steps: ${STEPS[*]}
EOF
}

main() {
  local steps=() name rc statuses=() failed=0

  while (($#)); do
    case "$1" in
      -h | --help) usage; return 0 ;;
      --list-steps) printf '%s\n' "${STEPS[@]}"; return 0 ;;
      --dry-run) DRY_RUN=1; shift ;;
      --step)
        [[ -n "${2:-}" ]] || { fail "--step needs a name"; return 2; }
        printf '%s\n' "${STEPS[@]}" | grep -qxF "$2" ||
          { fail "unknown step: $2 (valid: ${STEPS[*]})"; return 2; }
        steps+=("$2"); shift 2 ;;
      *) fail "unknown argument: $1"; usage >&2; return 2 ;;
    esac
  done

  ((${#steps[@]})) || steps=("${STEPS[@]}")

  printf 'dotfiles installer\n'
  printf '  repository  %s\n' "$DOTFILES"
  printf '  user        %s (uid %s)\n' "$(id -un)" "$(id -u)"
  printf '  mode        %s\n' "$( ((DRY_RUN)) && echo 'dry run' || echo apply)"
  printf '  environment %s\n' "$(is_workstation && echo workstation || echo CI)"
  printf '  steps       %s\n' "${steps[*]}"

  for name in "${steps[@]}"; do
    printf '\n== %s\n' "$name"
    # Never called from an if or a &&: bash disables errexit inside those, which
    # would let a step carry on after a failed command.
    set +e
    ( set -e; "step_$name" )
    rc=$?
    set -e
    if ((rc == 0)); then
      statuses+=("$name ok")
    else
      statuses+=("$name FAILED")
      failed=1
      fail "step $name failed with status $rc"
    fi
  done

  printf '\n== summary\n'
  printf '  %s\n' "${statuses[@]}"
  ((failed)) && { printf '\nfinished with failures\n' >&2; return 1; }
  printf '\nfinished\n'
}

main "$@"
