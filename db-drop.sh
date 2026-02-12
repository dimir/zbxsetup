#!/bin/bash

script_usage()
{
    echo -e "\t-p\t\tonly drop proxy DB"
}

. .zbx

onlyproxy=0
[ "$1" = "-p" ] && onlyproxy=1

if [ $O_PRX -eq 1 ]; then
	if [[ $PRX_DBName =~ ^/ ]]; then
		rm -fv $PRX_DBName
	else
		DB="$PRX_DBName"
		exec_sql $DB "drop database" < <(echo "drop database if exists $DB")
	fi
elif [ $onlyproxy -eq 1 ]; then
	msg "no proxy db specified"
fi

[ $onlyproxy -eq 1 ] && exit

DB="$DBName"
exec_sql $DB "drop database" < <(echo "drop database if exists $DB")
