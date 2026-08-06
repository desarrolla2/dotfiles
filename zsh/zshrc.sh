#
# ~/.zshrc -> symlink to dotfiles/zsh/zshrc.sh
#

export ZSH="$HOME/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
# Empty on purpose: the prompt comes from starship's default preset, so no
# oh-my-zsh theme is loaded.
ZSH_THEME=""


# --------------------------------------------------------------------- path --

# This has to come BEFORE the plugin block: that block probes for commands with
# $commands[...], which only sees what is already on the PATH. With the two
# blocks the other way round, composer installed in ~/.local/bin went unnoticed
# and its plugin never loaded, except on machines where the parent process
# happened to export that directory already.
#
# No relative entries. The previous PATH carried ./vendor/bin and
# ./node_modules/.bin, which run binaries from any repository you cd into.
path=(
  "$HOME/.local/bin"
  "$HOME/.config/composer/vendor/bin"
  "$HOME/.local/share/JetBrains/Toolbox/scripts"
  $path
)
typeset -U path               # drop duplicates
export PATH


# ------------------------------------------------------------------ plugins --

plugins=(git docker docker-compose extract sudo colored-man-pages)

# Environments run in Docker, so composer may be missing from the host. Loading
# it blindly leaves tab completion hanging.
(( $+commands[composer] )) && plugins+=(composer)
(( $+commands[fzf] ))      && plugins+=(fzf)

# nvm costs ~500ms to load. Deferred, that is only paid when node/npm/nvm run.
if [[ -d "$HOME/.nvm" ]]; then
  zstyle ':omz:plugins:nvm' lazy yes
  plugins+=(nvm)
fi

# External plugins, cloned into $ZSH_CUSTOM/plugins. Skipped when missing, so a
# half-configured machine does not throw errors on every terminal you open.
# zsh-syntax-highlighting has to stay last in the list.
for _plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  [[ -d "$ZSH_CUSTOM/plugins/$_plugin" ]] && plugins+=("$_plugin")
done
unset _plugin

source "$ZSH/oh-my-zsh.sh"


# ------------------------------------------------------------------ history --

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt EXTENDED_HISTORY       # store a timestamp for every command
setopt HIST_IGNORE_ALL_DUPS   # a repeated command only takes up one entry
setopt HIST_IGNORE_SPACE      # " command" with a leading space is not stored
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY          # history shared across open terminals


# --------------------------------------------------------------------- misc --

export EDITOR="${EDITOR:-nano}"


# ----------------------------------------------------------------- starship --

# The prompt. Default preset, minus what starship/starship.toml turns off.
# Guarded so a machine where starship is not installed yet still gets a usable
# shell instead of an error on every terminal you open.
(( $+commands[starship] )) && eval "$(starship init zsh)"


# -------------------------------------------------------------------- local --

# Settings specific to this machine, kept out of the repository: tokens, client
# paths, overrides. Anything that must not reach GitHub or the other machine.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
