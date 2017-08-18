export ZSH=$HOME/.oh-my-zsh
export GOPATH=~/go
export PATH=$PATH:~/.local/bin:./node_modules/.bin:./vendor/bin:$GOPATH/bin

ZSH_THEME=desarrolla2
#ZSH_THEME="amuse" # (this is one of the fancy ones)
plugins=(git composer compleat symfony2 tmux vagrant react-native docker grunt)

source $ZSH/oh-my-zsh.sh

if [ -f ~/.bash_profile ]
then
  source ~/.bash_profile
fi
