############################
# Getting base directory
############################

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

############################
# GOLANG
############################

export PATH="$PATH:/usr/local/go/bin"
#export GOROOT="/home/dgonzalez/go"
export GOPATH="/home/dgonzalez/go"
export PATH="$PATH:$GOPATH/bin"

############################
# Add paths to bin
############################

BIN_PERSONAL_DIRECTORY=~/.local/bin
BIN_DOCFILES_DIRECTORY=$BASE_DIR"/bin"

if [[ ! -e $BIN_PERSONAL_DIRECTORY ]]; then
    mkdir $BIN_PERSONAL_DIRECTORY
fi

export PATH="$PATH:$BIN_PERSONAL_DIRECTORY:$BIN_DOCFILES_DIRECTORY"

############################
# Set the environment 
############################

export VISUAL='vim'

