import std.stdio;

int main(string[] args)
{
	int val;
	if (readf("%d", val) == EOF) {
		stderr.writeln("readf");
		return 1;
	}
	writef("\t.text\n\t"~
			".global mymain\n"~
			"mymain:\n\t"~
			"mov $%d, %%eax\n\t"~
			"ret\n", val);
	return 0;
}
