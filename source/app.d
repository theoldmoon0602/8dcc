import std.stdio;
import std.string;
import std.conv;
import std.conv;
import std.uni;
import core.stdc.stdlib;
import core.stdc.stdio : ungetc;


enum AST_TYPE : int {
	INT = -1,
	VAR = -2,
	STR = -3,
	FUNCALL = -4,
}


class Ast {
	int type;
	union {
		// INT
		int ival;
		// STR
		struct {
			string sval;
			int sid;
			Ast snext;
		}
		// VAR
		struct {
			string vname;
			int vpos;
			Ast vnext;
		}
		// BINOP
		struct {
			Ast left;
			Ast right;
		}
		// FUNCALL
		struct {
			string fname;
			Ast[] args;
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
	this(string fname, Ast[] args) {
		this.type = AST_TYPE.FUNCALL;
		this.fname = fname;
		this.args = args;
	}
	this(int type, string str, ref Ast strings) {
		if (type == AST_TYPE.STR) {
			init_string(str, strings);
		}
		else if (type == AST_TYPE.VAR) {
			init_var(str, strings);
		}
		else {
			stderr.writeln("Unexpected type");
			exit(1);
		}
	}
	void init_string(string str, ref Ast strings) {
		this.type = AST_TYPE.STR;
		this.sval = str;
		if (strings is null) {
			this.sid = 0;
			this.snext = null;
		}
		else {
			this.sid = strings.sid+1;
			this.snext = strings;
		}
		strings = this;
	}
	void init_var(string vname, ref Ast vars) {
		this.type =AST_TYPE.VAR;
		this.vname = vname;
		this.vpos = vars ? vars.vpos + 1 : 0;
		this.vnext = vars;
		vars = this;
	}
}
Ast vars = null;
Ast strings = null;
string[] REGS = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"];


Ast find_var(string name) {
	for (Ast v = vars; v; v = v.vnext) {
		if (name == v.vname) {
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
	else if (c == '"') {
		return read_string();
	}
	else if (c.isAlpha) {
		return read_ident_or_func(c);
	}
	stderr.writefln("Don't know how to handle '%c'", c);
	exit(1);
	return null;
}
Ast read_string() {
	dchar[] buf;
	while (true) {
		dchar c;
		if (! readf("%c", c)) {
			stderr.writeln("Unterminated string");
			exit(1);
		}
		if (c == '"') {
			break;
		}
		if (c == '\\') {
			if (! readf("%c", c)) {
				stderr.writeln("Unterminated string");
				exit(1);
			}
		}
		buf ~= c;
	}
	buf ~= '\0';
	return new Ast(AST_TYPE.STR, buf.to!string,  strings);
}

Ast read_expr2(int prec) {
	skip_space();
	Ast ast = read_prim();
	if (ast is null) {
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

string read_ident(dchar c) {
	dchar[] buf;
	buf ~= c;
	while (true) {
		if (!readf("%c", c)) {
			stderr.writeln("Unterminated string");
			exit(1);
		}
		if (! c.isAlphaNum) {
			ungetc(cast(char)c, stdin.getFP);
			break;
		}
		buf ~= c;
	}
	buf ~= '\0';
	return buf.to!string;
}
Ast read_func_args(string fname) {
	Ast[] args;
	while (true) {
		skip_space();
		dchar c;
		readf("%c", c);
		if (c == ')') {
			break;
		}
		ungetc(cast(char)c, stdin.getFP);
		args ~= read_expr2(0);
		readf("%c", c);
		if (c == ')') {
			break;
		}
		if (c == ',') {
			skip_space();
		}
		else {
			stderr.writefln("Unexpected character : '%c'", c);
			exit(1);
		}
	}
	if (args.length > REGS.length) {
		stderr.writefln("Too many arguments: %s", fname);
		exit(1);
	}

	return new Ast(fname, args);
}
Ast read_ident_or_func(dchar c) {
	string name = read_ident(c);
	skip_space();
	dchar c2;
	readf("%c", c2);
	if (c2 == '(') {
		return read_func_args(name);
	}
	ungetc(cast(char)c2, stdin.getFP);
	Ast v = find_var(name);
	return v ? v : new Ast(AST_TYPE.VAR, name, vars);
}

Ast read_expr() {
	Ast r = read_expr2(0);
	if (r is null) {
		return null;
	}
	skip_space();
	dchar c;
	readf("%c", c);
	if (c != ';') {
		stderr.writefln("Unterminated expression. Expected ; but '%c' got", c);
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
		if (ast.left.type != AST_TYPE.VAR) {
			stderr.writeln("Symbol expected");
			exit(1);
		}
		writefln("mov %%eax, -%d(%%rbp)\n\t", ast.left.vpos*4);
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
		case AST_TYPE.VAR:
			writef("mov -%d(%%rbp), %%eax\n\t", ast.vpos*4);
			break;
		case AST_TYPE.STR:
			writef("lea .s%s(%%rip), %%eax\n\t", ast.sid);
			break;
		case AST_TYPE.FUNCALL:
			// レジスタの値を退避
			for (int i = 1; i < ast.args.length; i++) {
				writef("push %%%s\n\t", REGS[i]);
			}
			// 引数をpush
			foreach(arg; ast.args) {
				emit_expr(arg);
				write("push %rax\n\t");
			}
			// レジスタにpop
			for (int i = cast(int)ast.args.length-1; i >= 0; i--) {
				writef("pop %%%s\n\t", REGS[i]);
			}
			write("mov $0, %eax\n\t");
			writef("call %s\n\t", ast.fname);
			// 退避した値を戻す
			for (int i = cast(int)ast.args.length-1; i > 0; i--) {
				writef("pop %%%s\n\t", REGS[i]);
			}
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
		case AST_TYPE.VAR:
			writef("%s", ast.vname);
			break;
		case AST_TYPE.STR:
			write("\"");
			print_quote(ast.sval);
			write("\"");
			break;
		case AST_TYPE.FUNCALL:
			writef("%s(", ast.fname);
			for (int i = 0; i < ast.args.length; i++) {
				print_ast(ast.args[i]);
				if (i+1 < ast.args.length) {
					write(",");
				}
			}
			write(")");
			break;
		default:
			writef("(%c ", cast(char)ast.type);
			print_ast(ast.left);
			write(" ");
			print_ast(ast.right);
			write(")");
			break;
	}
}
void emit_data_section() {
	if (strings is null) {
		return;
	}
	write("\t.data\n");
	for (Ast p = strings; p; p = p.snext)  {
		writef(".s%d:\n\t", p.sid);
		writef(".string \""); print_quote(p.sval); writef("\"\n");
	}
	write("\t");
}

int main(string[] args)
{
	auto wantast = (args.length > 1 && args[1] == "-a");
	Ast[] exprs;
	while (true) {
		Ast t = read_expr();
		if (t is null) {
			break;
		}
		exprs ~= t;
	}
	if (!wantast) {
		emit_data_section();
		write(".text\n\t"~
			".global mymain\n"~
			"mymain:\n\t");
	}
	foreach(expr; exprs) {
		if (wantast) {
			print_ast(expr);
		}
		else {
			emit_expr(expr);
		}
	}
	if (!wantast) {
		write("ret\n");
	}
	return 0;
}
