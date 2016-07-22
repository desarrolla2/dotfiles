
export ZSH=$HOME/.oh-my-zsh
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:~/.local/bin"

ZSH_THEME="desarrolla2"
#ZSH_THEME="amuse" # (this is one of the fancy ones)
plugins=(git cap composer compleat symfony2 tmux vagrant)

source $ZSH/oh-my-zsh.sh
source ~/.local/oh-my-zsh/git-flow.plugin.zsh
source ~/.bash_profile

