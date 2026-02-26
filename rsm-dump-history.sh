#!/usr/bin/env bash

declare select_fields="h.host,i.key_,s.itemid,concat(from_unixtime(s.clock), ' (', s.clock, ')') as clock,s.value"
declare order="order by h.host,i.key_,s.clock"
declare clock_field="s.clock"
declare -a search_columns=(h.host i.key_)

(
	source .rsm-dump

	declare cond
	for i in history_uint history; do
		echo "  $i:"
		cond="${ptrn_cond}"
		[[ $i =~ lastvalue ]] || cond+="${time_cond}"
		db-exec.sh "select ${select_fields}
				from ${i} s,items i,hosts h,hstgrp g,hosts_groups hg
				where hg.hostid=h.hostid
					and hg.groupid=g.groupid
					and h.hostid=i.hostid
					and i.itemid=s.itemid
					and g.groupid in ($TLDS,$PMON,$PRES) ${cond}${order}" -t
	done
) 2>&1 | grep -v '^\['
