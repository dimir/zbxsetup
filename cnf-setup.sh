#!/bin/bash

additional_usage()
{
    echo -e "\t<key>=<val>\tset 'key' to 'val' in Zabbix configuration"
}

script_usage()
{
    echo -e "\t-v\t\tshow configuration details"
}

. .zbx

FILES_PTRN="$O_ZCONFDIR/*.conf"
SERV_PRI_PORT=11337
SERV_SEC_PORT=11338	# if proxy used
AGENT_PORT=11339

verb=0
for opt; do
	[ "$opt" = "-v" ] && verb=1 && break
done

for key in DBHost DBName DBUser; do
	value=$(eval echo \$$key)
	dbg "setting $key=$value"
	for f in $FILES_PTRN; do
		dbg "  in file $f"
		sed -i "s/^\(\([#\ ]*\)\?\)$key=.*/\1$key=$value/g" $f
	done
	[ $verb = 1 ] && echo "$key=$value"
done

CF="$O_ZCONFDIR/zabbix_server.conf"
if [ -f "$CF" ]; then
	for opt in PidFile LogFile; do
		if grep -q "^$opt=" "$CF"; then
			sed -i "s,^$opt=.*/\([^/]\+\),$opt=$O_ZLOGDIR/\1,g" "$CF"
		else
			echo "$opt=$O_ZLOGDIR/$(basename ${CF%.*}).$(echo ${opt:0:3} | tr '[A-Z]' '[a-z]')" >> "$CF"
		fi
	done

	# different server port if proxy used
	if [ $O_PRX -eq 1 ]; then
		sed -i "s/^ListenPort=.*/ListenPort=$SERV_SEC_PORT/" "$CF"
	else
		sed -i "s/^ListenPort=.*/ListenPort=$SERV_PRI_PORT/" "$CF"
	fi
fi

CF="$O_ZCONFDIR/zabbix_proxy.conf"
if [ -f "$CF" ]; then
	for opt in PidFile LogFile; do
		if grep -q "^$opt=" "$CF"; then
			sed -i "s,^$opt=.*/\([^/]\+\),$opt=$O_ZLOGDIR/\1,g" "$CF"
		else
			echo "$opt=$O_ZLOGDIR/$(basename ${CF%.*}).$(echo ${opt:0:3} | tr '[A-Z]' '[a-z]')" >> "$CF"
		fi
	done

	# db name in proxy is different
	sed -i "s/^DBName=.*/DBName=$PRX_DBName/" "$CF"
	if [ $O_PRX -eq 1 ]; then
		sed -i "s/^ListenPort=.*/ListenPort=$SERV_PRI_PORT/" "$CF"
		sed -i "s/^ServerPort=.*/ServerPort=$SERV_SEC_PORT/" "$CF"
	fi
fi

CF="$O_ZCONFDIR/zabbix_agentd.conf"
if [ -f "$CF" ]; then
	for opt in PidFile LogFile; do
		if grep -q "^$opt=" "$CF"; then
			sed -i "s,^$opt=.*/\([^/]\+\),$opt=$O_ZLOGDIR/\1,g" "$CF"
		else
			echo "$opt=$O_ZLOGDIR/$(basename ${CF%.*}).$(echo ${opt:0:3} | tr '[A-Z]' '[a-z]')" >> "$CF"
		fi
	done

	sed -i "s/^ListenPort=.*/ListenPort=$AGENT_PORT/" "$CF"
	sed -i "s/^ServerActive=.*/ServerActive=127.0.0.1:$SERV_PRI_PORT/" "$CF"
fi

# check if zabbix binaries are ready
zbx_serv_bin="sbin/zabbix_server"
if [ -f $zbx_serv_bin -a "$(which strings)" ]; then
	case $O_DB in
		m)
			# MySQL
			if ! strings $zbx_serv_bin | grep -q mysql_init; then
				msg "$zbx_serv_bin is not compiled with MySQL support"
				recompile
			fi
			;;
		p)
			# PostgreSQL
			if ! strings $zbx_serv_bin | grep -q PostgreSQL; then
				msg "$zbx_serv_bin is not compiled with PostgreSQL support"
				recompile
			fi
			;;
		*)
			;;
	esac
fi

# same for frontend
FE_CONF=frontends/php/conf/zabbix.conf.php
if [ ! -f "$FE_CONF" ]; then
	[ -f "${FE_CONF}.example" ] && cp "${FE_CONF}.example" "$FE_CONF"
fi
if [ -f "$FE_CONF" ]; then
	db_type=
	case $O_DB in
		m)
			db_type=MYSQL
			;;
		p)
			db_type=POSTGRESQL
			;;
		*)
			err "unsupported db type"
			;;
	esac
	sed -i "s/\(.*DB\[['\"]TYPE['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\1$db_type\2/"			$FE_CONF
	sed -i "s/\(.*DB\[['\"]SERVER['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\1$DBHost\2/"			$FE_CONF
	sed -i "s/\(.*DB\[['\"]DATABASE['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\1$DBName\2/"		$FE_CONF
	sed -i "s/\(.*DB\[\"PORT\"\].*= '\)[^']*\(';\)/\1\2/"						$FE_CONF
	if [ $O_DB = "m" ]; then
		sed -i "s/\(.*DB\[['\"]PORT['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\13306\2/"		$FE_CONF
	else
		sed -i "s/\(.*DB\[['\"]PORT['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\1\2/"			$FE_CONF
	fi
	sed -i "s/\(.*DB\[['\"]USER['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\1$DBUser\2/"			$FE_CONF
	sed -i "s/\(.*DB\[['\"]PASSWORD['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\1\2/"			$FE_CONF
	if [ $O_PRX -eq 1 ]; then
		sed -i "s/\(.*\$ZBX_SERVER_PORT.*= ['\"]\)[^'\"]*\(['\"];\)/\1$SERV_SEC_PORT\2/"	$FE_CONF
	else
		sed -i "s/\(.*\$ZBX_SERVER_PORT.*= ['\"]\)[^'\"]*\(['\"];\)/\1$SERV_PRI_PORT\2/"	$FE_CONF
	fi
fi

while [ -n "$1" ]; do
	if [[ $1 =~ = ]]; then
		key=${1%=*}
		val=${1#*=}

		[ $verb = 1 ] && echo "$key=$val"

		for f in $FILES_PTRN; do
			if grep -q "^$key=" $f; then
				sed -i "s/^$key=.*/$key=$val/g" $f
			else
				echo -n "$key not found in $f, add? [Y/n] "
				read ans
				ans=$(echo $ans | tr '[A-Z]' '[a-z]')
				if [ -z "$ans" -o "$ans" = "y" ]; then
					echo $key=$val >> $f
				fi
			fi
		done
	fi
	shift
done
