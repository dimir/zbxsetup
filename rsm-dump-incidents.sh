#!/usr/bin/env bash

from=
till=
service=

select_fields="distinct e.eventid,h.host,from_unixtime(e.clock) as clock,e.name,e.value,i.key_"
order="order by h.host,e.name,e.clock"

(
	while [ -n "$1" ]; do
		if [[ "$1" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
			if [ -z "$from" ]; then
				echo "from: $1"
				from="$1"
			elif [ -z "$till" ]; then
				echo "till: $1"
				till="$1"
			else
				echo "invalid parameter: $1"
				exit 1
			fi
		else
			echo "serv: $1"
			service="$1"
		fi
		shift
	done

	time_cond=
	if [ -n "$from" ]; then
		if [ -n "$till" ]; then
			time_cond="and e.clock between unix_timestamp('$from') and unix_timestamp('$till') "
		else
			time_cond="and e.clock>=unix_timestamp('$from') "
		fi
	fi

	ptrn_cond=
	if [ -n "$service" ]; then
		service=${service^^}
		ptrn_cond="and e.name='$service service is down' "
	else
		ptrn_cond="and e.name like '% service is down' "
	fi

	db-exec.sh "select $select_fields from events e,triggers t,functions f,items i,hosts h where e.objectid=t.triggerid and t.triggerid=f.triggerid and f.itemid=i.itemid and i.hostid=h.hostid ${time_cond}${ptrn_cond}${order}"
) 2>/dev/null | less
