# Introduction

This are my personal dotfiles, i use this repository to share some of my configs about several computers, you can use it
to get any ideas about how i work, but be careful is possible that this repo is not updated.

# Installation

First of all you need to clone the entire project.

```zsh
git clone git@github.com:desarrolla2/dotfiles.git
```

You only need to install the components that you want.

## zsh and oh-my-zsh

1. Install zsh with `apt-get install zsh` on debian/ubuntu system. More info [here](http://www.zsh.org/).
2. Install zsh oh-my-zsh, see more it [here](https://github.com/eyenx/omzsh).
3. Create a symbolic link.

```zsh
ln -s /path/to/dotfiles/zsh/zshrc.sh ~/.zshrc
ln -s /path/to/dotfiles/oh-my-zsh/desarrolla2.zsh-theme ~/.oh-my-zsh/themes/desarrolla2.zsh-theme
```
This is the aspect that will have your terminal

![screenshot](https://lh4.googleusercontent.com/-Cnm9OfD8PQ0/V5IV4HtZ7qI/AAAAAAAAHYA/W84Tk8vNbkMbGN7I3HA4eGIxTfWrVMzjACL0B/w1044-h157-no/desarrolla2_theme.png "Desarrolla2 theme screenshot")

## tmux

1. Install tmux with `apt-get install tmux` on debian/ubuntu system. More info [here](http://tmux.sourceforge.net/).
2. Create a symbolic link.

```zsh
ln -s /path/to/dotfiles/tmux/tmux.conf ~/.tmux.conf
```

I strongly recommend that you also use `guake`

## git

1. Install tmux with `apt-get install git` on debian/ubuntu system. More info [here](https://git-scm.com/).
2. Config your gitignore file.

```zsh
git config --global core.excludesfile /path/to/dotfiles/git/gitignore
 ```

## ssh

1. Create a symbolic link.

```zsh
ln -s /path/to/dotfiles/ssh/config ~/.ssh/config
 ```

# Contact

You can contact me on twitter [@desarrolla2](https://twitter.com/desarrolla2)
