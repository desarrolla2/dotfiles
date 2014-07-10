# Introduction

This are my personal dotfiles, i use this repository to share some of my configs about several computers, you can use it
to get any ideas about how i work, but be careful is possible that this repo is not updated.

# Installation

First of all you need to clone the entire project.

```zsh
git clone git@github.com:desarrolla2/dotfiles.git
```

You only need to install the components that you want.

## zsh

1. Install zsh with `apt-get install zsh` on debian/ubuntu system. More info [here](http://www.zsh.org/).
2. Install zsh oh-my-zsh, see more it [here](https://github.com/eyenx/omzsh).
3. Create a symbolic link.

```zsh
cd ~ && ln -s /path/to/dotfiles/zsh/zshrc.sh .zshrc
```

## tmux

1. Install tmux with `apt-get install tmux` on debian/ubuntu system. More info [here](http://tmux.sourceforge.net/).
3. Create a symbolic link.

```zsh
cd ~ && ln -s Projects/dotfiles/tmux/tmux.conf .tmux.conf
```

## phpstorm

Actually i am using phpstorm 7.1 you can download from [here](http://www.jetbrains.com/phpstorm/download/).

```zsh
cd ~ && rm -rf .WebIde70
ln -s /path/to/dotfiles/phpstorm/WebIde70 .WebIde70
```

# Contact

You can contact me on twitter [@desarrolla2](https://twitter.com/desarrolla2)
