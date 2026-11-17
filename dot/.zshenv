# ~/.zshenv — read by every zsh, before ~/.zshrc.
# Debian/Kali's /etc/zsh/zshrc runs its own compinit; skip it: completion is
# initialised once in ~/.zsh/config/completion.zsh (zsh-autocomplete runs it).
skip_global_compinit=1
