# Syntax-highlighting
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    . /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern line regexp)
    ZSH_HIGHLIGHT_STYLES[default]=none
    ZSH_HIGHLIGHT_STYLES[line]=bold
    ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=red,underline
    ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=cyan
    ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=green,underline
    ZSH_HIGHLIGHT_STYLES[global-alias]=fg=green
    ZSH_HIGHLIGHT_STYLES[precommand]=fg=green,underline
    ZSH_HIGHLIGHT_STYLES[commandseparator]=fg=blue
    ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=green,underline
    ZSH_HIGHLIGHT_STYLES[path]=bold,underline,fg=blue
    ZSH_HIGHLIGHT_STYLES[path_pathseparator]=
    ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]=
    ZSH_HIGHLIGHT_STYLES[globbing]=fg=blue
    ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=blue
    ZSH_HIGHLIGHT_STYLES[command-substitution]=none
    ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[process-substitution]=none
    ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=green
    ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=green
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=none
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]=fg=blue
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[rc-quote]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[assign]=none
    ZSH_HIGHLIGHT_STYLES[redirection]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[comment]=fg=gray
    ZSH_HIGHLIGHT_STYLES[named-fd]=none
    ZSH_HIGHLIGHT_STYLES[numeric-fd]=none
    ZSH_HIGHLIGHT_STYLES[arg0]=fg=cyan
    ZSH_HIGHLIGHT_STYLES[bracket-error]=fg=red
    ZSH_HIGHLIGHT_STYLES[bracket-level-1]=fg=blue
    ZSH_HIGHLIGHT_STYLES[bracket-level-2]=fg=green
    ZSH_HIGHLIGHT_STYLES[bracket-level-3]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[bracket-level-4]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[bracket-level-5]=fg=cyan
    ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]=standout
    ZSH_HIGHLIGHT_STYLES[alias]=fg=magenta
    ZSH_HIGHLIGHT_REGEXP+=('sudo' bg=red,fg=black,bold)
    ZSH_HIGHLIGHT_REGEXP+=('sudo' bg=red,fg=black,bold)
    ZSH_HIGHLIGHT_REGEXP+=('rm(\s+-[^\s]+|\s+--[^\s]+)*' bg=red,fg=black,bold)
    ZSH_HIGHLIGHT_REGEXP+=('sudo\s+rm(\s+-[^\s]+|\s+--[^\s]+)*' bg=red,fg=black,bold)
    ZSH_HIGHLIGHT_REGEXP+=('\$\([^\)]*rm[^\)]*\)|`[^`]*rm[^`]*`' bg=red,fg=black,bold)
fi
