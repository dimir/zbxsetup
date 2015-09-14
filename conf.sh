#!/bin/bash

script_usage()
{
    echo -e "\t\t\tadditional options to ./configure"
}

. .zbx

DBPFX=
if [ "p" = $O_DB ]; then
    DBPFX=postgre # 2.0 and later
    if [ 18 -eq $O_VER ]; then
	DBPFX=pg
    fi
elif [ "m" = $O_DB ]; then
    DBPFX=my
else
    usage
fi

opts="--prefix=$(pwd) --with-${DBPFX}sql --with-net-snmp --enable-agent --enable-server --with-libcurl $@"
[ 1 -eq $O_PRX ] && opts="$opts --enable-proxy"

cmd="./configure $opts"

CFLAGS_basic="$CFLAGS -Wall -Wunused -Werror=implicit-function-declaration \
-Wpointer-to-int-cast -Wbad-function-cast -Wint-to-pointer-cast"

# should work with gcc-4.4
CFLAGS_extra="-Wstrict-overflow=5 -pedantic -Wextra \
-Waggregate-return -Wattributes -Wpadded \
-Wbuiltin-macro-redefined -Wcast-align -Wcast-qual -Wconversion \
-Wcoverage-mismatch -Wdeclaration-after-statement -Wdeprecated \
-Wdeprecated-declarations -Wdisabled-optimization  -Wdiv-by-zero \
-Wendif-labels -Wfloat-equal \
-Wformat-contains-nul -Wformat-extra-args -Wformat-nonliteral \
-Wformat-security -Wformat-y2k -Wformat-zero-length -Wimplicit \
-Winit-self -Winline -Winvalid-pch -Wlogical-op \
-Wlong-long -Wmissing-declarations -Wmissing-format-attribute \
-Wmissing-include-dirs -Wmissing-noreturn -Wmissing-prototypes \
-Wmudflap -Wmultichar -Wnested-externs -Wnormalized=nfc \
-Wold-style-definition -Woverflow -Woverlength-strings -Wpacked \
-Wpacked-bitfield-compat -Wpointer-arith \
-Wpragmas -Wredundant-decls -Wshadow \
-Wstack-protector -Wstrict-prototypes -Wswitch-default -Wswitch-enum \
-Wsync-nand -Wtraditional-conversion -Wundef \
-Wunsafe-loop-optimizations -Wvariadic-macros -Wvla -Wwrite-strings"

# additional, newer gcc
CFLAGS_extra_new="-Wcpp -Wdouble-promotion -Wfree-nonheap-object \
-Winvalid-memory-model -Wjump-misses-init -Wstack-usage=8192 \
-Wsuggest-attribute=pure -Wsuggest-attribute=const \
-Wsuggest-attribute=noreturn -Wtrampolines \
-Wunsuffixed-float-constants -Wvector-operation-performance"

if [ $O_DEBUG -eq 1 ]; then
    echo
    echo DEBUG ENABLED
    echo
    CFLAGS="$CFLAGS_basic -DDEBUG -g -O0"
else
    echo
    echo DEBUG DISABLED
    echo
    CFLAGS="$CFLAGS_basic -DNDEBUG -O2"
fi
export CFLAGS

echo running CFLAGS=$CFLAGS $cmd
$cmd >/dev/null
