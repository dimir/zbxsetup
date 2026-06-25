#!/usr/bin/env bash

#set -o errexit
#set -o nounset
set -o pipefail
#set -o xtrace

script_usage()
{
    echo -e "\t-r\t\tremove logs"
    echo -e "\t-s\t\tdo not start the server"
}

. .zbx

USER=zabbix
rv=0

pkill -u $USER zabbix_agentd
pkill -u $USER zabbix_server

for i in agentd proxy server; do
	if [ ! -f /etc/zabbix/zabbix_$i.conf ]; then
		continue
	fi
	wait_reported=0
	while pgrep -u $USER -l zabbix_$i >/dev/null; do
		if [ $wait_reported = 0 ]; then
			wait_reported=1
			msg "waiting for Zabbix $i to stop..."
		fi
		sleep 1
	done
done

opt_remove_logs=0
opt_start_server=1
while [ -n "$1" ]; do
    case "$1" in
	-r)
	    opt_remove_logs=1
	    ;;
	-s)
	    opt_start_server=0
	    ;;
	*)
	    usage
    esac
    shift
done

if [ $opt_remove_logs -eq 1 ]; then
    rm $O_ZLOGDIR/zabbix*.log
elif ls $O_ZLOGDIR/zabbix*.log >/dev/null 2>&1; then
    for i in $O_ZLOGDIR/zabbix*.log; do
	[ -f "$i" ] && mv $i $i.$(date +%d.%m.%y-%H%M%S)
    done
fi

if [ $opt_start_server -eq 1 ]; then
	out=$(grep '^DBName=' $O_ZCONFDIR/zabbix_server.conf)
	[ -n "$out" ] && msg "server $out"
fi

if [ -f /opt/zabbix ]; then
	if [ ! -L /opt/zabbix ]; then
		echo "cannot continue: directory /opt/zabbix exists"
		exit 1
	fi

	sudo rm -f /opt/zabbix
fi

sudo ln -sf /home/vl/git/icann/dev-rdds/opt/zabbix /opt/zabbix

bin=sbin/zabbix_agentd
if [[ -x $bin && -f $O_ZCONFDIR/zabbix_agentd.conf ]]; then
    opts=
    opts="-c $O_ZCONFDIR/zabbix_agentd.conf"
    msg "starting $bin $opts"
    $bin $opts
    rv=$?
    sleep 1
    [ $rv -eq 0 ] && pgrep -u $USER -l zabbix_agentd >/dev/null && msg "Zabbix Agent started"'!' || err "cannot start Zabbix Agent"'!'
fi

if [ $opt_start_server -eq 1 ]; then
    bin=sbin/zabbix_server
    opts=
    [ -e $bin ] || err "Zabbix Server ($bin) not available"'!'
    opts="-c $O_ZCONFDIR/zabbix_server.conf"
    msg "starting $bin $opts"
    $bin $opts
    rv=$?
    sleep 1
    [ $rv -eq 0 ] && pgrep -u $USER -l zabbix_server >/dev/null && msg "Zabbix Server started"'!' || err "cannot start Zabbix Server"'!'
fi

exit $rv
