#!/usr/bin/env bash

ptrn=
from=
till=

select_fields="h.host,i.key_,s.itemid,concat(from_unixtime(s.clock), ' (', s.clock, ')') as clock,s.value"
order="order by h.host,i.key_,s.clock"

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
			echo "ptrn: $1"
			ptrn="$1"
		fi
		shift
	done

	time_cond=
	if [ -n "$from" ]; then
		if [ -n "$till" ]; then
			time_cond="and clock between unix_timestamp('$from') and unix_timestamp('$till') "
		else
			time_cond="and clock>=unix_timestamp('$from') "
		fi
	fi

	ptrn_cond=
	if [ -n "$ptrn" ]; then
		ptrn_cond="and (i.key_ like '%$ptrn%' or h.host like '%$ptrn%') "
	fi

	for i in history_uint history lastvalue lastvalue_str; do
		echo "  $i:"
		db-exec.sh "select $select_fields from $i s,items i,hosts h,hstgrp g,hosts_groups hg where hg.hostid=h.hostid and hg.groupid=g.groupid and h.hostid=i.hostid and i.itemid=s.itemid and g.groupid in (140,190)  ${time_cond}${ptrn_cond}${order}"
	done
) 2>&1 | grep -v '^\['
