#!/usr/bin/env bash

declare select_fields="h.host,i.key_,s.itemid,concat(from_unixtime(s.clock), ' (', s.clock, ')') as clock,s.value"
declare order="order by h.host,i.key_,s.clock"
declare clock_field="s.clock"
declare -a search_columns=(h.host i.key_)

(
	source .rsm-dump

	db-exec.sh "select case when i.status=0 then 'Enabled' when i.status=1 then 'Disabled' end as 'status',h.host,i.key_,i.itemid,case when i.value_type=0 then 'FLOAT' when i.value_type=1 then 'STR' when i.value_type=3 then 'INT' else i.value_type end as type
			from items i
			left join hosts h on h.hostid=i.hostid
			where i.templateid is not null
				${ptrn_cond}
			order by h.host,i.key_" -t

	declare cond
	for i in lastvalue lastvalue_str; do
		echo "  $i:"
		cond="${ptrn_cond}"
		[[ $i =~ lastvalue ]] || cond+="${time_cond}"
		db-exec.sh "select ${select_fields}
				from ${i} s,items i,hosts h,hstgrp g,hosts_groups hg
				where hg.hostid=h.hostid
					and hg.groupid=g.groupid
					and h.hostid=i.hostid
					and i.itemid=s.itemid
					and g.groupid in (120,130,140,190)
					${cond}
				${order}" -t
	done
) 2>&1 | grep -v '^\['
