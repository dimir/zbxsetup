#!/usr/bin/env bash

declare select_fields="h.host,i.key_,s.itemid,concat(from_unixtime(s.clock), ' (', s.clock, ')') as clock,cast(s.value as double) as value"
declare order="order by host,key_,clock"
declare clock_field="s.clock"
declare -a search_columns=(h.host i.key_)

(
	source .rsm-dump

	declare sql=""
	for i in history_uint history; do
		[ -n "$sql" ] && sql+=" union "

		declare fields="${select_fields}"

		[ $i = "history" ] && fields="${fields/cast(s.value as double)/round(s.value, 3)}"

		sql+="select ${fields}
				from ${i} s,items i,hosts h,hstgrp g,hosts_groups hg
				where hg.hostid=h.hostid
					and hg.groupid=g.groupid
					and h.hostid=i.hostid
					and i.itemid=s.itemid
					and g.groupid in ($TLDS,$PMON,$PRES) ${ptrn_cond}${time_cond}"
	done

	db-exec.sh "${sql}${order}" -t
) 2>&1 | grep -v '^\['
