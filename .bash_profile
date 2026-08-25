#
# ~/.bash_profile
[[ -f ~/.profile ]] && . ~/.profile

[[ -f ~/.bashrc ]] && . ~/.bashrc
        export PATH="/home/bhava/.local/bin:$PATH" 
        export OPENSSL_ia32cap=~0x200000200000000
        [ -d "$HOME/.dotfiles/.scripts" ] && PATH="$HOME/.dotfiles/.scripts:$PATH"
 
