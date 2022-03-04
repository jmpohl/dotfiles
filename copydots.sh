#!/bin/zsh

dotfiles_dir=$HOME/dotfiles

#delcare -A dirs=( .config/kak/colors .newsboat)
#
#for d in $dirs; do
#    if [ ! -d $d]
#    	echo "mkdir -p ${HOME}/${d}"
#    	mkdir -p $d
#    else
#        echo "Directory $d already exists"
#done

declare -A dotfiles=(
    ["$dotfiles_dir/zshrc"]="$HOME/.zprezto/runcoms/zshrc"
    ["$dotfiles_dir/zprofile"]="$HOME/.zprezto/runcoms/zprofile"
    ["$dotfiles_dir/zpreztorc"]="$HOME/.zprezto/runcoms/zpreztorc"
    ["$dotfiles_dir/tmux.conf"]="$HOME/.tmux.conf"
    ["$dotfiles_dir/kak"]="$HOME/.config/kak"
    ["$dotfiles_dir/newsboat"]="$HOME/.newsboat"
    ["$dotfiles_dir/mpv"]="$HOME/.config/mpv"

    #["$dotfiles_dir/julia"]="$HOME/.julia"
    #["$dotfiles_dir/jupyter"]="$HOME/.jupyter"
)

for dotfile location in "${(@kv)dotfiles}"; do
    if [ ! -f $location ] && [ ! -d $location ]; then
    	echo cp $dotfile $location
    	cp $dotfile ${dotfiles[$i]}
    else
        echo "Dotfile $location already exists!!"
    fi
done
