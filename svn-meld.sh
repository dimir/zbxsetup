#!/bin/bash
#
# SVN Diff Wrapper for Meld
# KOG 2008-02
# http://www.nabble.com/How-to-use-meld-with-'svn-diff'-td16765244.html

[ -d /tmp/svndiff ] && chmod -R 777 /tmp/svndiff || mkdir /tmp/svndiff
rm /tmp/svndiff/* 2>/dev/null

right=$(echo "$5" | awk '{print $1}')
ext=$(echo "$right" | egrep -o "[^/]+$")
left="/tmp/svndiff/$ext"

cp "$6" "$left"
chmod 777 "$left"
meld --diff "$left" "$right" 2>/dev/null
