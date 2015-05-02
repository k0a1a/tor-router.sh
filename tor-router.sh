#!/bin/bash

## tor-router.sh - transparent TOR router capable of serving a subnet.
## Danja Vasiliev | http://k0a1a.net |  2015 | Artistic License 2.0

## requirements (debian):
## tor, torsock, redsocks
## /etc/redsocks.conf:
##  redsocks {
##   local_ip = 0.0.0.0;
##   local_port = 12345;
##   ip = 127.0.0.1;
##   port = 9050;
##  }
##
## invocation: tor-router.sh [start|stop|start_router|stop_router]

if [[ $EUID -ne 0 ]]; then
	echo 'You must be root' 1>&2
  su -c "$0 $1" root  
  exit
fi

## the following used only in 'router' mode
LOCAL_NIC='eth1' 
LOCAL_IP='10.4.5.0/24'
LOCAL_RANGE='100-110'

start_me() {
  service tor restart && pidof tor >/dev/null || { echo 'Tor is not running!'; exit 1; }
  service redsocks restart && pidof redsocks >/dev/null || { echo 'Redsocks is not running!'; exit 1; }

	## make REDSOCKS chain
	iptables -t nat -N REDSOCKS
	## exclude reserved addresses
	iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
	iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
	iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
	iptables -t nat -A REDSOCKS -d 169.254.0.0/16 -j RETURN
	iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN
	iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
	iptables -t nat -A REDSOCKS -d 224.0.0.0/4 -j RETURN
	iptables -t nat -A REDSOCKS -d 240.0.0.0/4 -j RETURN
	## redirect anything else to port 12345 (redsocks)
	iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345
	## exclude tor traffic from being redirected to redsocks
  iptables -t nat -A OUTPUT -p tcp -m owner \! --uid-owner $(id -u debian-tor) -j REDSOCKS
  #	iptables -t nat -A OUTPUT -p tcp -m owner --uid-owner user -j REDSOCKS
}

start_router() {
  ifconfig $LOCAL_NIC || exit 1
	start_me
	sleep 1
	ifconfig $LOCAL_NIC ${LOCAL_IP//.0/.1} up
	iptables -t nat -A PREROUTING --in-interface $LOCAL_NIC -p tcp -j REDSOCKS
	echo 1 > /proc/sys/net/ipv4/ip_forward
	dnsmasq -i $LOCAL_NIC -F ${LOCAL_IP//.0*/.}${LOCAL_RANGE%-*},${LOCAL_IP//.0*/.}${LOCAL_RANGE##*-}
}

stop_me() {
	## find REDSOCKS rule in OUTPUT
	REDSOCKS=$(iptables -t nat -L OUTPUT --line-numbers | awk '/REDSOCKS/ { print $1 }')
	[ -z "$REDSOCKS" ] || for i in $REDSOCKS; do iptables -t nat -D OUTPUT $i; done
	## find REDSOCKS rule in PREROUTING
	REDSOCKS=$(iptables -t nat -L PREROUTING --line-numbers | awk '/REDSOCKS/ { print $1 }')
	## if present delete it
	[ -z "$REDSOCKS" ] || for i in $REDSOCKS; do iptables -t nat -D PREROUTING $i; done
	## flush and delete REDSOCKS chain
	iptables -t nat -F REDSOCKS
	iptables -t nat -X REDSOCKS
	echo 0 > /proc/sys/net/ipv4/ip_forward
  [ -e /var/run/dnsmasq.pid ] &&
	kill $(cat /var/run/dnsmasq.pid) && rm /var/run/dnsmasq.pid
	[ -z $(ifconfig $LOCAL_NIC &>/dev/null| awk '/UP/') ] || ifconfig $LOCAL_NIC down
}

myip() {
  ## get our external ip address by asking http://wtfismyip.com
  (which geoiplookup && which curl) &>/dev/null || exit
  read -d '$\n' IP ERR < <(curl -sL -w "\n%{http_code}" --connect-timeout 5 http://ipv4.wtfismyip.com/test)
  [[ $ERR == "200" ]] && {
    echo -e "\n$IP";
    geoiplookup $IP | awk '/Country/ { print $4, $5, $6 }';
    echo -en "\n";
    exit 0; } || { echo 'error getting ip address'; exit 1; }
}

case "$1" in
	start)
		echo 'starting system-wide TOR redirection..'
		start_me
		sleep 1
		myip
		;;
	start_router)
		echo 'starting TOR router and system-wide redirection..'
		start_router
		sleep 1
		myip
		;;
	stop)
		echo 'stopping..'
		stop_me
		sleep 1
		myip
		;;
	*)
		echo 'Usage: tor-router.sh [start|start_router|stop]'
		exit 1
	;;
esac 
	
