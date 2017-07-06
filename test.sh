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
function assertequal {
	if [ "$1" != "$2" ]; then
		echo "Test failed: $2 expected but got $1"
		exit
	fi
}
function testast {
	result="$(echo "$2" | ./8dcc -a)"
	if [ $? -ne 0 ]; then
		echo "Failed to compile $1"
		exit
	fi
	assertequal "$result" "$1"
}
function test {
	compile "$2"
	assertequal "$(./tmp.out)" "$1"
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
testast '1' '1'
testast '(+ (- (+ 1 2) 3) 4)' '1+2-3+4'

test 0 0
test abc '"abc"'

test 3 '1+2'
test 3 '1 + 2'
test 10 '1+2+3+4'
test 4 '1+2-3+4'

testfail '0abc'
testfail '"abc'
testfail '1+'
testfail '1+"abc"'

echo "All test passed"
