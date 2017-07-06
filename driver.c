#include <stdio.h>

extern int mymain();

int main(int argc, char**argv) {
	int val = mymain();
	printf("%d\n", val);
	return 0;
}
