#!/bin/bash

script_usage()
{
	echo -e "\t-t <target>\tspecify target: server/proxy"
	echo -e "\t\t\tadditional options to ./configure"
}

. .zbx

target=
addopts=
while [ -n "$1" ]; do
	case "$1" in
		-t)
			shift
			if [ -z "$1" ]; then
				usage
			fi
			target="$1"
			;;
		-*)
			usage
			;;
		*)
			addopts="${addopts} $1"
			;;
	esac
	shift
done

if [ -z "$target" ]; then
	echo "error: target must be specified"
	usage
fi

addopts="${addopts} --enable-$target"

dbtype=
if [ $target = "server" ]; then
	dbtype=$O_DB
else
	dbtype=$O_DBPRX
fi

if [ "p" = $dbtype ]; then
	addopts="${addopts} --with-postgresql"
	if [ 18 -eq $O_VER ]; then
		addopts="${addopts} --with-pgsql"
	fi
elif [ "m" = $dbtype ]; then
	addopts="${addopts} --with-mysql"
elif [ "s" = $dbtype ]; then
	addopts="${addopts} --with-sqlite3"
else
	usage
fi

opts="--prefix=$(pwd) --with-net-snmp --enable-agent --enable-ipv6 --with-libcurl --with-openssl --with-libpcre2 $addopts $@"

cmd="./configure $opts"

CFLAGS_basic="-Wformat-signedness -Wformat=2 -Wformat-truncation=2          \
-Wno-format-nonliteral -Werror=format-security -Werror=array-bounds         \
-Wall -Wextra -Wsign-compare -fstack-protector-all -fstack-protector-strong \
-fstack-check -g -O0 -Wshadow -Wsystem-headers -Wunused-value               \
-Wpointer-arith -Wempty-body -fstrict-aliasing -Wmissing-prototypes"

# should work with gcc-4.4
CFLAGS_extra="-Wstrict-overflow=5 -pedantic -Wextra                  \
-Wattributes -Wpadded                                                \
-Wbuiltin-macro-redefined -Wcast-align -Wcast-qual -Wconversion      \
-Wcoverage-mismatch -Wdeprecated                                     \
-Wdeprecated-declarations -Wdisabled-optimization  -Wdiv-by-zero     \
-Wendif-labels -Wfloat-equal                                         \
-Wformat-contains-nul -Wformat-extra-args -Wformat-nonliteral        \
-Wformat-security -Wformat-y2k -Wformat-zero-length -Wimplicit       \
-Winit-self -Winline -Winvalid-pch -Wlogical-op                      \
-Wlong-long -Wmissing-declarations -Wmissing-format-attribute        \
-Wmissing-include-dirs -Wmissing-noreturn -Wmissing-prototypes       \
-Wmudflap -Wmultichar -Wnested-externs -Wnormalized=nfc              \
-Wold-style-definition -Woverflow -Woverlength-strings -Wpacked      \
-Wpacked-bitfield-compat -Wpointer-arith                             \
-Wpragmas -Wredundant-decls -Wshadow                                 \
-Wstack-protector -Wstrict-prototypes -Wswitch-default -Wswitch-enum \
-Wsync-nand -Wtraditional-conversion -Wundef                         \
-Wunsafe-loop-optimizations -Wvariadic-macros -Wvla -Wwrite-strings"

# additional, newer gcc
CFLAGS_extra_new="-Wcpp -Wdouble-promotion -Wfree-nonheap-object \
-Winvalid-memory-model -Wjump-misses-init -Wstack-usage=8192     \
-Wsuggest-attribute=pure -Wsuggest-attribute=const               \
-Wsuggest-attribute=noreturn -Wtrampolines                       \
-Wunsuffixed-float-constants -Wvector-operation-performance"

if [ $O_DEBUG -eq 1 ]; then
    echo
    echo DEBUG ENABLED
    echo
    CFLAGS="$CFLAGS_basic $CFLAGS_extra $CFLAGS_extra_new -DDEBUG -g -O0"
else
    echo
    echo DEBUG DISABLED
    echo
    CFLAGS="$CFLAGS_basic -DNDEBUG"
fi

export CFLAGS

#export CFLAGS="-O1 -g -fno-omit-frame-pointer -gline-tables-only -fsanitize=address"
#export CC=clang
#export CXXFLAGS="-O1 -g -fno-omit-frame-pointer -gline-tables-only -fsanitize=address"
#export CXX=clang

echo running CFLAGS=$CFLAGS $cmd
$cmd >/dev/null
