#!/bin/bash

if [ -f conf/zabbix_agentd.conf ]; then
    echo 'Yes'
elif [ -f misc/conf/zabbix_agentd.conf ]; then
    echo 'No'
else
    echo 'Eh?!' && exit 1
fi
