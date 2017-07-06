import std.stdio;
import std.string;
import std.conv;
import std.conv;
import std.uni;
import core.stdc.stdlib;
import core.stdc.stdio : ungetc;


void skip_space() {
	dchar c;
	while (readf("%c", c)) {
		if (c.isWhite) {
			continue;
		}
		ungetc(c.to!char, stdin.getFP);
		return;
	}
}

int read_number(int n) {
	dchar c;
	while (readf("%c", c)) {
		if (!c.isNumber) {
			ungetc(c.to!char, stdin.getFP);
			break;
		}
		n = n * 10 + cast(int)(c-'0');
	}
	return n;
}

void compile_expr2() {
	while (true) {
		skip_space();
		dchar c;
		if (!readf("%c", c)) {
			writeln("ret");
			exit(0);
		}
		string op;
		if (c == '+') {
			op = "add";
		}
		else if (c == '-') {
			op = "sub";
		}
		else {
			stderr.writef("Operator expected, but got '%c'", c);
			exit(1);
		}
		skip_space();
		readf("%c", c);
		if (!c.isNumber) {
			stderr.writef("Number expected, but got '%c'", c);
			exit(1);
		}
		writef("%s $%d, %%rax\n\t", op, read_number(cast(int)(c-'0')));
	}
}

void compile_expr(int n) {
	n = read_number(n);
	writef("\t.text\n\t"~
		".global intfn\n"~
		"intfn:\n\t"~
		"mov $%d, %%eax\n\t", n);
	compile_expr2();
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
	exit(0);
}

void compile() {
	char c;
	readf("%c", c);
	if (c.isNumber) {
		compile_expr(cast(int)(c-'0'));
	}
	if (c == '"') {
		compile_string();
	}
	else {
		stderr.writefln("Don't know how to handle '%c'", c);
		exit(1);
	}
}


int main(string[] args)
{
	compile();
	return 0;
}
