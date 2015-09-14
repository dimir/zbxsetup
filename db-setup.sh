#!/bin/bash

script_usage()
{
    echo -e "\t-p\t\tonly setup proxy db";
    echo -e "\t-c\t\tonly create db, do not import anything";
}

PSQL="postgre" # 2.0, for images file
SCHEMA_SQL=
IMAGES_SQL=
DB_DIR=
CHARSET_CREATE=
DATA_SQL="create/data/data.sql" # 1.8
DB= # for output

export PGOPTIONS='-c client_min_messages=warning' # disable NOTICEs in case of PostgreSQL

. .zbx

onlyproxy=0
onlycreate=0
stop=0
while [ -n "$1" ]; do
    case "$1" in
        -p)
            onlyproxy=1
	    ;;
        -c)
            onlycreate=1
	    ;;
        -*)
            usage
            ;;
        *)
            stop=1
            break
            ;;
    esac
    [ $stop -eq 1 ] && break
    shift
done


[ 18 -eq "$O_VER" ] && PSQL="pg"

if [ "p" = "$O_DB" ]; then
    # PgSQL
    DB_DIR=postgresql
    SCHEMA_SQL="create/schema/postgresql.sql"
    IMAGES_SQL="create/data/images_${PSQL}sql.sql"
    CHARSET_CREATE="ENCODING 'UTF8'"
elif [ "m" = "$O_DB" ]; then
    # MySQL
    DB_DIR=mysql
    SCHEMA_SQL="create/schema/mysql.sql"
    IMAGES_SQL="create/data/images_mysql.sql"
    CHARSET_CREATE="character set utf8"
else
    echo unsupported db type: $O_DB
    exit 1
fi

if [ 20 -eq "$O_VER" ]; then
    SCHEMA_SQL="database/$DB_DIR/schema.sql"
    IMAGES_SQL="database/$DB_DIR/images.sql"
    DATA_SQL="database/$DB_DIR/data.sql"
fi

# proxy
if [ $O_PRX -eq 1 ]; then
    DB=$PRX_DBName
    exec_sql $DB "create database" < <(echo "create database $DB $CHARSET_CREATE")	|| exit
    if [ $onlycreate -eq 0 ]; then
	exec_sql $DB "import schema" $DB < $SCHEMA_SQL					|| exit
    fi
elif [ $onlyproxy -eq 1 ]; then
    msg "no proxy db specified"
fi

[ $onlyproxy -eq 1 ] && exit

DB=$DBName
exec_sql $DB "create database" < <(echo "create database $DB $CHARSET_CREATE")		|| exit
[ $onlycreate -eq 1 ] && exit
exec_sql $DB "import schema" $DB < $SCHEMA_SQL						|| exit

if [ $O_VER -eq 18 ]; then
    exec_sql $DB "import data" $DB < $DATA_SQL				|| exit
    exec_sql $DB "import images" $DB < $IMAGES_SQL			|| exit
else
    exec_sql $DB "import images" $DB < $IMAGES_SQL			|| exit
    exec_sql $DB "import data" $DB < $DATA_SQL				|| exit
fi

cmds=(
    "update media_type set smtp_server = 'mail.zabbix.com', smtp_helo = 'zabbix.com', smtp_email = 'dimir@zabbix.com' where description = 'Email'"
    "insert into media (mediaid, userid, mediatypeid, sendto, active, severity, period) values (1, 1, 1, 'vladimir.levijev@zabbix.com', 0, 63, '1-7,00:00-24:00;')"
    "update config set refresh_unsupported = 15, event_show_max=10, event_expire=1, event_ack_enable=0"
    "update users set autologout=0,rows_per_page=300"
)

if [ $O_VER -ne 18 ]; then
    cmds+=("update interface set port=11339")
fi

i=0
while [ "${cmds[$i]}" ]; do
    s=${cmds[$i]}
    exec_sql $DB "$s" $DB < <(echo "$s")				|| exit
    ((i++))
done
