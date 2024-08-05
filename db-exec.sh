#!/bin/bash

set -f # do not expand wildcards

script_usage()
{
	echo -e "\t-p\t\tconnect to proxy DB"
	echo -e "\t*\t\tadditional parameters to the database"
}

. .zbx

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
