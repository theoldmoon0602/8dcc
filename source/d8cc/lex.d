module d8cc.lex;

import d8cc.util, d8cc.token;

import std.stdio;
import std.uni;
import core.stdc.stdio : getc, ungetc;

Token ungotten = null;

int getc(ref File f) {
	return f.getFP.getc;
}
auto ungetc(ref File f, int c) {
	return ungetc(c, f.getFP);
}

int getc_nonspace() {
	int c;
	while ((c = stdin.getc) != EOF) {
		if (c.isWhite) {
			continue;
		}
		return c;
	}
	return EOF;
}

Token read_number(int c) {
	int n = c-'0';
	for (;;) {
		int c2 = stdin.getc;
		if (!c2.isNumber) {
			stdin.ungetc(c2);
			return Token.newInt(n);
		}
		n = n*10 + (c2-'0');
	}
}

Token read_char() {
	int c = stdin.getc;
	int c2;
	if (c == EOF)  {
		goto err;
	}
	if (c == '\\') {
		if ((c = stdin.getc) == EOF) {
			goto err;
		}
	}
	c2 = stdin.getc;
	if (c == EOF) {
		goto err;
	}
	if (c == '\'') {
		error!("Malformed char literal");
	}
	return Token.newChar(cast(char)c);
err:
	error!("Unterminated char");
	return null;
}

Token read_string() {
	char[] s;
	for(;;) {
		int c = stdin.getc;
		if (c == EOF) {
			error!("Unterminated string");
		}
		if (c == '"') {
			break;
		}
		if (c == '\\') {
			if ((c = stdin.getc) == EOF) {
				error!("Unterminated \\");
			}
		}
		s ~= c;
	}
	return Token.newString(cast(string)s);
}
Token read_ident(char c) {
	char[] s;
	s ~= c;
	for (;;) {
		int c2 = stdin.getc;
		if (c2.isAlphaNum || c2 == '_') {
			s ~= c2;
		}
		else {
			stdin.ungetc(c2);
			return Token.newIdent(cast(string)s);
		}

	}
}
Token read_token_int() {
	int c = getc_nonspace();
	if (c == EOF) {
		return null;
	}
	switch (cast(char)c) {
		case '0': .. case '9':
			  return read_number(c);
		case '"':
			  return read_string();
		case '\'':
			  return read_char();
		case 'a': .. case 'z':
		case 'A': .. case 'Z':
		case '_':
			  return read_ident(cast(char)c);
		case '/', '=', '*', '+', '-',
		     '(', ')', ',', ';', '&':
			  return Token.newPunct(cast(char)c);
		default:
			  error!("Unexpected character: '%c'", c);
	}
	return null;
}
bool is_punct(Token tok, char c) {
	if (tok is null) {
		error!("Token is null");
	}
	return tok.type == TOKEN_TYPE.PUNCT && tok.punct == c;
}
void unget_token(Token tok) {
	if (ungotten !is null) {
		error!("Push back buffer is already full");
	}
	ungotten = tok;
}
Token peek_token() {
	Token tok = read_token();
	unget_token(tok);
	return tok;
}
Token read_token() {
	if (ungotten !is null) {
		Token tok = ungotten;
		ungotten = null;
		return tok;
	}
	return read_token_int();
}
