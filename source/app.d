import std.stdio;
import std.string;
import std.conv;
import std.conv;
import std.uni;
import core.stdc.stdlib;
import core.stdc.stdio : ungetc;


enum AST_TYPE : char{
	INT = 254,
	SYM
}

class Var {
	string name;
	int pos;
	Var next;
	this(string name, ref Var vars) {
		this.name = name;
		this.pos = vars ? vars.pos+1 : 1;
		this.next = vars;
		vars = this;
	}
}

class Ast {
	char type;
	union {
		int ival;
		Var var;
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
	this(Var var) {
		this.type = AST_TYPE.SYM;
		this.var = var;
	}
}
Var vars = null;

Var find_var(string name) {
	Var v = vars;
	for (; v; v = v.next) {
		if (name == v.name) {
			return v;
		}
	}
	return null;
}
int priority(char op) {
	switch(op) {
		case '=':
			return 1;
		case '+':
		case '-':
			return 2;
		case '*':
		case '/':
			return 3;
		default:
			break;
	}
	return -1;
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
		return null;
	}
	else if (c.isNumber) {
		return read_number(cast(int)(c - '0'));
	}
	else if (c.isAlpha) {
		return read_symbol(c);
	}
	stderr.writefln("Don't know how to handle '%c'", c);
	exit(1);
	return null;
}

Ast read_expr2(int prec) {
	skip_space();
	Ast ast = read_prim();
	if (!ast) {
		return null;
	}
	while (true) {
		skip_space();
		dchar c;
		if (!readf("%c", c)) {
			return ast;
		}
		int prec2 = priority(cast(char)c);
		if (prec2 < 0 || prec2 < prec) {
			ungetc(cast(char)c, stdin.getFP);
			return ast;
		}
		skip_space();
		ast = new Ast(cast(char)c, ast, read_expr2(prec2+1));
	}
}

Ast read_symbol(dchar c) {
	dchar[] buf;
	buf ~= c;
	while (true) {
		if (!readf("%c", c)) {
			stderr.writeln("Unterminated string");
			exit(1);
		}
		if (! c.isAlpha) {
			ungetc(cast(char)c, stdin.getFP);
			break;
		}
		buf ~= c;
	}
	buf ~= '\0';
	Var v = find_var(buf.to!string);
	if (!v) {
		v = new Var(buf.to!string, vars);
	}
	return new Ast(v);
}

Ast read_expr() {
	Ast r = read_expr2(0);
	if (!r) {
		return null;
	}
	skip_space();
	dchar c;
	readf("%c", c);
	if (c != ';') {
		stderr.writeln("Unterminated expression");
		exit(1);
	}
	return r;
}

void print_quote(string s) {
	foreach(c; s) {
		if (c == '\"' || c == '\\') {
			write("\\");
		}
		writef("%c", c);
	}
}
void emit_binop(Ast ast) {
	if (ast.type == '=') {
		emit_expr(ast.right);
		if (ast.left.type != AST_TYPE.SYM) {
			stderr.writeln("Symbol expected");
			exit(1);
		}
		writefln("mov %%eax, -%d(%%rbp)\n\t", ast.left.var.pos*4);
		return;
	}
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

	emit_expr(ast.left);
	write("push %rax\n\t");
	emit_expr(ast.right);
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
void emit_expr(Ast ast) {
	switch (ast.type) {
		case AST_TYPE.INT:
			writef("mov $%d, %%eax\n\t", ast.ival);
			break;
		case AST_TYPE.SYM:
			writef("mov -%d(%%rbp), %%eax\n\t", ast.var.pos*4);
			break;
		default:
			emit_binop(ast);
			break;
	}
}
void print_ast(Ast ast) {
	switch(ast.type) {
		case AST_TYPE.INT:
			writef("%d", ast.ival);
			break;
		case AST_TYPE.SYM:
			writef("%s", ast.var.name);
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

int main(string[] args)
{
	auto wantast = (args.length > 1 && args[1] == "-a");
	if (!wantast) {
		write(".text\n\t"~
			".global mymain\n"~
			"mymain:\n\t");
	}
	while (true) {
		Ast ast = read_expr();
		if (ast is null) {
			break;
		}
		if (wantast) {
			print_ast(ast);
		}
		else {
			emit_expr(ast);
		}
	}
	if (!wantast) {
		write("ret\n");
	}
	return 0;
}
