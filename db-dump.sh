#!/bin/bash

script_usage()
{
    echo -e "\t-p\t\tconnect to proxy DB"
}

dump()
{
	db="$1"
	shift

	CMD=
	if [ "m" = "$O_DB" ]; then
		CMD="mysqldump -u $O_DBUSER -h $DBHost $db"
	else
		echo "unsupported db type: $O_DB"
		exit 1
	fi

	$CMD "$@"
}

. .zbx

DB="$O_DBNAME"

if [ "$1" = "-p" ]; then
    shift
    DB="$O_PRX_DBNAME"
fi

dump $DB
