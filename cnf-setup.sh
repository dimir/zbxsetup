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

branch=$(git branch | grep '^*' | awk '{print $2}')

if [ -z "$branch" ]; then
	echo "something impossible just happened"
	exit -1
fi

if [[ ! -d ui/modules && ! -d frontends/php ]]; then
	echo "please change directory to repository root"
	exit 1
fi

FILES_PTRN="$O_ZCONFDIR/zabbix_*.conf"
SERVER_PORT_PRIMARY=10051
SERVER_PORT_SECONDARY=10052
AGENT_PORT=10050
WEB_IP=192.168.6.85
TESTS_DIR=~/tmp/rsm-tests

if [ $O_PRX -eq 1 ]; then
	SERVER_PORT=${SERVER_PORT_SECONDARY}
	PROXY_PORT=${SERVER_PORT_PRIMARY}
else
	SERVER_PORT=${SERVER_PORT_PRIMARY}
fi

verb=0
for opt; do
	[ "$opt" = "-v" ] && verb=1 && break
done

echo "DBUser=$DBUser"
echo "DBPassword=$DBPassword"
echo "DBName=$DBName"
echo "URLPATH=$O_URLPATH"

for key in DBHost DBName DBUser DBPassword; do
	value=$(eval echo \$$key)
	dbg "setting $key=$value"
	for f in $FILES_PTRN; do
		dbg "  in file $f"
		sed -i "s/^\(\([#\ ]*\)\?\)$key=.*/\1$key=$value/g" $f
	done
	[ $verb = 1 ] && echo "$key=$value"
done

# this is done by run-tests.sh
# CONF="automated-tests/framework/tests.conf"
# if [[ -d "automated-tests" && ! -f "$CONF" ]]; then
#	cp "$CONF.example" "$CONF"
#
# 	BASE_DIR="$(pwd)/automated-tests"
# 	sed -i 's,^source_dir=.*,source_dir='$(pwd)',g'                                   "$CONF"
# 	sed -i 's,^build_dir=.*,build_dir='${BASE_DIR}'/build,g'                          "$CONF"
# 	sed -i 's,^logs_dir=.*,logs_dir='${BASE_DIR}'/logs,g'                             "$CONF"
# 	sed -i 's,^db_dumps_dir=.*,db_dumps_dir='${BASE_DIR}'/db_dumps,g'                 "$CONF"

# 	sed -i 's,^socket_dir=.*,socket_dir='${BASE_DIR}',g'                              "$CONF"
# 	sed -i 's,^pid_file=.*,pid_file='${BASE_DIR}',g'                                  "$CONF"
# 	sed -i 's,^db_name=.*,db_name='${DBName}',g'                                      "$CONF"
# 	sed -i 's,^db_username=.*,db_username='${DBUser}',g'                              "$CONF"
# 	sed -i 's,^db_password=.*,db_password='${DBPassword}',g'                          "$CONF"

# 	sed -i -rz 's,\[frontend\]\nurl=,[frontend]\nurl=http://'${WEB_IP}'/'${O_URLPATH}'/ui,' "$CONF"
# fi

CONF="$O_ZCONFDIR/zabbix_server.conf"
if [ -f "$CONF" ]; then
	for opt in PidFile LogFile; do
		if grep -q "^$opt=" "$CONF"; then
			sed -i "s,^$opt=.*/\([^/]\+\),$opt=$O_ZLOGDIR/\1,g" "$CONF"
		else
			echo "$opt=$O_ZLOGDIR/$(basename ${CONF%.*}).$(echo ${opt:0:3} | tr '[A-Z]' '[a-z]')" >> "$CONF"
		fi
	done

	sed -i "s/^ListenPort=.*/ListenPort=${SERVER_PORT}/" "$CONF"
fi

if [ $O_PRX -eq 1 ]; then
	CONF="$O_ZCONFDIR/zabbix_proxy.conf"
	if [ -f "$CONF" ]; then
		for opt in PidFile LogFile; do
			if grep -q "^$opt=" "$CONF"; then
				sed -i "s,^$opt=.*/\([^/]\+\),$opt=$O_ZLOGDIR/\1,g" "$CONF"
			else
				echo "$opt=$O_ZLOGDIR/$(basename ${CONF%.*}).$(echo ${opt:0:3} | tr '[A-Z]' '[a-z]')" >> "$CONF"
			fi
		done

		# db name in proxy is different
		sed -i "s/^DBName=.*/DBName=$PRX_DBName/" "$CONF"
		sed -i "s/^ListenPort=.*/ListenPort=${PROXY_PORT}/" "$CONF"
		sed -i "s/^ServerPort=.*/ServerPort=${SERVER_PORT}/" "$CONF"
	fi
fi

CONF="$O_ZCONFDIR/zabbix_agentd.conf"
if [ -f "$CONF" ]; then
	for opt in PidFile LogFile; do
		if grep -q "^$opt=" "$CONF"; then
			sed -i "s,^$opt=.*/\([^/]\+\),$opt=$O_ZLOGDIR/\1,g" "$CONF"
		else
			echo "$opt=$O_ZLOGDIR/$(basename ${CONF%.*}).$(echo ${opt:0:3} | tr '[A-Z]' '[a-z]')" >> "$CONF"
		fi
	done

	sed -i "s/^ListenPort=.*/ListenPort=$AGENT_PORT/" "$CONF"
	sed -i "s/^ServerActive=.*/ServerActive=127.0.0.1:${SERVER_PORT_PRIMARY}/" "$CONF"
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

CONF=ui/conf/zabbix.conf.php
if [ ! -f "${CONF}.example" ]; then
	CONF=frontends/php/conf/zabbix.conf.php
fi

if [ ! -f "$CONF" ]; then
	[ -f "${CONF}.example" ] && cp -v "${CONF}.example" "$CONF"
fi

if [ -f "$CONF" ]; then
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
	sed -i "s/\(.*DB\[['\"]TYPE['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\1$db_type\2/"		$CONF
	sed -i "s/\(.*DB\[['\"]SERVER['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\1$DBHost\2/"		$CONF
	sed -i "s/\(.*DB\[['\"]DATABASE['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\1$DBName\2/"	$CONF
	sed -i "s/\(.*DB\[['\"]USER['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\1$DBUser\2/"		$CONF
	sed -i "s/\(.*DB\[['\"]PASSWORD['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\1$DBPassword\2/"	$CONF

	if [ $O_DB = "m" ]; then
		sed -i "s/\(.*DB\[['\"]PORT['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\10\2/"		$CONF
	else
		sed -i "s/\(.*DB\[['\"]PORT['\"]\].*= ['\"]\)[^'\"]*\(['\"];\)/\1\2/"		$CONF
	fi

	sed -i "s/\(.*\$ZBX_SERVER_PORT.*= ['\"]\)[^'\"]*\(['\"];\)/\1${SERVER_PORT}\2/"	$CONF

	if grep -q '$DB\[.*SERVERS.*\]' "$CONF"; then
		echo setting $DBPassword...
		sed -i "s/\('NAME'\s*=>\s*\)'.*'/\1'Server 1'/"		$CONF
		sed -i "s/\('SERVER'\s*=>\s*\)'.*'/\1'$DBHost'/"	$CONF
		sed -i "s/\('DATABASE'\s*=>\s*\)'.*'/\1'$DBName'/"	$CONF
		sed -i "s/\('USER'\s*=>\s*\)'.*'/\1'$DBUser'/"		$CONF
		sed -i "s/\('PASSWORD'\s*=>\s*\)'.*'/\1'$DBPassword'/"	$CONF

		set -x
		sed -i "s|\('URL'\s*=>\s*\).*|\1'http://${WEB_IP}/${O_URLPATH}/ui/',|"	$CONF
		set +x
	fi
fi

CONF="rsm-api/example/config"
if [[ ! -f $CONF && -f $CONF.example ]]; then
	cp -v $CONF.example $CONF
fi
if [ -f $CONF ]; then
	sed -i "s|\(.*FRONTEND_URL=\).*|\1\"http://${WEB_IP}/${O_URLPATH}/ui\"|"       $CONF
	sed -i "s|\(.*FORWARDER_URL=\).*|\1\"http://${WEB_IP}/${O_URLPATH}/rsm-api\"|" $CONF
fi


# set up config for rsm-api
CONF="rsm-api/config.php"

if [ -f $CONF.example ]; then
	alerts_dir="/tmp/rsm-tests/alerts"

	cp -v $CONF.example $CONF

	sed -i "s|\(.*'database'.*=> \).*|\1'${DBName}',|"                   $CONF
	sed -i "s|\(.*'url'.*=> \).*|\1'http://${WEB_IP}/${O_URLPATH}/ui',|" $CONF
	sed -i "s|/var/log/zabbix/alerts|$alerts_dir|"                       $CONF
fi

# add key=value to the config files
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

repo=$(basename -s .git `git config --get remote.origin.url`)

if [ -z "$repo" ]; then
	echo "cannot identify git repository (are you in the git repo directory?)"
	exit 1
fi

[ "$repo" = "icann" ] || exit 0

target_dir="$(pwd)"

pushd /opt > /dev/null
if [ ! -d "$target_dir/opt/zabbix/sla" ]; then
	[ -d zabbix/sla ] && $ECHO mv zabbix/sla "$target_dir/opt/zabbix"
	[ -d zabbix/cache ] && $ECHO mv zabbix/cache "$target_dir/opt/zabbix"
fi

rm -f zabbix
ln -sf "$target_dir/opt/zabbix"
popd > /dev/null

pushd /opt/zabbix > /dev/null
ln -sf "$target_dir/bin"
popd > /dev/null

if [ -d rsm-api ]; then
	find . -name .htaccess | xargs rm
	cat << EOF > rsm-api/.htaccess
RewriteEngine  on

RewriteRule "^index.php$" - [L]
RewriteRule "^(.*)$" "index.php" [B,L]
EOF
#<Limit GET POST PUT OPTIONS DELETE PATCH HEAD>
#    Require all granted
#</Limit>
fi

CONF=opt/zabbix/scripts/rsm.conf

if [ -f $CONF.example ]; then
	cp $CONF{.example,}

	set_ini $CONF server_1 za_url     http://${WEB_IP}/${O_URLPATH}/ui
	set -x
	grep db_name /home/vl/tmp/rsm-tests/src/$CONF
	set_ini $CONF server_1 db_name    $DBName
	grep db_name /home/vl/tmp/rsm-tests/src/$CONF
	set +x
	set_ini $CONF server_1 db_user    zabbix
	set_ini $CONF server_1 dbpassword password

	set_ini $CONF slv zport              $SERVER_PORT
	set_ini $CONF slv max_cycles_dns     1000
	set_ini $CONF slv max_cycles_dnssec  1000
	set_ini $CONF slv max_cycles_rdds    500
	set_ini $CONF slv max_cycles_rdap    500
	set_ini $CONF slv reconfig_duration  5

	set_ini $CONF sla_api output_dir /opt/zabbix/sla

	set_ini $CONF data_export output_dir /opt/zabbix/export
fi

#db-exec.sh "update globalmacro set value='192.112.36.4,192.58.128.30,198.41.0.4,198.97.190.53,192.33.4.12,170.247.170.2' where macro='{\$RSM.IP4.ROOTSERVERS1}'"
#db-exec.sh "update globalmacro set value='1' where macro like '{\$RSM.%.PROBE.ONLINE}'"
#db-exec.sh "update globalmacro set value='2' where macro like '{\$RSM.%.MIN.PROBE.ONLINE}'"
#db-exec.sh "update globalmacro set value=1 where macro like '%INCIDENT%'"
