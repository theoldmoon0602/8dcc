import std.stdio;
import std.string;
import std.conv;
import std.uni;
import std.algorithm;
import std.format;

import d8cc;



enum AST_TYPE : int {
	LITERAL = -1,
	VAR = -2,
	FUNCALL = -3,
	DECL = -4,
	ADDR = -5,
	DEREF = -6,
}

enum CTYPE: int {
	VOID,
	INT,
	CHAR,
	STR,
	PTR,
}


class Ctype {
	int type;
	Ctype ptr;

	this(int type, Ctype ptr) {
		this.type = type;
		this.ptr = ptr;
	}

	this(Ctype ctype) {
		this(CTYPE.PTR, ctype);
	}
	static Ctype INT;
	static Ctype CHAR;
	static Ctype STR;
	static this() {
		INT = new Ctype(CTYPE.INT, null);
		CHAR = new Ctype(CTYPE.CHAR, null);
		STR = new Ctype(CTYPE.STR, null);
	}
	override string toString() {
		if (this.type == CTYPE.PTR) {
			return "%s*".format(ptr);
		}
		return (cast(CTYPE)(type)).to!string.toLower;
	}
}
class Ast {
	int type;
	Ctype ctype;
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
		// Unary operator
		struct {
			Ast operand;
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
	this(int type, Ctype ctype, Ast left, Ast right) {
		this.type = type;
		this.ctype = ctype;
		this.left = left;
		this.right = right;
	}
	this(int type, Ctype ctype, Ast operand) {
		this.type = type;
		this.ctype = ctype;
		this.operand = operand;
	}
	this(int val) {
		this.type = AST_TYPE.LITERAL;
		this.ctype = Ctype.INT;
		this.ival = val;
	}
	this(string fname, Ast[] args) {
		this.type = AST_TYPE.FUNCALL;
		this.ctype = Ctype.INT;
		this.fname = fname;
		this.args = args;
	}
	this(char c) {
		this.type = AST_TYPE.LITERAL;
		this.ctype = Ctype.CHAR;
		this.c = c;
	}
	this(Ast var, Ast init) {
		this.type = AST_TYPE.DECL;
		this.ctype = null;
		this.decl_var = var;
		this.decl_init = init;
	}
	static Ast newStr(string str, ref Ast strings) {
		Ast ast = new Ast();
		ast.type = AST_TYPE.LITERAL;
		ast.ctype = Ctype.STR;
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
	static Ast newVar(Ctype ctype, string vname, ref Ast vars) {
		Ast ast = new Ast();
		ast.type = AST_TYPE.VAR;
		ast.ctype = ctype;
		ast.vname = vname;
		ast.vpos = vars ? vars.vpos + 1 : 1;
		ast.vnext = vars;
		vars = ast;
		return ast;
	}
	override string toString () {
		switch(this.type) {
		case AST_TYPE.LITERAL:
			switch(ctype.type) {
				case CTYPE.INT:
					return "%d".format(this.ival);
				case CTYPE.CHAR:
					return "'%c'".format(this.c);
				case CTYPE.STR:
					return "\"%s\"".format(quote(this.sval));
				default:
					error!("internal error");
					break;
			}
			break;
		case AST_TYPE.VAR:
			return "%s".format(this.vname);
		case AST_TYPE.FUNCALL:
			{
				char[] buf;
				buf ~= "%s(".format(this.fname);
				for (int i = 0; i < this.args.length; i++) {
					buf ~= this.args[i].toString;
					if (i+1 < this.args.length) {
						buf ~= ",";
					}
				}
				buf ~= ")";
				return buf.to!string;
		       }
		case AST_TYPE.DECL:
			return "(decl %s %s %s)".format(this.decl_var.ctype, this.decl_var.vname, this.decl_init);
		case AST_TYPE.ADDR:
			return "(& %s)".format(this.operand);
		case AST_TYPE.DEREF:
			return "(* %s)".format(this.operand);
		default:
			return "(%c %s %s)".format(cast(char)this.type, this.left, this.right);
		}
		error!("internal error");
		return "";
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
bool is_right_assoc(char op) {
	return op == '=';
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
			auto p = tok.punct;
			error!("unexpected character: '%c'", p);
			break;
	}
	return null;
}
Ctype result_type_int(Ctype a, Ctype b) {
	if (a.type == CTYPE.PTR) {
		if (b.type != CTYPE.PTR) {
			throw new Exception("");
		}
		return new Ctype(CTYPE.PTR, result_type_int(a.ptr, b.ptr));
	}
	if (a.type > b.type) {
		swap(a, b);
	}
	switch (a.type) {
		case CTYPE.VOID:
			throw new Exception("");
		case CTYPE.INT:
			switch(b.type) {
				case CTYPE.INT:
				case CTYPE.CHAR:
					return Ctype.INT;
				case CTYPE.STR:
					throw new Exception("");
				default:
					break;
			}
			error!("internal error");
			break;
		case CTYPE.CHAR:
			switch (b.type) {
				case CTYPE.CHAR:
					return Ctype.INT;
				case CTYPE.STR:
					throw new Exception("");
				default:
					break;
			}
			error!("internal error");
			break;
		case CTYPE.STR:
			throw new Exception("");
		default:
			error!("internal error");
			break;
	}
	return null;
}
Ctype result_type(char op, Ast a, Ast b) {
	try { 
		return result_type_int(a.ctype, b.ctype);
	}
	catch (Exception e) {
		error!("incompatible operands: %c: <%s> and <%s>", op, a, b);
	}
	return null;
}
Ast read_unary_opeartor() {
	Token tok = read_token();
	if (tok.is_punct('&')) {
		Ast operand = read_unary_expr();
		ensure_lvalue(operand);
		return new Ast(AST_TYPE.ADDR, new Ctype(operand.ctype), operand);
	}
	if (tok.is_punct('*')) {
		Ast operand = read_unary_expr();
		if (operand.ctype.type != CTYPE.PTR) {
			error!("pointer type expected, but got %s", operand);
		}
		return new Ast(AST_TYPE.DEREF, operand.ctype.ptr, operand);
	}
	unget_token(tok);
	return read_prim();
}
Ast read_expr(int prec) {
	Ast ast = read_unary_expr();
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
		Ast rest = read_expr(prec2 + (is_right_assoc(tok.punct) ? 0 : 1));
		auto ctype = result_type(tok.punct, ast, rest);
		ast = new Ast(tok.punct, ctype, ast, rest);
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
			error!("Unexpected token: '%s'", tok);
		}
	}
	if (args.length > REGS.length) {
		error!("Too many arguments: %s", fname);
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
		error!("Undefined variable: %s", name);
	}
	return v;
}

void ensure_lvalue(Ast ast) {
	if (ast.type != AST_TYPE.VAR) {
		error!("lvalue expected, but got %s", ast);
	}
}
Ast read_unary_expr() {
	Token tok = read_token();
	if(tok.is_punct('&')) {
		Ast operand = read_unary_expr();
		ensure_lvalue(operand);
		return new Ast(AST_TYPE.ADDR, new Ctype(operand.ctype), operand);
	}
	if (tok.is_punct('*')) {
		Ast operand = read_unary_expr();
		if (operand.ctype.type != CTYPE.PTR) {
			error!("pointer type expected, but got %s", operand);
		}
		return new Ast(AST_TYPE.DEREF, operand.ctype.ptr, operand);
	}
	unget_token(tok);
	return read_prim();
}

Ctype get_ctype(Token tok) {
	if (tok.type != TOKEN_TYPE.IDENT) {
		return null;
	}
	if (tok.sval == "int") {
		return Ctype.INT;
	}
	if (tok.sval == "char") {
		return Ctype.CHAR;
	}
	if (tok.sval == "string") {
		return Ctype.STR;
	}

	return null;
}

bool is_type_keyword(Token tok) {
	return get_ctype(tok) !is null;
}

void expect(char punct) {
	Token tok = read_token();
	if (! is_punct(tok, punct)) {
		error!("'%c' expected, but got %s", punct, tok);
	}
}
Ast read_decl() {
	auto ctype = get_ctype(read_token());
	Token tok;
	for (;;) {
		tok = read_token();
		if (!tok.is_punct('*')) {
			break;
		}
		ctype = new Ctype(ctype);
	}
	if (tok.type != TOKEN_TYPE.IDENT) {
		error!("Identifier expected, but got %s", tok);
	}
	Ast var = Ast.newVar(ctype, tok.sval, vars);
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
		error!("Unterminated expression: %s", tok);
	}
	return r;
}

string quote(string s) {
	char[]buf;
	foreach(c; s) {
		if (c == '\"' || c == '\\') {
			buf ~="\\";
		}
		buf ~= "%c".format(c);
	}
	return buf.to!string;
}
void emit_assign(Ast var, Ast value) {
	emit_expr(value);
	writef("mov %%rax, -%d(%%rbp)\n\t", var.vpos * 8);
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
			auto t= ast.type;
			error!("invalid operator '%c'", t);
			break;
	}

	emit_expr(ast.left);
	write("push %rax\n\t");
	emit_expr(ast.right);
	if (ast.type == '/') {
		write("mov %rax, %rbx\n\t");
		write("pop %rax\n\t");
		write("mov $0, %edx\n\t");
		write("idiv %rbx\n\t");
	}
	else {
		write("pop %rbx\n\t");
		writef("%s %%rbx, %%rax\n\t", op);
	}
}
void emit_expr(Ast ast) {
	switch (ast.type) {
		case AST_TYPE.LITERAL:
			switch(ast.ctype.type) {
				case CTYPE.INT:
					writef("mov $%d, %%rax\n\t", ast.ival);
					break;
				case CTYPE.CHAR:
					writef("mov $%d, %%rax\n\t", ast.c);
					break;
				case CTYPE.STR:
					writef("lea .s%d(%%rip), %%rax\n\t", ast.sid);
					break;
				default:
					error!("internal error");
					break;
			}
			break;
		case AST_TYPE.VAR:
			writef("mov -%d(%%rbp), %%rax\n\t", ast.vpos*8);
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
			write("mov $0, %rax\n\t");
			writef("call %s\n\t", ast.fname);
			// 退避した値を戻す
			for (int i = cast(int)ast.args.length-1; i > 0; i--) {
				writef("pop %%%s\n\t", REGS[i]);
			}
			break;
		case AST_TYPE.DECL:
			emit_assign(ast.decl_var, ast.decl_init);
			break;
		case AST_TYPE.ADDR:
			assert(ast.operand.type == AST_TYPE.VAR);
			writef("lea -%d(%%rbp), %%rax\n\t", ast.operand.vpos * 8);
			break;
		case AST_TYPE.DEREF:
			assert(ast.operand.ctype.type == CTYPE.PTR);
			emit_expr(ast.operand);
			write("mov (%rax), %rax\n\t");
			break;
		default:
			emit_binop(ast);
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
		writef(".string \"%s\"\n", quote(p.sval));
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
			"mymain:\n\t"~
			"push %rbp\n\t"~
			"mov %rsp, %rbp\n\t");
		if (vars !is null) {
			writef("sub $%d, %%rsp\n\t", vars.vpos*8);
		}
	}
	foreach(expr; exprs) {
		if (wantast) {
			write(expr);
		}
		else {
			emit_expr(expr);
		}
	}
	if (!wantast) {
		write("leave\n\t"~
			"ret\n");
	}
	return 0;
}
