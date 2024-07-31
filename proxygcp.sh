#!/bin/bash

random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$IP4:$port:$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
    $(awk -F ":" '{print "sudo iptables -I INPUT -p tcp --dport " $2 " -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F ":" '{print "sudo ifconfig ens4 inet6 add " $3 "/64"}' ${WORKDATA})
EOF
}

install_3proxy() {
    echo "installing 3proxy"
    URL="https://raw.githubusercontent.com/quayvlog/quayvlog/main/3proxy-3proxy-0.8.6.tar.gz"
    wget -qO- $URL | tar -xzf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    sudo mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    sudo cp src/3proxy /usr/local/etc/3proxy/bin/
    sudo cp ./scripts/rc.d/proxy.sh /etc/init.d/3proxy
    sudo chmod +x /etc/init.d/3proxy
    sudo update-rc.d 3proxy defaults
    cd $WORKDIR
}

gen_3proxy() {
    cat <<EOF
daemon
maxconn 1000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid nogroup
setuid nobody
flush
auth none

$(awk -F ":" '{print "proxy -6 -n -a -p" $2 " -i" $1 " -e"$3"\n" "flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F ":" '{print $1 ":" $2}' ${WORKDATA})
EOF
}

echo "installing apps"
sudo apt-get update
sudo apt-get install -y gcc net-tools zip tar wget make >/dev/null

install_3proxy

echo "working folder = /home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $WORKDIR

IP4=$(curl -4 -s icanhazip.com)
IP6="2600:1900:4001:e6b0:3::"

echo "Internal IP = ${IP4}. External sub for IPv6 = ${IP6}"

echo "How many proxy do you want to create? Example 500"
read COUNT

FIRST_PORT=10000
LAST_PORT=$(($FIRST_PORT + $COUNT))

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x ${WORKDIR}/boot_*.sh

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat <<EOF | sudo tee /etc/rc.local
#!/bin/bash
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
service 3proxy start
EOF

sudo chmod +x /etc/rc.local
sudo bash /etc/rc.local

gen_proxy_file_for_user

echo "Proxy is ready! Format IP:PORT"
cat proxy.txt
