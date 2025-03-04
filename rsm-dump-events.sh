#!/usr/bin/env bash

declare select_fields="distinct case when e.value=1 then 'PROBLEM' else 'RESOLVED' end as value,e.eventid,h.host,from_unixtime(e.clock) as clock,e.name,i.key_,a.action as ack_action,from_unixtime(a.clock) as ack_clock,e.severity"
declare order="order by h.host,e.name,e.clock"
declare clock_field="e.clock"
declare -a search_columns=(h.host i.key_ e.name)

(
	source .rsm-dump

	db-exec.sh "
		select ${select_fields}
		from events e
			left join acknowledges a on a.eventid=e.eventid
			left join triggers     t on t.triggerid=e.objectid and e.object=0 and e.source=0
			left join functions    f on f.triggerid=t.triggerid
			left join items        i on i.itemid=f.itemid
			left join hosts        h on h.hostid=i.hostid
		where h.host is not null ${time_cond}${ptrn_cond}${order}" -t
) 2>&1 | grep -v '^\['
