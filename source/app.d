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
	DECL = -6,
}

enum CTYPE: int {
	VOID,
	INT,
	CHAR,
	STR
}


class Ast {
	int type;
	int ctype;
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
	// Declaration
	struct {
		Ast decl_var;
		Ast decl_init;
	}
	this() {}
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
	this(Ast var, Ast init) {
		this.type = AST_TYPE.DECL;
		this.decl_var = var;
		this.decl_init = init;
	}
	static Ast newStr(string str, ref Ast strings) {
		Ast ast = new Ast();
		ast.type = AST_TYPE.STR;
		ast.sval = str;
		if (strings is null) {
			ast.sid = 0;
			ast.snext = null;
		}
		else {
			ast.sid = strings.sid+1;
			ast.snext = strings;
		}
		strings = ast;
		return ast;
	}
	static Ast newVar(int ctype, string vname, ref Ast vars) {
		Ast ast = new Ast();
		ast.type = AST_TYPE.VAR;
		ast.ctype = ctype;
		ast.vname = vname;
		ast.vpos = vars ? vars.vpos + 1 : 1;
		ast.vnext = vars;
		vars = ast;
		return ast;
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
			return Ast.newStr(tok.sval, strings);
		case TOKEN_TYPE.PUNCT:
			error("unexpected character: '%c'", tok.punct);
	}
	return null;
}

Ast read_expr(int prec) {
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
		if (is_punct(tok, '=')) {
			ensure_lvalue(ast);
		}
		ast = new Ast(tok.punct, ast, read_expr(prec2+1));
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
		args ~= read_expr(0);
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
	if (v is null) {
		error("Undefined variable: %s", name);
	}
	return v;
}

void ensure_lvalue(Ast ast) {
	if (ast.type != AST_TYPE.VAR) {
		error("variable expected");
	}
}

int get_ctype(Token tok) {
	if (tok.type != TOKEN_TYPE.IDENT) {
		return -1;
	}
	if (tok.sval == "int") {
		return CTYPE.INT;
	}
	if (tok.sval == "char") {
		return CTYPE.CHAR;
	}
	if (tok.sval == "string") {
		return CTYPE.STR;
	}

	return -1;
}

bool is_type_keyword(Token tok) {
	return get_ctype(tok) != -1;
}

void expect(char punct) {
	Token tok = read_token();
	if (! is_punct(tok, punct)) {
		error("'%c' expected, but got %s", punct, tok);
	}
}
Ast read_decl() {
	int ctype = get_ctype(read_token());
	Token name = read_token();
	if (name.type != TOKEN_TYPE.IDENT) {
		error("Identifier expected, but got %s", name);
	}
	Ast var = Ast.newVar(ctype, name.sval, vars);
	expect('=');
	Ast init = read_expr(0);
	return new Ast(var, init);
}
Ast read_decl_or_stmt() {
	Token tok = peek_token();
	if (tok is null) {
		return null;
	}
	Ast r = is_type_keyword(tok) ? read_decl() : read_expr(0);
	tok = read_token();
	if (!is_punct(tok, ';')) {
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
void emit_assign(Ast var, Ast value) {
	emit_expr(value);
	writef("mov %%eax, -%d(%%rbp)\n\t", var.vpos * 4);
}
void emit_binop(Ast ast) {
	if (ast.type == '=') {
		emit_assign(ast.left, ast.right);
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
			foreach(arg;ast.args) {
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
		case AST_TYPE.DECL:
			emit_assign(ast.decl_var, ast.decl_init);
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
		case AST_TYPE.DECL:
			writef("(decl %s %s ", (cast(CTYPE)ast.decl_var.ctype).to!string.toLower, ast.decl_var.vname);
			print_ast(ast.decl_init);
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
		Ast t = read_decl_or_stmt();
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
