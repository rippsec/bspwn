alias ls='lsd -v --icon never --group-directories-first'
alias ll='ls -lh'
alias lv='\ls -v1 '
alias la='ls -a1'
alias l='ls -1v'
alias lt='ls -1t'
alias lla='ls -lha'
alias lra='ls -lRa'
alias igrep='grep -i'
alias grepi='grep -i'
alias rm='rm -Iv'
alias cat='batcat --paging=never --style=plain'
alias tra='trans --brief'
alias ris="ristretto"
alias kp="kolourpaint"
alias torwho="whois -h torwhois.com"
alias cls="clear"
alias img="w3m -o ext_image_viewer=0"
alias bspwmrc=". ~/.config/bspwm/bspwmrc"
alias virtualbox="virtualbox -style fusion %U"
alias less="batcat -p --color=always"
alias cal="ncal -bwyM"
alias acs="apt-cache search"
alias del="/bin/rm -rfv"
alias which="which -a"
alias docker="sudo docker"

alias yp3="yt-dlp -x --audio-format mp3 --audio-quality 128K  --output '%(title)s.%(ext)s'"
alias yp4="yt-dlp --format mp4  --output '%(title)s.%(ext)s'"
alias ydl="yt-dlp"
alias python='python -W "ignore"'
alias smbmap='smbmap --no-banner'
alias verse="verse | tr -s ' '| tr -d '' | sed 's/^ //'"
alias target='setg rhost'
alias ctarget='unsetg rhost'
alias hosts='sudoedit /etc/hosts'
alias btop='sudo btop'
alias htop='sudo htop'
alias top='sudo top'
alias show-options="show_options"
alias rhost='setg rhost'
alias rport='setg rport'
alias lhost='setg lhost'
alias lport='setg lport'
alias root='sudo su'
alias caido='caido > /dev/null 2>&1'

alias rot13-encode='tr "A-Za-z" "N-ZA-Mn-za-m"'
alias rot13-decode='tr "A-Za-z" "N-ZA-Mn-za-m"'
alias copy='cp'
alias move='mv'

alias lsof='sudo lsof'
alias autorecon='sudo autorecon'
alias responder='sudo responder'
