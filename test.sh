#!/bin/bash

function compile {
	echo "$1" | ./8dcc > tmp.s
	if [ $? -ne 0 ]; then
		echo "Failed to compile $1"
		exit
	fi
	gcc -o tmp.out driver.c tmp.s || exit
	if [ $? -ne 0 ]; then
		echo "GCC failed"
		exit
	fi
}
function test {
	expected="$1"
	expr="$2"

	compile "$expr"
	result="`./tmp.out`"
	if [ "$result" != "$expected" ]; then
		echo "Test failed: $expected expected but got $result"
		exit
	fi
}
function testfail {
	expr="$1"
	echo "$expr" | ./8dcc > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "Should fail to compile, but succeeded: $expr"
		exit
	fi
}
dub build
if [ $? -ne 0 ]; then
	echo "dub build failed"
	exit
fi
test 0 0
test abc '"abc"'

test 3 '1+2'
test 3 '1 + 2'
test 10 '1+2+3+4'

testfail '0abc'
testfail '"abc'
testfail '1+'

echo "All test passed"
