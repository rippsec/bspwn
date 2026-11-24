EUID=$(id -u); IDLE_LOCK=3; source ./fn.sh
# fake: idle only after 4 s from start
xssstate() { echo 6000; }
timeout 14 bash -c 'source ./fn.sh; EUID=$(id -u); IDLE_LOCK=3; xssstate(){ echo 6000; }; watch_idle'
