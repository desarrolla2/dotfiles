export ZSH=$HOME/.oh-my-zsh
export PATH=$PATH:~/.local/bin:./node_modules/.bin:./vendor/bin

ZSH_THEME=desarrolla2
#ZSH_THEME="amuse" # (this is one of the fancy ones)
plugins=(git composer compleat symfony2 tmux vagrant react-native docker grunt ng)

source $ZSH/oh-my-zsh.sh

if [ -f ~/.bash_profile ]
then
  source ~/.bash_profile
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
