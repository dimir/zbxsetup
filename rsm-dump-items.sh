#!/usr/bin/env bash

declare select_fields="h.host,left(i.key_,30),s.itemid,concat(from_unixtime(s.clock), ' (', s.clock, ')') as clock,cast(round(s.value, 3) as double) as value"
declare order="order by h.host,i.key_,s.clock"
declare clock_field="s.clock"
declare -a search_columns=(h.host i.key_)

(
	source .rsm-dump

	db-exec.sh "select case when i.status=0 then 'Enabled' when i.status=1 then 'Disabled' end as 'status',h.host,left(i.key_, 30) AS key_,i.itemid,case when i.value_type=0 then 'FLOAT' when i.value_type=1 then 'STR' when i.value_type=3 then 'INT' when i.value_type=4 then 'TEXT' else i.value_type end as type,l.value as lastvalue
			from items i
			left join hosts h on h.hostid=i.hostid
			left join lastvalue l on l.itemid=i.itemid
			where i.templateid is not null
				and h.status in (0,1)
				${ptrn_cond}
			order by h.host,i.key_" -t
) 2>&1 | grep -v '^\['
