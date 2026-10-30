# Manual applications

Four applications on these machines are not in `apt/packages.txt` and are not
touched by `install.sh`. They are not missing by oversight, and they are not a
to-do list: each one has a hard reason why the last mile cannot be scripted.

- **Dropbox** ships a tiny apt package that only contains the CLI and the
  Nautilus extension. The actual sync daemon is a proprietary blob the package
  downloads into your home directory on first run, and choosing the account and
  the folder location happens in a GUI wizard.
- **Google Chrome** and **Dropbox** both live in vendor apt repositories, not in
  Ubuntu's archive. `apt/packages.txt` is a plain list of names resolved against
  the configured sources, so a package that needs its own source and its own
  signing key registered first does not belong in it.
- **JetBrains Toolbox** is a tarball into `~/.local/share`, and PhpStorm is
  installed *by* Toolbox, after a JetBrains account login.
- **Claude Code** has an official apt repository now, but this machine uses the
  native installer on purpose (see section 4), and authentication is an
  interactive browser flow either way.

What all four share: the install is trivial, the **account sign-in is the
step that matters**, and the account sign-in is what carries the real
configuration — bookmarks, IDE settings, the synced note tree. That is why
there is no `chrome/` or `phpstorm/` directory in this repository. Do not
"helpfully" move these into `install.sh`. You would automate the easy 10% and
leave the machine looking installed while nothing is actually signed in.

Everything below was verified against the desktop machine on 2026-08-01,
running Ubuntu 26.04 LTS (`resolute`). Where the vendor's current published
instructions differ from what is actually installed here, the difference is
called out rather than smoothed over.

Do the four in the order given. The ordering is not cosmetic:

1. **Dropbox first**, because it is the only one the others do not need and the
   only one everything else needs. The synced note tree, the shared project
   folders and the personal vault all live inside it, and its first sync takes
   hours. Starting it first means it syncs in the background while you do the
   rest, instead of you waiting on it at the end.
2. **Chrome second**, because steps 3 and 4 both end in a browser: JetBrains
   and Anthropic both authenticate by opening a URL. Doing Chrome next means
   those logins land in the browser you actually use, already signed in to the
   Google account, instead of in Firefox where the saved passwords are not.
3. **JetBrains Toolbox / PhpStorm third**, because it needs a browser and
   because `zsh/zshrc.sh` and `guake/guake.dconf` both reference paths it
   creates. Install it before you judge whether those configs are working.
4. **Claude Code last**, because its configuration arrives through Dropbox, so
   the sync has to be done first, and it is the most useful thing to have
   working when something in the earlier steps needs fixing.

---

## 1. Dropbox

### What it is for here

The sync spine between the desktop and the laptop. Everything personal that is
deliberately not in this public repository lives inside it: the note tree, the
`Desarrolla2` and `Shared` project folders, and the encrypted personal vault.
Repository files reference it as the source of things that are symlinked into
place, and `git/gitignore` has entries specifically for the note folders it
syncs and for the Claude Code project configuration it carries. Creating those
symlinks is not this repository's job: the Dropbox `claude` project owns it,
through `make symlink` and its own manifest at
`herramientas/compartido/enlaces.conf`. Every entry there resolves under the
Dropbox folder, so the path below has to be right and the sync has to have
reached that path before it can do anything useful.

### The non-default folder location

On this machine the Dropbox folder is:

```
$HOME/Documents/Dropbox
```

**Not** `~/Dropbox`. A fresh install defaults to `~/Dropbox` and never asks
twice. If you accept the default, every symlink that points into
`~/Documents/Dropbox` will point at nothing, and the failure is quiet: the
symlink exists, it just resolves to a missing target. This is the single
easiest thing to get wrong in the entire rebuild.

The location is chosen in the setup wizard on first run, under *Advanced
settings* / *Change* on the folder-selection screen. Set it there. Moving the
folder afterwards means a full re-download.

Dropbox records the choice in `~/.dropbox/info.json`, which on this machine
reads:

```json
{"personal": {"path": "$HOME/Documents/Dropbox", "host": ..., "is_team": false, "subscription_type": "Pro"}}
```

That file is the authoritative answer to "did I get the path right".

### How it is actually installed here

Verified: apt package `dropbox`, version `2026.05.06`, amd64, described as
"cloud synchronization engine - CLI and Nautilus extension". It provides
`/usr/bin/dropbox` and a Nautilus extension, and nothing else — the package is
82 KB.

The apt source and key on disk are:

- `/etc/apt/sources.list.d/dropbox.list` →
  `deb [arch=i386,amd64 signed-by=/etc/apt/keyrings/dropbox.asc] http://linux.dropbox.com/ubuntu resolute main`
- `/etc/apt/keyrings/dropbox.asc`

Neither file belongs to any package (`dpkg -S` finds no owner). They are
written by the `dropbox` package's own `postinst`, which builds that exact
`deb` line and drops the key inline. So: you install a downloaded `.deb` once,
and from then on apt keeps the package updated from Dropbox's repository. On
this machine the `.deb` was installed through PackageKit — apt history records
`Commandline: packagekit role='install-files'` — i.e. it was downloaded in a
browser and opened, not fetched by a command.

The sync daemon is separate and is **not** in the package. It is a proprietary
binary downloaded per-user on first run into `~/.dropbox-dist`, which here
contains `dropbox-lnx.x86_64-262.4.3183`. This is the part that cannot be
packaged and the reason Dropbox is in this document at all.

### Install

Download and install the Ubuntu `.deb`. The `dl=` URL redirects to the real
file on `linux.dropbox.com`, so it can be fetched non-interactively:

```sh
curl -fsSL -o /tmp/dropbox.deb \
  "https://www.dropbox.com/download?dl=packages/ubuntu/dropbox_2026.05.06_amd64.deb"
sudo apt install /tmp/dropbox.deb
```

Pin a version only if you have a reason to. To get whatever is current, use
the download page at <https://www.dropbox.com/install-linux> and take the
"Ubuntu 64-bit" `.deb`.

Then fetch the daemon and start the wizard:

```sh
dropbox start -i
```

`-i` is what downloads `~/.dropbox-dist` if it is not there yet. Autostart is
already handled: the package installs `~/.config/autostart/dropbox.desktop`
with `Exec=dropbox start -i`, so it comes back on every login without anything
from this repository.

### Interactive steps that cannot be scripted

1. Accept the daemon download prompt.
2. Sign in to the Dropbox account in the browser window it opens.
3. **On the folder screen, change the location to `~/Documents/Dropbox`.** Not
   the default.
4. Choose selective sync if you do not want the whole account on this machine.
5. **Wait.** A full account is hours, not minutes. On this machine `dropbox
   status` reported `Downloading 3 files (2,093 KB/sec, 1 hour)` well into the
   session. Any later step that reads a file under Dropbox — the note folders,
   the vault, anything symlinked out of it — must wait until this reads `Up to
   date`. Do not start those steps on a partial tree; you will get dangling
   symlinks and conclude something is broken when it is only unfinished.

### Check it

```sh
# expects: Up to date
dropbox status

# expects {"personal": {"path": "$HOME/Documents/Dropbox", ...
cat ~/.dropbox/info.json

# expects "ok": the folder is at the non-default path and ~/Dropbox does not exist
test -d ~/Documents/Dropbox && ! test -e ~/Dropbox && echo ok
```

---

## 2. Google Chrome

### What it is for here

The browser, and the account that carries its configuration. Bookmarks,
extensions, passwords and history all come back by signing in to the Google
account and letting sync run. **Nothing about Chrome belongs in this
repository** — there is no `chrome/` directory and there should not be one.
Anything you committed here would be a stale copy of what the account already
holds, and passwords have no business in a public repository.

It is second in the order because the two steps after it finish in a browser.

### How it is actually installed here

Verified: apt package `google-chrome-stable`, version `151.0.7922.71-1`,
amd64. `google-chrome --version` reports `Google Chrome 151.0.7922.71`. Both
`/usr/bin/google-chrome` and `/usr/bin/google-chrome-stable` exist.

The apt source and key on disk are:

- `/etc/apt/sources.list.d/google-chrome.sources`, deb822 format:

  ```
  ### THIS FILE IS AUTOMATICALLY CONFIGURED ###
  X-Repolib-Name: Google Chrome
  Types: deb
  URIs: https://dl.google.com/linux/chrome-stable/deb/
  Suites: stable
  Components: main
  Architectures: amd64
  Signed-By: /usr/share/keyrings/google-chrome.gpg
  ```

- `/usr/share/keyrings/google-chrome.gpg`

`apt-cache policy google-chrome-stable` confirms the installed version is
served from `https://dl.google.com/linux/chrome-stable/deb stable/main`, so
updates arrive through normal `apt upgrade`. There is also
`/etc/cron.daily/google-chrome`, installed by the package, which re-adds the
repository if it goes missing.

**Where reality differs from the obvious reading.** It is tempting to describe
this as "the repository was added, then the package installed from it". It was
not. Like Dropbox, apt history records `Commandline: packagekit
role='install-files'` — a `.deb` downloaded in a browser and opened. Neither
the `.sources` file nor the keyring is owned by any package; both are generated
by the Chrome `postinst`, which contains the deb822 template verbatim,
including the `X-Repolib-Name` line and the `chrome-stable` URI. The one-off
`.deb` *is* the mechanism that registers the repository. So the distinction
between "one-off `.deb`" and "repository install" does not exist for Chrome —
the first produces the second.

Two details worth knowing, since the same `postinst` is where they live: the
literal string `deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable
main` also appears in it, as `REPOCONFIG`, used only to find and comment out
legacy `.list` entries from older installs. The current repository path is
`chrome-stable`, not `chrome`. Do not copy the legacy line out of an old blog
post.

### Install

```sh
curl -fsSL -o /tmp/google-chrome.deb \
  "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
sudo apt install /tmp/google-chrome.deb
```

That is the method that matches this machine, and it self-registers the
repository. If you would rather register the repository first and install by
name — the same end state, reached explicitly, and the form to use if this ever
does move into an automated step:

```sh
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
  | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome-stable/deb/ stable main" \
  | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update && sudo apt install -y google-chrome-stable
```

Note that this leaves a `.list` file where this machine has a `.sources` file,
and the `postinst` may then comment your line out and write its own. Prefer the
`.deb`.

### Interactive steps that cannot be scripted

1. Launch Chrome, sign in to the Google account.
2. Turn on sync and wait for bookmarks, extensions and passwords to come back.
3. Re-enter any per-extension login the extension keeps outside Chrome sync.
4. Make it the default browser if the desktop did not already ask.

### Check it

```sh
# expects: Google Chrome 151.0.7922.71 (or newer)
google-chrome --version

# expects the installed version to come from dl.google.com, not a local file
apt-cache policy google-chrome-stable
```

---

## 3. JetBrains Toolbox and PhpStorm

### What it is for here

PhpStorm is the IDE, and Toolbox is how it is installed and updated. Two files
in this repository depend on the paths Toolbox creates, so this is not an
optional extra you can defer:

- `zsh/zshrc.sh` puts `$HOME/.local/share/JetBrains/Toolbox/scripts` on the
  `PATH`, which is what makes `phpstorm` runnable as a command.
- `guake/guake.dconf` sets
  `quick-open-command-line='__HOME__/.local/share/JetBrains/Toolbox/scripts/phpstorm --line %(line_number)s %(file_path)s'`,
  which is the click-to-open of `file:line` in terminal output. That is a hard
  path into the Toolbox scripts directory. Get the install location wrong and
  guake's quick-open silently does nothing.

### Why there is no `phpstorm/` directory in this repository

**PhpStorm settings sync through the JetBrains account.** Keymaps, code style,
inspections, plugins, the UI theme — Settings Sync pushes all of it to the
account and pulls it back on a new machine. Committing any of it here would be
a second, worse copy that drifts.

This is not a guess about how it should work; the repository already tried the
other way. `phpstorm/` was added in July 2014 (`e9b48c2`, "[phpstorm] - added
configuration", followed by `148ef48`, "[phpstorm] - added markdown plugin") as
a checked-in `phpstorm/WebIde70/config/` tree — `codestyles/`, `inspection/`,
`keymap.xml`, `options/*.xml`, and files like
`options/statistics.application.usages.xml` and `componentVersions/*.xml` that
are pure machine state. It was deleted wholesale in July 2016 by `afb622b`. Do
not bring it back.

### How it is actually installed here

Verified:

- Toolbox at `~/.local/share/JetBrains/Toolbox`, version `3.6.3.86383`
  (`bin/build.txt`). This is the current release: JetBrains' release feed lists
  `3.6.3.86383`, dated 2026-07-29, as latest for Linux.
- Launcher symlink `~/.local/bin/jetbrains-toolbox` →
  `~/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox`.
- PhpStorm at `~/.local/share/JetBrains/Toolbox/apps/phpstorm`, version
  `2026.2.0.1`, build `PS-262.8665.325`.
- The launcher script `~/.local/share/JetBrains/Toolbox/scripts/phpstorm`,
  generated by Toolbox, three lines, execs
  `apps/phpstorm/bin/phpstorm "$@"`.
- Toolbox writes the scripts location itself, in
  `~/.local/share/JetBrains/Toolbox/.settings.json`:
  `"shell_scripts": {"location": "$HOME/.local/share/JetBrains/Toolbox/scripts"}`.
  That is the setting the two repository files depend on. It is Toolbox's
  default, but confirm it rather than assume it.
- Autostart is `~/.config/autostart/jetbrains-toolbox.desktop`, written by
  Toolbox, `Exec=... --minimize`.

**Where reality differs from the vendor's instructions.** JetBrains' own
`Install-linux-tar.txt`, shipped inside the tarball, says to unpack "to the
location where you want to install the program" and the help pages suggest
something like `/opt`. This machine does not do that: the tarball contents live
in `~/.local/share/JetBrains/Toolbox/bin`, under the same directory Toolbox
uses for its own state. Keep it that way — a system-wide `/opt` install would
need root for every Toolbox self-update, and the `scripts` path both
`zsh/zshrc.sh` and `guake/guake.dconf` hardcode is the one under
`~/.local/share`.

One honest caveat: `which phpstorm` finds nothing from a `bash` shell, because
only `zsh/zshrc.sh` adds the scripts directory to `PATH`. Check it from zsh, or
call the script by its full path. This is expected, not a broken install.

### Install

Fetch the current Linux tarball and unpack it in place:

```sh
mkdir -p ~/.local/share/JetBrains/Toolbox
curl -fsSL -o /tmp/jetbrains-toolbox.tar.gz \
  "https://download.jetbrains.com/toolbox/jetbrains-toolbox-3.6.3.86383.tar.gz"
tar -xzf /tmp/jetbrains-toolbox.tar.gz \
  --strip-components=1 -C ~/.local/share/JetBrains/Toolbox
~/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox
```

JetBrains' own wording is "unpack the archive to the location where you want to
install the application", then run `./bin/jetbrains-toolbox` from that
directory. Here the installation directory *is*
`~/.local/share/JetBrains/Toolbox`, so `--strip-components=1` drops the
`jetbrains-toolbox-<version>` wrapper directory and lands `bin/` directly under
`Toolbox/` — which is the layout on this machine, where every file under
`bin/` still carries the archive's own 2026-07-27 timestamps. Toolbox then
initialises its state (`.settings.json`, `state.json`, `apps/`, `scripts/`) in
that same directory, which is the practical argument for installing there
rather than in `/opt`. To resolve the current version instead of pinning one:

```sh
curl -fsSL "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release"
```

Read `.TBA[0].downloads.linux.link` from the JSON.

The first launch does the rest by itself. JetBrains documents only the
`~/.local/share/applications` desktop entry, but on this machine everything
below carries the same timestamp as Toolbox's recorded `firstRunDate`
(`2026-08-01T11:19:34`), so all of it comes from that first run:
`~/.local/share/applications/jetbrains-toolbox.desktop`,
`~/.local/share/applications/jetbrainsd.desktop`,
`~/.config/autostart/jetbrains-toolbox.desktop`, and the
`~/.local/bin/jetbrains-toolbox` symlink. Do not create any of them by hand.
Installing PhpStorm later adds its own launcher,
`~/.local/share/applications/jetbrains-phpstorm-<uuid>.desktop`.

### Interactive steps that cannot be scripted

1. Sign in to the JetBrains account in Toolbox. This is what carries the
   licence and it is what makes Settings Sync possible.
2. Install PhpStorm from the Toolbox tool list. Toolbox downloads and unpacks
   it and generates `scripts/phpstorm`.
3. Confirm Toolbox's *Settings* / *Shell scripts* location is
   `~/.local/share/JetBrains/Toolbox/scripts`.
4. Launch PhpStorm, sign in again if asked, and enable **Settings Sync** —
   *Settings* / *Settings Sync* / *Enable Settings Sync* — then pull from the
   account. This is the step that restores the actual configuration.
5. Re-enter any per-plugin credentials that Settings Sync does not carry.

### Check it

```sh
# expects a version line, e.g. PhpStorm 2026.2.0.1; run from zsh, since only
# zsh/zshrc.sh puts the Toolbox scripts directory on PATH
~/.local/share/JetBrains/Toolbox/scripts/phpstorm --version

# expects the path guake/guake.dconf points at to exist and be executable
test -x ~/.local/share/JetBrains/Toolbox/scripts/phpstorm && echo ok
```

---

## 4. Claude Code

### What it is for here

A primary daily tool, used for the work in this repository among everything
else. `CLAUDE.md` lists it under Environment as "used daily".

### What comes from this repository, and what does not

The global configuration is **not** in this repository. It describes private
work, so it lives in Dropbox and is linked into `~/.claude/` file by file by the
Dropbox `claude` project, never replacing `~/.claude` itself.

Authentication does **not** come from this repository, and must not. It is
per-machine and interactive: you run `claude`, it opens a browser, you approve.
The token lands in `~/.claude/.credentials.json`, mode `0600`.

**Never copy `~/.claude/.credentials.json` between machines and never commit
it.** It is a live credential for the Anthropic account. Each machine
authenticates itself, once, by hand. The same goes for everything else in
`~/.claude/` that is state rather than configuration —
`settings.local.json`, `history.jsonl`, `projects/`, `sessions/`,
`.credentials.json`.

### How it is actually installed here

Verified: the **native installer**, not apt and not npm.

- `which claude` → `$HOME/.local/bin/claude`
- that path is a symlink to
  `$HOME/.local/share/claude/versions/2.1.220`
- `claude --version` → `2.1.220 (Claude Code)`
- `npm` is not installed on this machine at all, so an npm global install is
  ruled out
- no `claude-code` apt package is installed

This is exactly the layout the native installer produces and manages: the
launcher at `~/.local/bin/claude` as a symlink into
`~/.local/share/claude/versions/`. `~/.local/bin` is already first on the
`PATH` set by `zsh/zshrc.sh`, so nothing extra is needed to make `claude`
runnable.

**Where reality differs from what is available.** Anthropic now publishes a
signed apt repository, and this machine could in principle install
`claude-code` from it — which would make it a candidate for
`apt/packages.txt`. It deliberately does not, for one reason: **native
installations auto-update in the background; apt, dnf and apk installations do
not.** For a tool used every day, on two machines, silent self-update is worth
more than uniformity with the package list. Keep the native install.

Do not confuse this with the `claude-desktop` package, which **is** installed
here (version `1.24012.9`) from
`/etc/apt/sources.list.d/claude-desktop.list`, pointing at
`https://downloads.claude.ai/claude-desktop/apt/stable stable main` with the
key at `/usr/share/keyrings/claude-desktop-archive-keyring.asc`. That is the
GUI desktop application, a different product from the CLI, installed from a
`.deb` (apt history: `apt install
$HOME/Downloads/claude-desktop_amd64.deb`, which pulled in a large qemu
dependency set for its sandbox). Both write to `~/.claude/`, which is worth
remembering if you ever try to uninstall one.

### Install

The current official method for Linux, from
<https://code.claude.com/docs/en/setup>:

```sh
curl -fsSL https://claude.ai/install.sh | bash
```

That installs the `latest` channel, which is what this machine is on. `bash -s
stable` selects the stable channel instead, roughly a week behind; `bash -s
2.1.220` pins an exact version. Do not pin here — auto-update is the reason
this install method was chosen.

If a future rebuild ever does want the apt route despite the above, it is:

```sh
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL https://downloads.claude.ai/keys/claude-code.asc \
  -o /etc/apt/keyrings/claude-code.asc
gpg --show-keys /etc/apt/keyrings/claude-code.asc   # 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" \
  | sudo tee /etc/apt/sources.list.d/claude-code.list
sudo apt update && sudo apt install claude-code
```

Verify that fingerprint before trusting the key.

### Interactive steps that cannot be scripted

1. Run `claude` in a terminal. It opens a browser for login — which is why
   Chrome comes first.
2. Approve the login in the browser and return to the terminal. The token is
   written to `~/.claude/.credentials.json`. A Pro, Max, Team, Enterprise or
   Console account is required; the free plan does not include Claude Code.
3. Re-authenticate any MCP servers that need their own OAuth. Those are also
   per-machine.

### Check it

```sh
# expects: 2.1.220 (Claude Code) or newer
claude --version

# expects the launcher to be the native installer's symlink into versions/
readlink -f "$(command -v claude)"

# expects install health, settings validation and the last update result
claude doctor
```

---

## 5. Composer

Composer is on the host for the same reason PHP is: sometimes it is quicker to
run something outside a container. Every project resolves its own dependencies
inside Docker with its own pinned versions, so nothing depends on this copy.

PHP itself comes from `apt/packages.txt` and is installed by
`./install.sh --step packages`. Composer does not, for one reason: the apt
package lags upstream and cannot self-update, while the phar can. Since this
copy exists purely for convenience, the version that keeps itself current is
the one worth having.

Install it into `~/.local/bin`, which `zsh/zshrc.sh` already puts on the PATH.
The hash check is not optional — it is the only thing standing between a
compromised download and an arbitrary-code-execution as your user:

```sh
cd "$(mktemp -d)"
curl -fsSL -o composer-setup.php https://getcomposer.org/installer
EXPECTED="$(curl -fsSL https://composer.github.io/installer.sig)"
ACTUAL="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"
[ "$EXPECTED" = "$ACTUAL" ] || { echo "installer hash mismatch, do not run it"; exit 1; }

mkdir -p ~/.local/bin
php composer-setup.php --install-dir=$HOME/.local/bin --filename=composer
rm composer-setup.php
```

Keeping it current afterwards is `composer self-update`, which is the whole
reason for not using the apt package.

Check it:

```sh
composer --version
# expects a version line, and no PHP extension warnings

composer diagnose
# expects the checks to pass; it also reports whether a newer Composer exists

composer config --global home
# expects ~/.config/composer, whose vendor/bin zsh/zshrc.sh puts on the PATH
```

If `composer diagnose` complains about a missing extension, the fix is a line in
`apt/packages.txt`, not a one-off `apt install` — that file is the only place
where "why is this installed" stays answerable.

---

## What this document does not cover

- Anything installable from Ubuntu's archive. That is `apt/packages.txt`.
- Anything symlinked from this repository. That is `install.sh`, and
  `bin/doctor` checks it.
- The ssh keys, the GitHub key registration and the git identity, which are
  also manual but are documented in `INSTALL.md` because they gate cloning the
  repository in the first place — they come before everything here.
