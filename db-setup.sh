#!/bin/bash

script_usage()
{
	echo -e "\t-p\t\tonly setup proxy db";
	echo -e "\t-c\t\tonly create db, do not import anything";
	echo -e "\t-s\t\tonly create db, add schema but no data";
	echo -e "\t-x\t\tdo not apply extra modifications to db";
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
onlyschema=0
noextra=0
stop=0
while [ -n "$1" ]; do
	case "$1" in
		-p)
			onlyproxy=1
			;;
		-c)
			onlycreate=1
			;;
		-s)
			onlyschema=1
			;;
		-x)
			noextra=1
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
	CHARSET_CREATE="character set utf8 collate utf8_bin"
else
	echo "unsupported db type: $O_DB"
	exit 1
fi

if [ 20 -eq "$O_VER" ]; then
	SCHEMA_SQL="database/$DB_DIR/schema.sql"
	IMAGES_SQL="database/$DB_DIR/images.sql"
	DATA_SQL="database/$DB_DIR/data.sql"
fi

if [ $onlyproxy -eq 0 ]; then
	DB=$DBName
	exec_sql $DB "create database" < <(echo "create database $DB $CHARSET_CREATE")	|| exit
	[ $onlycreate -eq 1 ] && exit
	exec_sql $DB "import schema" $DB < $SCHEMA_SQL					|| exit
	[ $onlyschema -eq 1 ] && exit

	if [ $O_VER -eq 18 ]; then
		exec_sql $DB "import data" $DB < $DATA_SQL	|| exit
		exec_sql $DB "import images" $DB < $IMAGES_SQL	|| exit
	else
		exec_sql $DB "import images" $DB < $IMAGES_SQL	|| exit
		exec_sql $DB "import data" $DB < $DATA_SQL	|| exit
	fi
	declare -A macros=(
		['{$RSM.IP4.ROOTSERVERS1}']='193.0.14.129,192.5.5.241,199.7.83.42,198.41.0.4,192.112.36.4'
		['{$RSM.IP6.ROOTSERVERS1}']='2001:7fe::53,2001:500:2f::f,2001:500:9f::42,2001:503:ba3e::2:30,2001:500:12::d0d'
		['{$RSM.MONITORING.TARGET}']='registry'
		['{$RSM.RDAP.STANDALONE}']='1'
	)
	for macro in ${!macros[@]}; do
		exec_sql $DB "set global macro '${macro}'" $DB < <(echo "update globalmacro set value='${macros[${macro}]}' where macro='${macro}'") || exit
	done

	exec_sql $DB "set global macros '{$RSM.%.PROBE.ONLINE}'" $DB < <(echo "update globalmacro set value='1' where macro like '{\$RSM.%.PROBE.ONLINE}'") || exit
	exec_sql $DB "change item history period" $DB < <(echo "update items set history='1h' where history!='0'") || exit
fi

# proxy
if [ $O_PRX -eq 1 ]; then
	if [ $O_DBPRX = "s" ]; then
		> "${PRX_DBName}" || exit
		if [ $onlycreate -eq 0 ]; then
			sqlite3 "${PRX_DBName}" < "database/sqlite3/schema.sql"						|| exit
		fi
	else
		exec_sql "${PRX_DBName}" "create database" < <(echo "create database ${PRX_DBName} $CHARSET_CREATE")	|| exit
		if [ $onlycreate -eq 0 ]; then
			exec_sql "${PRX_DBName}" "import schema" "${PRX_DBName}" < $SCHEMA_SQL				|| exit
		fi
	fi
elif [ $onlyproxy -eq 1 ]; then
	msg "no proxy db specified"
fi

[ $noextra -eq 1 ] && exit

cmds=(
)

i=0
while [ "${cmds[$i]}" ]; do
	s=${cmds[$i]}
	exec_sql $DB "$s" $DB < <(echo "$s")	|| exit
	((i++))
done
