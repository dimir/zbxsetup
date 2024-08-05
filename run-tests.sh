#!/usr/bin/env bash

TESTS_DIR=tmp/rsm-tests
TESTS_DIR_FULL=~/${TESTS_DIR}
TESTS_LOG=/tmp/rsm-tests.log
FW_DIR=${TESTS_DIR_FULL}/src/automated-tests/framework
WEB_IP=192.168.6.85

exec &> >(tee  $TESTS_LOG)

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

		ln -sf ${TESTS_DIR_FULL}/src/opt/zabbix/scripts/CSlaReport.php ${TESTS_DIR_FULL}/src/ui/include/classes/services/CSlaReport.php
	else
		# keep default file
		default_file="rsm.conf.default"
		if [ -f ${TESTS_DIR_FULL}/src/opt/zabbix/scripts/$default_file ]; then
			mv -v ${TESTS_DIR_FULL}/src/opt/zabbix/scripts/$default_file /tmp
		fi

		for i in automated-tests ui rsm-api opt; do
			rm -rf ${TESTS_DIR_FULL}/src/$i
			cp -a $(pwd)/$i ${TESTS_DIR_FULL}/src
		done

		mv /tmp/$default_file ${TESTS_DIR_FULL}/src/opt/zabbix/scripts/
	fi
fi

pushd ${TESTS_DIR_FULL}/src > /dev/null

# disable SLV scripts
sudo opt/zabbix/scripts/setup-cron.pl --disable

# stop server/proxy
pkill -f 'zabbix_(server|proxy)'

if [ $OPT_REBUILD -eq 1 ]; then
	[ -f Makefile ] && make -s distclean

	mkdir -p ${TESTS_DIR_FULL}
	mkdir -p ${TESTS_DIR_FULL}/build
	mkdir -p ${TESTS_DIR_FULL}/logs
	mkdir -p ${TESTS_DIR_FULL}/db_dumps
	mkdir -p ${TESTS_DIR_FULL}/sock
fi

if [ $OPT_SOURCES -eq 1 ]; then
	. .zbx

	# this will set up basic configuration, we'll need to tweak some of them later
	cnf-setup.sh -t m -n dimir_rsm_tests -r ${TESTS_DIR}/src

	if [ $OPT_REBUILD -eq 1 ]; then
		db-drop.sh
	fi

	webpath="${TESTS_DIR}/src/ui"
	rsmapipath="${TESTS_DIR}/src/rsm-api"
	alerts_dir="/tmp/alerts"

	mkdir -p $alerts_dir

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
	sed -i 's,^db_name=.*,db_name='${DBName}',g'                                       "$CF"
	sed -i 's,^db_username=.*,db_username='${DBUser}',g'                               "$CF"
	sed -i 's,^db_password=.*,db_password='${DBPassword}',g'                           "$CF"

	sed -i -rz 's,\[frontend\]\nurl=,[frontend]\nurl=http://'${WEB_IP}'/'$webpath','   "$CF"
	sed -i -rz 's,\[rsm-api\]\nurl=,[rsm-api]\nurl=http://'${WEB_IP}'/'$rsmapipath','  "$CF"
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

[ -f test-results.xml ] || exit

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
