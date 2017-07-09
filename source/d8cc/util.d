module d8cc.util;

import std.stdio;
import core.stdc.stdlib : exit;

template error(Args...){
    void error(string file=__FILE__, uint line=__LINE__)() {
        stderr.writefln("file:%s, line: %s", file, line);
        stderr.writefln(Args);
        exit(1);
    }
}
template warn(Args...){
    void warn(string file=__FILE__, uint line=__LINE__)() {
        stderr.writefln("file:%s, line: %s", file, line);
        stderr.write("warning: ");
        stderr.writefln(Args);
    }
}
