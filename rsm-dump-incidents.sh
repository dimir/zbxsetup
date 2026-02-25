#!/usr/bin/env bash

declare select_fields="distinct case when r.eventid is null then 'Active' else 'Resolved' end as state,e.eventid,r.eventid as r_eventid,h.host,e.name,from_unixtime(e.clock) as clock,case when r.clock<>0 then from_unixtime(r.clock) else NULL end as r_clock,i.key_,a.action as ack_action,from_unixtime(a.clock) as ack_clock,s.status as fp,from_unixtime(s.clock) as fp_clock"
declare order="order by clock,r_clock,h.host"
declare clock_field="e.clock"
declare -a search_columns=(h.host i.key_ e.name)

(
	source .rsm-dump

	db-exec.sh "
		select $select_fields
		from events e
			left join event_recovery    er on er.eventid=e.eventid
			left join events             r on r.eventid=er.r_eventid
			left join acknowledges       a on a.eventid=e.eventid
			left join rsm_false_positive s on s.eventid=e.eventid
			left join triggers           t on t.triggerid=e.objectid and e.object=0 and e.source=0
			left join functions          f on f.triggerid=t.triggerid
			left join items              i on i.itemid=f.itemid
			left join hosts              h on h.hostid=i.hostid
		where e.name like '% is down' and (e.value=1 ${time_cond}${ptrn_cond})${order}" -t
) 2>&1 | grep -v '^\['
