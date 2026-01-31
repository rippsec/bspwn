function zat() {
    zathura "$@" &!
}

function atril() {
    command atril "$@" &!
}

function java11(){
    echo "switching to java 11..."
    sudo update-java-alternatives -s java-1.11.0-openjdk-amd64
    export PATH=$PATH:$JAVA_HOME
    java --version
}

function java17(){
    echo "switching to java 17..."
    sudo update-java-alternatives -s java-1.17.0-openjdk-amd64
    export PATH=$PATH:$JAVA_HOME
    java --version
}

function w32(){
    export WINEARCH=win32
    export WINEPREFIX=~/.wine32
}

function w64(){
    export WINEARCH=win64
    export WINEPREFIX=~/.wine
}

function rsp(){
  sudo rsync -rhazc --info=progress2 $@
}

function realpath() {
  command realpath "$@" | xsel -b
}
