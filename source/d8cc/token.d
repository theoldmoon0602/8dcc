module d8cc.token;

import std.conv;
import std.format;

enum TOKEN_TYPE {
	IDENT,
	PUNCT,
	INT,
	CHAR,
	STRING,
}

class Token {
	public:
		TOKEN_TYPE type;
		union {
			int ival;
			string sval;
			char punct;
			char c;
		}
		static Token newIdent(string s) {
			Token t = new Token();
			t.type = TOKEN_TYPE.IDENT;
			t.sval = s;
			return t;
		}
		static Token newString(string s) {
			Token t = new Token();
			t.type = TOKEN_TYPE.STRING;
			t.sval = s;
			return t;
		}
		static Token newPunct(char punct) {
			Token t = new Token();
			t.type = TOKEN_TYPE.PUNCT;
			t.punct = punct;
			return t;
		}
		static Token newInt(int ival) {
			Token t = new Token();
			t.type = TOKEN_TYPE.INT;
			t.ival = ival;
			return t;
		}
		static Token newChar(char c) {
			Token t = new Token();
			t.type = TOKEN_TYPE.CHAR;
			t.c = c;
			return t;
		}
		override string toString() {
			final switch (this.type) {
				case TOKEN_TYPE.IDENT:
					return this.sval;
				case TOKEN_TYPE.PUNCT:
					return this.punct.to!string;
				case TOKEN_TYPE.CHAR:
					return this.c.to!string;
				case TOKEN_TYPE.INT:
					return this.ival.to!string;
				case TOKEN_TYPE.STRING:
					return "%s".format(this.sval);
			}
		}
}
