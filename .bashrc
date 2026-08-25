#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

#(cat ~/.config/wpg/sequences &) # commented out when using kitty/alacritty so font colours change, otherwise it will stay white.
