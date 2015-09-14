#!/bin/bash

set -f # do not expand wildcards

script_usage()
{
    echo -e "\t-p\t\tconnect to proxy DB"
}

. .zbx

SQL=
DB="$O_DBNAME"

if [ "$1" = "-p" ]; then
    shift
    DB="$O_PRX_DBNAME"
fi

interactive=1
if [ $# -gt 0 ]; then
    interactive=0
    SQL="$@"
    shift
fi

if [ $interactive -eq 1 ]; then
    exec_sql "$DB" "interactive console" "$DB"
else
    exec_sql "$DB" "$SQL" "$DB" < <(echo "$SQL")
fi
