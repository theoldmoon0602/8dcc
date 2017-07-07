import std.stdio;
import std.string;
import std.conv;
import std.conv;
import std.uni;
import core.stdc.stdlib;
import core.stdc.stdio : ungetc;


enum AST_TYPE : char{
	INT = 254,
	STR
}

class Ast {
	char type;
	union {
		int ival;
		string sval;
		struct {
			Ast left;
			Ast right;
		}
	}
	this(char type, Ast left, Ast right) {
		this.type = type;
		this.left = left;
		this.right = right;
	}

	this(int val) {
		this.type = AST_TYPE.INT;
		this.ival = val;
	}
	this(string str) {
		this.type = AST_TYPE.STR;
		this.sval = str;
	}
}
int priority(char op) {
	switch(op) {
		case '+':
		case '-':
			return 1;
		case '*':
		case '/':
			return 2;
		default:
			break;
	}
	stderr.writefln("Unknown binary operator :%c", op);
	exit(1);
	return 0;
}

void skip_space() {
	dchar c;
	while (readf("%c", c)) {
		if (c.isWhite) {
			continue;
		}
		ungetc(c.to!char, stdin.getFP);
		break;
	}
	return;
}

Ast read_number(int n) {
	while (true) {
		dchar c;
		readf("%c", c);
		if (!c.isNumber) {
			ungetc(c.to!char, stdin.getFP);
			break;
		}
		n = n * 10 + cast(int)(c-'0');
	}
	return new Ast(n);
}

Ast read_prim() {
	dchar c;
	if (!readf("%c", c)) {
		stderr.writeln("Unexpected EOF");
		exit(1);
	}
	else if (c.isNumber) {
		return read_number(cast(int)(c - '0'));
	}
	else if (c == '"') {
		return read_string();
	}
	stderr.writefln("Don't know how to handle '%c'", c);
	exit(1);
	return null;
}

Ast read_expr2(int prec) {
	Ast ast = read_prim();
	while (true) {
		skip_space();
		dchar c;
		if (!readf("%c", c)) {
			return ast;
		}
		int prec2 = priority(cast(char)c);
		if (prec2 < prec) {
			ungetc(cast(char)c, stdin.getFP);
			return ast;
		}
		skip_space();
		ast = new Ast(cast(char)c, ast, read_expr2(prec2+1));
	}
}

Ast read_string() {
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
	return new Ast(buf.to!string);
}

Ast read_expr() {
	return read_expr2(0);
}

void print_quote(string s) {
	foreach(c; s) {
		if (c == '\"' || c == '\\') {
			write("\\");
		}
		writef("%c", c);
	}
}
void emit_string(Ast ast) {
	write("\t.data\n"~
		".mydata:\n\t"~
		".string \"");
	print_quote(ast.sval);
	write("\"\n\t"~
		".text\n\t"~
		".global stringfn\n"~
		"stringfn:\n\t"~
		"lea .mydata(%rip), %rax\n\t"~
		"ret\n");
}
void emit_binop(Ast ast) {
	string op;
	switch (ast.type) {
		case '+':
			op = "add";
			break;
		case '-':
			op = "sub";
			break;
		case '*':
			op = "imul";
			break;
		case '/':
			break;
		default:
			stderr.writefln("invalid operator '%c'", ast.type);
			exit(1);
			break;
	}

	emit_intexpr(ast.left);
	write("push %rax\n\t");
	emit_intexpr(ast.right);
	if (ast.type == '/') {
		write("mov %eax, %ebx\n\t");
		write("pop %rax\n\t");
		write("mov $0, %edx\n\t");
		write("idiv %ebx\n\t");
	}
	else {
		write("pop %rbx\n\t");
		writef("%s %%ebx, %%eax\n\t", op);
	}
}
void ensure_intexpr(Ast ast) {
	switch (ast.type) {
		case '+':
		case '-':
		case '*':
		case '/':
		case AST_TYPE.INT:
			return;
		default:
		stderr.writeln("integer or binary operator expected");
		exit(1);
		break;
	}
}
void emit_intexpr(Ast ast) {
	ensure_intexpr(ast);
	if (ast.type == AST_TYPE.INT) {
		writef("mov $%d, %%eax\n\t", ast.ival);
	}
	else {
		emit_binop(ast);
	}
}
void print_ast(Ast ast) {
	switch(ast.type) {
		case AST_TYPE.INT:
			writef("%d", ast.ival);
			break;
		case AST_TYPE.STR:
			print_quote(ast.sval);
			break;
		default:
			writef("(%c ", ast.type);
			print_ast(ast.left);
			write(" ");
			print_ast(ast.right);
			write(")");
			break;
	}
}

void compile(Ast ast) {
	if (ast.type == AST_TYPE.STR) {
		emit_string(ast);
	}
	else {
		write(".text\n\t"~
			".global intfn\n"~
			"intfn:\n\t");
		emit_intexpr(ast);
		write("ret\n");
	}
}


int main(string[] args)
{
	Ast ast = read_expr();
	if (args.length > 1 && args[1] == "-a") {
		print_ast(ast);
	}
	else {
		compile(ast);
	}
	return 0;
}
