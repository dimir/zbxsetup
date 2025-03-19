#!/usr/bin/env bash

rebuilt=0
for dir in $(find automated-tests/test-cases -mindepth 1 -maxdepth 1 -type d ! -name poc); do
	i=$(basename $dir)

	opt=
	if [ $rebuilt -eq 0 ]; then
		opt="-r"
		rebuilt=1
	else
		opt="-s"
	fi

	run-tests.sh $opt -d $i -- --stop-on-failure
	rv=$?

	if [ $rv -ne 0 ]; then
		exit $rv
	fi
done
