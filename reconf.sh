#!/bin/bash

die()
{
    echo -n FAIL
    [ -n "$1" ] && echo -n ": "
    echo $*
    exit 1
}

script_usage()
{
    echo -e "\t-n\t\tdo not setup database"
    echo -e "\t-c\t\tcontinue, jump to setting up the database"
    echo -e "\t-a\t\tadditional options to configure script (e. g. -a \"--enable-ipv6 --with-libxml2\")"
    echo -e "\t-x\t\tpass \"-x\" to db-setup.sh, to skip extra db modifications"
}

spinner()
{
    # one cycle is about half of the second
    cycles=8

    chars=('/' '-' '\\' '|')
    for ((i=0; i<6; i++)); do
	cur=0
	while [ $cur -lt ${#chars[*]} ]; do
	    echo -ne "${chars[$cur]}\033[1D"
	    cur=$((cur+1))
	    sleep .1
	done
    done
    echo " "
}

opts=
verspecified=0

for param; do
    if [ "$param" = "-v" ]; then
	verspecified=1
	break
    fi
done

ver=
if [ $verspecified -eq 0 ]; then
    istrunk=$(istrunk.sh)
    [ $? -ne 0 ] && die "cannot verify current directory"

    if [ "Yes" = "$istrunk" ]; then
	ver="trunk"
	opts="-v 20"
    else
	ver="1.8"
	opts="-v 18"
    fi
fi

. .zbx

DB_SETUP=1
DB_SETUP_OPTS=
CONTIN=0

while [ -n "$1" ]; do
	case "$1" in
		-n)
			DB_SETUP=0
			;;
		-c)
			CONTIN=1
			;;
		-a)
			shift
			ADDOPTS="$1"
			;;
		-x)
			DB_SETUP_OPTS="-- -x"
			;;
		*)
			echo "$1: unknown option"
			usage
			;;
	esac
	shift
done

msg="Reconfiguring for $O_DBHOST:$ver:$DB_TYPE:$DBName"
[ $O_PRX -eq 1 ] && msg="$msg:$PRX_DBName"
echo -n "$msg "
spinner

if [ $CONTIN -eq 0 ]; then
	[ -f configure ] || ./bootstrap.sh || die
	conf.sh $opts -- $ADDOPTS || die
	cnf-setup.sh || die
	make -j2 dbschema || die
fi
if [ $DB_SETUP -eq 1 ]; then
	db-setup.sh $DB_SETUP_OPTS || die
fi
make -j2 install > /dev/null || die
echo OK
