#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

(cat ~/.config/wpg/sequences &)
alias multimc='vblank_mode=0 multimc &'
export PATH="/home/bhava/.local/bin:$PATH"
[ -d "$HOME/.scripts" ] && PATH="$HOME/.scripts:$PATH"
