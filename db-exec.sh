#!/bin/bash

set -f # do not expand wildcards

DIR="$(dirname "$(readlink -f "$0")")"
ZBX_DEFAULTS="${DIR}/.zbx-defaults"

script_usage()
{
	echo -e "\t-p\t\tconnect to proxy DB"
	echo -e "\t*\t\tadditional parameters to the database"
}

#. .zbx

defaults=(
	O_DB     "m"
	O_DBHOST "mariadb"
	O_DBNAME "zabbix"
	O_DBUSER "zabbix"
	O_DBPASS "zabbix"
	O_DEBUG  "0"
)

eval_defaults()
{
    n=0
    while [ $n -lt ${#defaults[*]} ]; do
	o=${defaults[$n]}
	v=$(/bin/grep "$o=" $ZBX_DEFAULTS | sed "s|^$o=\([^[:space:]]*\).*$|\1|")
	((n+=2))
	export $o=$v
    done
}

eval_defaults

exec_sql()
{
    db_name="$1"
    shift
    cmd="$1"
    shift

    if [ "p" = "$O_DB" ]; then
        ADDOPTS=
	[ "$O_DEBUG" = "1" ] && ADDOPTS="-a"
	export PGPASSWORD="${O_DBPASS}"
	CMD="psql $ADDOPTS -h $O_DBHOST -v ON_ERROR_STOP=1 -q -U $O_DBUSER"
    elif [ "m" = "$O_DB" ]; then
        export MYSQL_PWD="${O_DBPASS}"
        ADDOPTS=
	[ "$O_DEBUG" = "1" ] && ADDOPTS="-v"
	CMD="mysql $ADDOPTS -h $O_DBHOST -u $O_DBUSER"
#	CMD="mysql $ADDOPTS -u $O_DBUSER -p$O_DBPASS -t"
    else
	echo unsupported db type: $O_DB
	exit
    fi

    msg="[$O_DB:$O_DBUSER@$O_DBHOST"
    [ -n "$db_name" ] && msg="$msg:$db_name"
    msg="$msg] $cmd"

    >&2 echo $msg

    $CMD "$@"
}

SQL=
DB="$O_DBNAME"

interactive=1
while [ -n "$1" ]; do
	case "$1" in
		-p)
			DB="$O_PRX_DBNAME"
			;;
		*)
			SQL="$1"
			shift
			interactive=0
			break
			;;
	esac
	shift
done

if [ $interactive -eq 1 ]; then
	exec_sql "$DB" "interactive console" "$DB" "$@"
else
	exec_sql "$DB" "$SQL" "$DB" "$@" < <(echo "$SQL")
fi
