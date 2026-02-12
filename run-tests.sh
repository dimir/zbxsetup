#!/usr/bin/env bash

TESTS_DIR=tmp/rsm-tests
TESTS_DIR_FULL=~/${TESTS_DIR}
TESTS_LOG=/tmp/rsm-tests.log
FW_DIR=${TESTS_DIR_FULL}/src/automated-tests/framework
CWD=$(pwd)

err()
{
	echo "ERR: $*"
	exit 1
}

cleanup()
{
	cd ${CWD}

	# restore configuration
	cnf-setup.sh -a $webaddr -r $urlpath -n $dbname -p $proxy -t $dbtype
}

exec &> >(tee $TESTS_LOG)

usage()
{
	if [ -n "$1" ]; then
		echo "Error: "$*
	fi

	echo "Usage: $0 <-d directory> [-p pattern] [-s] [-r] [-- <additional options to run-tests.pl>]"
	echo "    -d <directory>    test case directory (e. g. simple-check)"
	echo "    -p <pattern>      test case file pattern (e. g. '003-*.txt')"
	echo "    -s                only copy the automated test files"
	echo "    -r                copy and rebuild everything (implies -s)"

	exit 1
}

OPT_TCDIR=
OPT_TCPTRN=
OPT_SOURCES=0
OPT_REBUILD=0
OPT_ADDOPTS=

while [ -n "$1" ]; do
	case "$1" in
		-d)
			shift
			OPT_TCDIR=$1
			;;
		-p)
			shift
			OPT_TCPTRN=$1
			;;
		-s)
			OPT_SOURCES=1
			;;
		-r)
			OPT_REBUILD=1
			OPT_SOURCES=1
			;;
		--)
			shift
			if [ $# -eq 0 ]; then
				usage
			fi
			
			while [ $# -gt 0 ]; do
				OPT_ADDOPTS+="$1 "
				if [ $# -gt 1 ]; then
					shift
				else
					break
				fi
			done			
			;;
		-h)
			usage
			;;
		*)
			usage "unexpected parameter \"$1\""
			;;
	esac
	shift
done

if [ -z "$OPT_TCDIR" ]; then
	usage "you must specify option \"-d\""
fi

if [ $OPT_SOURCES -eq 1 ]; then
	mkdir -p ${TESTS_DIR_FULL}/src

	if [ ! -d automated-tests/framework ]; then
		echo "please change directory to git repo root"
		exit 1
	fi

	if [ $OPT_REBUILD -eq 1 ]; then
		rm -rf ${TESTS_DIR_FULL}/src
		cp -a $(pwd) ${TESTS_DIR_FULL}/src

		chown -R zabbix ${TESTS_DIR_FULL}/src/*
	else
		# do not add "database" to the list as "make dbschema" might not be run locally
		for i in automated-tests ui rsm-api opt probe-scripts; do
			rm -rf ${TESTS_DIR_FULL}/src/$i
			cp -a $(pwd)/$i ${TESTS_DIR_FULL}/src/
		done
	fi

	ln -sf ${TESTS_DIR_FULL}/src/opt/zabbix/scripts/CSlaReport.php ${TESTS_DIR_FULL}/src/ui/include/classes/services/CSlaReport.php
fi

# disable SLV scripts
sudo opt/zabbix/scripts/setup-cron.pl --disable

# stop server/proxy
pkill -f 'bin/zabbix_(server|proxy)'

if [ $OPT_REBUILD -eq 1 ]; then
	[ -f Makefile ] && make -s distclean

	mkdir -p ${TESTS_DIR_FULL}
	mkdir -p ${TESTS_DIR_FULL}/build
	mkdir -p ${TESTS_DIR_FULL}/logs
	mkdir -p ${TESTS_DIR_FULL}/db_dumps
	mkdir -p ${TESTS_DIR_FULL}/sock
fi

chmod 777 ${TESTS_DIR_FULL}

# remember current zbxsetup configuration
webaddr=$(cnf-setup.sh -- -v 2>&1 | grep -E 'WEBADDR' --color=none | sed 's/WEBADDR=//')                ; [ -z "$webaddr" ] && err "cannot get webaddr"
urlpath=$(cnf-setup.sh -- -v 2>&1 | grep -E 'URLPATH' --color=none | sed 's/URLPATH=//')                ; [ -z "$urlpath" ] && err "cannot get urlpath"
dbname=$(cnf-setup.sh -- -v 2>&1 | grep -E 'DBName' --color=none | sed 's/DBName=//' | sort -u)         ; [ -z "$dbname" ] && err "cannot get dbname"
proxy=$(cnf-setup.sh -- -v 2>&1 | grep -E 'proxy=' --color=none | sed 's/proxy=//')                     ; [ -z "$proxy" ] && err "cannot get proxy"
dbtype=$(cnf-setup.sh -- -v 2>&1 | grep -E 'dbtype=' --color=none | sed 's/dbtype=//')                  ; [ -z "$dbtype" ] && err "cannot get dbtype"
proxy_dbtype=$(cnf-setup.sh -- -v 2>&1 | grep -E 'proxy_dbtype=' --color=none | sed 's/proxy_dbtype=//'); [ -z "$proxy_dbtype" ] && err "cannot get proxy_dbtype"

echo webaddr=$webaddr
echo urlpath=$urlpath
echo dbname=$dbname
echo proxy=$proxy
echo dbtype=$dbtype
echo proxy_dbtype=$proxy_dbtype

pushd ${TESTS_DIR_FULL}/src > /dev/null

if [ $OPT_SOURCES -eq 1 ]; then
	# this will set up basic configuration, we'll need to tweak some of them later
	cnf-setup.sh -a $webaddr -r ${TESTS_DIR}/src -n dimir_rsm_tests -p 0 -t m

	trap cleanup EXIT

	source .zbx

	cp -v -f /opt/zabbix/scripts/rsm.conf /opt/zabbix/scripts/rsm.conf.default

	if [ $OPT_REBUILD -eq 1 ]; then
		db-drop.sh
	fi

	webpath="${urlpath}/ui"
	rsmapipath="${urlpath}/rsm-api"
	alerts_dir="/tmp/rsm-tests/alerts"

# This causes more mess because it's recreated by cnf-setup.sh and then test framework, let's leave it to test framework
#	mkdir -p $alerts_dir
#	sudo chown www-data $alerts_dir

	# set up config for tests
	CF="${FW_DIR}/tests.conf"

	cp "$CF.example" "$CF"

	sed -i 's,^source_dir=.*,source_dir='${TESTS_DIR_FULL}'/src,g'                     "$CF"
	sed -i 's,^build_dir=.*,build_dir='${TESTS_DIR_FULL}'/build,g'                     "$CF"
	sed -i 's,^logs_dir=.*,logs_dir='${TESTS_DIR_FULL}'/logs,g'                        "$CF"
	sed -i 's,^alerts_dir=.*,alerts_dir='$alerts_dir',g'                               "$CF"
	sed -i 's,^db_dumps_dir=.*,db_dumps_dir='${TESTS_DIR_FULL}'/db_dumps,g'            "$CF"

	sed -i 's,^socket_dir=.*,socket_dir='${TESTS_DIR_FULL}',g'                         "$CF"
	sed -i 's,^pid_file=.*,pid_file='${TESTS_DIR_FULL}'/zabbix_server.pid,g'           "$CF"
	sed -i 's,^db_host=.*,db_host='${O_DBHOST}',g'                                     "$CF"
	sed -i 's,^db_name=.*,db_name='${O_DBNAME}',g'                                     "$CF"
	sed -i 's,^db_username=.*,db_username='${O_DBUSER}',g'                             "$CF"
	sed -i 's,^db_password=.*,db_password='${O_DBPASS}',g'                             "$CF"

	sed -i -rz 's,\[frontend\]\nurl=,[frontend]\nurl=http://'$webaddr'/'$webpath','   "$CF"
	sed -i -rz 's,\[rsm-api\]\nurl=,[rsm-api]\nurl=http://'$webaddr'/'$rsmapipath','  "$CF"
fi

pushd ${FW_DIR} > /dev/null

if [ ! -d "../test-cases/${OPT_TCDIR}" ]; then
	usage "specified directory \"$OPT_TCDIR\" does not exist under \"test-cases\" directory"
fi

if [ $OPT_REBUILD -eq 1 ]; then
	ADDOPTS="$OPT_ADDOPTS --build-server"
else
	ADDOPTS="$OPT_ADDOPTS --skip-build"
fi

if [ -z "$OPT_TCPTRN" ]; then
	TZ=UTC ./run-tests.pl ${ADDOPTS} --test-case-dir ../test-cases/$OPT_TCDIR
else
	TZ=UTC ./run-tests.pl ${ADDOPTS} --test-case-file ../test-cases/$OPT_TCDIR/$OPT_TCPTRN
fi

if [ ! -f test-results.xml ]; then
	echo "No file test-results.xml found in $(pwd)!"
	exit 1
fi

total=$(grep --color=none 'failures="' test-results.xml | sed -r 's/.* tests="([[:digit:]]+)" .*/\1/')
failures=$(grep --color=none 'failures="' test-results.xml | sed -r 's/.* failures="([[:digit:]]+)" .*/\1/')

echo
if [ $total -eq 0 ]; then
	echo "No tests performed"
else
	if [ $failures -eq 0 ]; then
		if [ $total -eq 1 ]; then
			echo "Test successful"
		else
			echo "All $total tests successful"
		fi
	else
		EC=1
		if [ $failures -eq $total ]; then
			if [ $total -eq 1 ]; then
				echo "Test failed:"
			else
				echo "All $total tests failed:"
			fi
		else
			echo "$failures tests failed out of total $total:"
		fi
		grep --color=none '<failure>test case failed' test-results.xml -B1 | grep --color=none '<testcase name' | sed -r 's/.*testcase name="([^"]+)" .*/    \1/'
	fi
fi

echo "Test results available in file $(pwd)/test-results.xml"
echo "Full output is available in file $TESTS_LOG"

popd > /dev/null
popd > /dev/null

exit $EC
