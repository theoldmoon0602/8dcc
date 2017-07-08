import std.stdio;
import std.string;
import std.conv;
import std.uni;

import d8cc;



enum AST_TYPE : int {
	INT = -1,
	VAR = -2,
	STR = -3,
	FUNCALL = -4,
	CHAR = -5,
}


class Ast {
	int type;
	union {
		// INT
		int ival;
		// CHAR;
		char c;
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
	this(char c) {
		this.type = AST_TYPE.CHAR;
		this.c = c;
	}
	this(int type, string str, ref Ast strings) {
		if (type == AST_TYPE.STR) {
			init_string(str, strings);
		}
		else if (type == AST_TYPE.VAR) {
			init_var(str, strings);
		}
		else {
			error("Unexpected type");
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


Ast read_prim() {
	Token tok = read_token();
	if (tok is null) {
		return null;
	}
	final switch (tok.type) {
		case TOKEN_TYPE.IDENT:
			return read_ident_or_func(tok.sval);
		case TOKEN_TYPE.INT:
			return new Ast(tok.ival);
		case TOKEN_TYPE.CHAR:
			return new Ast(tok.c);
		case TOKEN_TYPE.STRING:
			return new Ast(AST_TYPE.STR, tok.sval, strings);
		case TOKEN_TYPE.PUNCT:
			error("unexpected character: '%c'", tok.punct);
	}
	return null;
}

Ast read_expr2(int prec) {
	Ast ast = read_prim();
	if (ast is null) {
		return null;
	}
	for(;;) {
		Token tok = read_token();
		if (tok.type != TOKEN_TYPE.PUNCT) {
			unget_token(tok);
			return ast;
		}
		int prec2 = priority(tok.punct);
		if (prec2 < 0 || prec2 < prec) {
			unget_token(tok);
			return ast;
		}
		ast = new Ast(tok.punct, ast, read_expr2(prec2+1));
	}
}

Ast read_func_args(string fname) {
	Ast[] args;
	while (true) {
		Token tok = read_token();
		if (is_punct(tok, ')')) {
			break;
		}
		unget_token(tok);
		args ~= read_expr2(0);
		tok = read_token();
		if (is_punct(tok, ')')) {
			break;
		}
		if (!is_punct(tok, ',')) {
			error("Unexpected token: '%s'", tok);
		}
	}
	if (args.length > REGS.length) {
		error("Too many arguments: %s", fname);
	}

	return new Ast(fname, args);
}
Ast read_ident_or_func(string name) {
	Token tok = read_token();
	if (is_punct(tok, '(')) {
		return read_func_args(name);
	}
	unget_token(tok);
	Ast v = find_var(name);
	return (v !is null) ?  v : new Ast(AST_TYPE.VAR, name, vars);

}

Ast read_expr() {
	Ast r = read_expr2(0);
	if (r is null) {
		return null;
	}
	Token tok = read_token();
	if (! is_punct(tok, ';')) {
		error("Unterminated expression: %s", tok);
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
			error("Symbol expected");
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
			error("invalid operator '%c'", ast.type);
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
		case AST_TYPE.CHAR:
			writef("mov $%d, %%eax\n\t", ast.c);
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
		case AST_TYPE.CHAR:
			writef("'%c'", ast.c);
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
