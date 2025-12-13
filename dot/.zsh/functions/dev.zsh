function gip(){
  git add .
  git commit -m x
  git push origin main --force
}

function afu()
{
    sudo apt update -y
    export DEBIAN_FRONTEND=noninteractive
    sudo -E apt-get -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" dist-upgrade -q -y --allow-downgrades --allow-remove-essential --allow-change-held-packages
    apt -y autoremove
    apt -y purge
    apt -y clean
}
