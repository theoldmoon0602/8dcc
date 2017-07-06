import std.stdio;
import std.string;
import std.conv;
import std.conv;
import std.uni;
import core.stdc.stdlib;

enum { BUFLEN=256 };


void compile_number(int n) {
	dchar c;
	while (readf("%c", c)) {
		if (c.isWhite) {
			break;
		}
		if (!c.isNumber) {
			stderr.writefln("Invalid character in number: '%c'", c);
			exit(1);
		}
		n = n * 10 + cast(int)(c-'0');
	}
	writef("\t.text\n\t"~
		".global intfn\n"~
		"intfn:\n\t"~
		"mov $%d, %%eax\n\t"~
		"ret\n", n);
}

void compile_string() {
	dchar[] buf;
	while (true) {
		dchar c;
		if (!readf("%c", c)) {
			stderr.writeln("Unterminated string");
			exit(1);
		}
		if (c == '"') {
			break;
		}
		if (c == '\\') {
			if (!readf("%c", c)) {
				stderr.writeln("Unterminated \\");
				exit(1);
			}
		}
		buf ~= c;
	}
	buf ~= '\0';
	writef("\t.data\n"~
		".mydata:\n\t"~
		".string \"%s\"\n\t"~
		".text\n\t"~
		".global stringfn\n"~
		"stringfn:\n\t"~
		"lea .mydata(%%rip), %%rax\n\t"~
		"ret\n", buf.to!string);
}

void compile() {
	char c;
	readf("%c", c);
	if (c.isNumber) {
		return compile_number(cast(int)(c-'0'));
	}
	if (c == '"') {
		return compile_string();
	}
	stderr.writefln("Don't know how to handle '%c'", c);
	exit(1);
}


int main(string[] args)
{
	compile();
	return 0;
}
