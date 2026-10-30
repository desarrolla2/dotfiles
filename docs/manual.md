# Manual applications

Four applications that `install.sh` does not touch. Each one ends in an account
sign-in, and the sign-in is what restores the configuration. Do not move their
installs into `install.sh`: the machine would look ready with nothing signed in.

Do them in this order:

1. **Dropbox**: its first sync takes hours and everything else waits on it.
2. **Chrome**: the next two logins open a browser, so they land in the one
   already signed in.
3. **JetBrains Toolbox / PhpStorm**: `zsh/zshrc.sh` and `guake/guake.dconf`
   reference paths it creates.
4. **Claude Code**: its configuration arrives through Dropbox, so the sync has
   to be done first.

---

## 1. Dropbox

The folder must be `~/Documents/Dropbox`, not the default `~/Dropbox`: every
symlink into Dropbox points there, and with the default they dangle silently.
Only the setup wizard can set it; moving it later means a full re-download.

```sh
curl -fsSL -o /tmp/dropbox.deb \
  "https://www.dropbox.com/download?dl=packages/ubuntu/dropbox_2026.05.06_amd64.deb"
sudo apt install /tmp/dropbox.deb
dropbox start -i
```

For the current version, take the "Ubuntu 64-bit" `.deb` from
<https://www.dropbox.com/install-linux> instead. The package holds only the CLI
and the Nautilus extension, and registers Dropbox's apt repository and an
autostart entry. `dropbox start -i` downloads the sync daemon into
`~/.dropbox-dist`.

Then, by hand:

1. Accept the daemon download.
2. Sign in to the Dropbox account in the browser window it opens.
3. On the folder screen, *Advanced settings* / *Change*: set
   `~/Documents/Dropbox`.
4. Choose selective sync if you do not want the whole account here.
5. Wait for `Up to date`, hours on a full account, before any step that reads
   from Dropbox. A partial tree gives dangling symlinks that look like a broken
   setup.

Check it:

```sh
# expects: Up to date
dropbox status

# expects {"personal": {"path": "$HOME/Documents/Dropbox", ...
cat ~/.dropbox/info.json

# expects ok: the folder is at the non-default path and ~/Dropbox does not exist
test -d ~/Documents/Dropbox && ! test -e ~/Dropbox && echo ok
```

---

## 2. Google Chrome

```sh
curl -fsSL -o /tmp/google-chrome.deb \
  "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
sudo apt install /tmp/google-chrome.deb
```

The `.deb` registers Google's apt repository itself, so updates arrive with
`apt upgrade`.

Then, by hand:

1. Sign in to the Google account, turn on sync and wait for bookmarks,
   extensions and passwords to come back.
2. Re-enter any extension login that Chrome sync does not carry.
3. Make it the default browser if the desktop did not already ask.

Check it:

```sh
# expects a version line
google-chrome --version

# expects the installed version to come from dl.google.com, not a local file
apt-cache policy google-chrome-stable
```

---

## 3. JetBrains Toolbox and PhpStorm

Install under `~/.local/share/JetBrains/Toolbox`, not `/opt` as JetBrains
suggests: Toolbox self-updates there without root, and `zsh/zshrc.sh` (`PATH`)
and `guake/guake.dconf` (click-to-open of `file:line`) hardcode its `scripts/`
path. With the wrong location guake's quick-open silently does nothing.

```sh
mkdir -p ~/.local/share/JetBrains/Toolbox
curl -fsSL -o /tmp/jetbrains-toolbox.tar.gz \
  "https://download.jetbrains.com/toolbox/jetbrains-toolbox-3.6.3.86383.tar.gz"
tar -xzf /tmp/jetbrains-toolbox.tar.gz \
  --strip-components=1 -C ~/.local/share/JetBrains/Toolbox
~/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox
```

`--strip-components=1` drops the archive's wrapper directory, so `bin/` lands
directly under `Toolbox/`. For the current version, read
`.TBA[0].downloads.linux.link` from:

```sh
curl -fsSL "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release"
```

The first launch creates the desktop entries, the autostart entry and
`~/.local/bin/jetbrains-toolbox`. Do not create them by hand.

Then, by hand:

1. Sign in to the JetBrains account in Toolbox. It carries the licence and
   Settings Sync.
2. Install PhpStorm from the Toolbox tool list. This generates
   `scripts/phpstorm`.
3. Confirm Toolbox's *Settings* / *Shell scripts* location is
   `~/.local/share/JetBrains/Toolbox/scripts`.
4. Launch PhpStorm, enable *Settings* / *Settings Sync* / *Enable Settings
   Sync* and pull from the account. This restores the configuration, which is
   why there is no `phpstorm/` directory here.
5. Re-enter any plugin credentials that Settings Sync does not carry.

Check it:

```sh
# expects a version line
~/.local/share/JetBrains/Toolbox/scripts/phpstorm --version

# expects ok: the path guake/guake.dconf points at exists and is executable
test -x ~/.local/share/JetBrains/Toolbox/scripts/phpstorm && echo ok
```

`which phpstorm` finds nothing from bash: only `zsh/zshrc.sh` puts `scripts/` on
`PATH`. That is expected, not a broken install.

---

## 4. Claude Code

Native installer, not Anthropic's apt repository: native installs update
themselves in the background, apt ones do not.

```sh
curl -fsSL https://claude.ai/install.sh | bash
```

That is the `latest` channel; `bash -s stable` picks the stable one, about a
week behind. Do not pin a version: auto-update is why this method was chosen.

The configuration is not in this repository. It arrives through Dropbox, linked
into `~/.claude/` file by file by the Dropbox `claude` project (INSTALL.md
step 11).

Then, by hand:

1. Run `claude`. It opens the browser to log in. A Pro, Max, Team, Enterprise
   or Console account is required.
2. Approve the login. The token lands in `~/.claude/.credentials.json`: never
   copy it between machines and never commit it. Each machine signs in once.
3. Re-authenticate any MCP server with its own OAuth; that is per machine too.

Check it:

```sh
# expects a version line
claude --version

# expects a path under ~/.local/share/claude/versions/, the native layout
readlink -f "$(command -v claude)"

# expects install health, settings validation and the last update result
claude doctor
```
