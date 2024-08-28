#!/usr/bin/env bash

from=
till=
service=

select_fields="distinct case when p.r_eventid is null then 'Active' else 'Resolved' end as state,p.eventid,p.r_eventid,h.host,from_unixtime(p.clock) as clock,case when p.r_clock<>0 then from_unixtime(p.r_clock) else NULL end as r_clock,p.name,i.key_,a.action as ack_action,from_unixtime(a.clock) as ack_clock,s.status as fp,from_unixtime(s.clock) as fp_clock"
order="order by p.clock,p.r_clock"

(
	while [ -n "$1" ]; do
		if [[ "$1" = "-h" || "$1" = "--help" ]]; then
			echo "usage: $0 <options>"
			echo
			echo "Options:"
			echo "<from>    - in format 0000-00-00 00:00:00 (optional)"
			echo "<till>    - in format 0000-00-00 00:00:00 (optional)"
			echo "<pattern> - search pattern that will be applied to an item key and a host name"
			exit 1
		fi

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
			time_cond="and p.clock between unix_timestamp('$from') and unix_timestamp('$till') "
		else
			time_cond="and p.clock>=unix_timestamp('$from') "
		fi
	fi

	ptrn_cond=
	if [ -n "$service" ]; then
		service=${service^^}
		ptrn_cond="and p.name='$service service is down' "
	else
		ptrn_cond="and p.name like '% service is down' "
	fi

	db-exec.sh "
		select $select_fields
		from problem p
			left join acknowledges       a on a.eventid=p.eventid
			left join rsm_false_positive s on s.eventid=p.eventid
			left join triggers           t on t.triggerid=p.objectid and p.object=0 and p.source=0
			left join functions          f on f.triggerid=t.triggerid
			left join items              i on i.itemid=f.itemid
			left join hosts              h on h.hostid=i.hostid
		where 1=1 ${time_cond}${ptrn_cond}${order}"
) 2>&1 | grep -v '^\['
