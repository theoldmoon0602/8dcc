import std.stdio;
import std.string;
import std.conv;
import std.conv;
import std.uni;
import core.stdc.stdlib;
import core.stdc.stdio : ungetc;


enum AST_TYPE {
	OP_PLUS,
	OP_MINUS,
	INT,
	STR
}

class Ast {
	AST_TYPE type;
	union {
		int ival;
		string sval;
		struct {
			Ast left;
			Ast right;
		}
	}
	this(AST_TYPE type, Ast left, Ast right) {
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

Ast read_expr2(Ast left) {
	skip_space();
	dchar c;
	if (!readf("%c", c)) {
		return left;
	}
	AST_TYPE op;
	if (c == '+') {
		op = AST_TYPE.OP_PLUS;
	}
	else if (c == '-') {
		op = AST_TYPE.OP_MINUS;
	}
	else {
		stderr.writefln("Operator expected, but got '%c'", c);
		exit(1);
	}
	skip_space();
	Ast right = read_prim();
	return read_expr2(new Ast(op, left, right));
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
	Ast left = read_prim();
	return read_expr2(left);
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
	if (ast.type == AST_TYPE.OP_PLUS) {
		op = "add";
	}
	else if (ast.type == AST_TYPE.OP_MINUS) {
		op = "sub";
	}
	else {
		stderr.writeln("invalid operand");
		exit(1);
	}
	emit_intexpr(ast.left);
	write("mov %eax, %ebx\n\t");
	emit_intexpr(ast.right);
	writef("%s %%ebx, %%eax\n\t", op);
}
void ensure_intexpr(Ast ast) {
	if (ast.type != AST_TYPE.OP_PLUS &&
		ast.type != AST_TYPE.OP_MINUS &&
		ast.type != AST_TYPE.INT) {
		stderr.writeln("integer or binary operator expected");
		exit(1);
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
	final switch(ast.type) {
		case AST_TYPE.OP_PLUS:
			write("(+ ");
			goto print_op;
		case AST_TYPE.OP_MINUS:
			write("(- ");
print_op:
			print_ast(ast.left);
			write(" ");
			print_ast(ast.right);
			write(")");
			break;
		case AST_TYPE.INT:
			writef("%d", ast.ival);
			break;
		case AST_TYPE.STR:
			print_quote(ast.sval);
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
