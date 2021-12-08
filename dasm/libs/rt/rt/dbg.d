module rt.dbg;

import rt.str;

version (WASM)
{
    import wasm;

}
else
{
    import core.stdc.stdio;
    import core.stdc.stdlib;
}

version (WASM) alias noreturn = void;

noreturn not_implemented(string file = __FILE__, int line = __LINE__)
{
    panic("not implemented at {}:{}", file, line);
}

noreturn panic(Char, A...)(in Char[] fmt, A args, string file = __FILE__, int line = __LINE__)
{
    version(WASM)
    {
        print_char('[');
        print_str(file.ptr);
        print_char(':');    
        print_int(line);
        print_char(']');
        print_char(' ');
    }
    else
        printf("[%s:%d] ", file.ptr, line);

    writef_impl(fmt, args);

    version(WASM) 
        print_char('\n');
    else
        printf("\n");

    abort();
}


string enum_to_str(E)(E v) if (is(E == enum))
{
    final switch (v) with(E)
    {
        static foreach (m; __traits(allMembers, E))
        {
    case mixin(m):
            return m;
        }
    }
}


alias writelnf = writeln;

void LINFO(Char, A...)(in Char[] fmt, A args, string file = __FILE__, int line = __LINE__)
{
    version (PRINT_PATH)
        print_path(file, line);

    print_str("[INFO] ");

    writef_impl(fmt, args);

    print_char('\n');
}
void LWARN(Char, A...)(in Char[] fmt, A args, string file = __FILE__, int line = __LINE__)
{
    version (PRINT_PATH)
        print_path(file, line);
    print_str("[WARN] ");

    writef_impl(fmt, args);

    print_char('\n');
}

void LERRO(Char, A...)(in Char[] fmt, A args, string file = __FILE__, int line = __LINE__)
{
    version (PRINT_PATH)
        print_path(file, line);

    print_str("[ERRO] ");

    writef_impl(fmt, args);

    print_char('\n');
}


void writeln(Char, A...)(in Char[] fmt, A args, string file = __FILE__, int line = __LINE__)
{
    version (PRINT_PATH)
        print_path(file, line);
    
    writef_impl(fmt, args);

    print_char('\n');
}

void writef(Char, A...)(in Char[] fmt, A args, string file = __FILE__, int line = __LINE__)
{
    version (PRINT_PATH)
        print_path(file, line);
    writef_impl(fmt, args);
}

void writef_impl(Char, A...)(in Char[] fmt, A args)
{
    enum bool isSomeString(T) = is(immutable T == immutable C[], C) && (is(C == char) || is(C == wchar) || is(C == dchar));
    enum bool isIntegral(T) = __traits(isIntegral, T);
    enum bool isBoolean(T) = __traits(isUnsigned, T) && is(T : bool);
    enum bool isSomeChar(T) = __traits(isUnsigned, T) && is(T : char);
    enum bool isSomeChar2(T) = __traits(isUnsigned, T) && (is(T == char) || is(T == wchar) || is(T == dchar));
    enum bool isFloatingPoint(T) = __traits(isFloating, T) && is(T : real);
    enum bool isPointer(T) = is(T == U*, U) && __traits(isScalar, T);
    enum bool isStaticArray(T) = __traits(isStaticArray, T);
    string enum_to_str(E)(E v) if (is(E == enum))
    {
        final switch (v)
        {
        // FIXME: 
            static foreach (m; __traits(allMembers, E))
            {
            case mixin("E.", m):
                return m;
            }
        }
    }
    static assert(isSomeString!(typeof(fmt)));

    bool inside = false;
    size_t c;
    int num_arg;
    foreach (a; args)
    {
        alias T = typeof(a);

        foreach (i, f; fmt)
        {
            if (i < c)
                continue;

            if (f == '{')
            {
                inside = true;
                static if (is(T == enum))
                {
                    print_str(enum_to_str(a).ptr);
                }
                else static if (isBoolean!T)
                {
                    if (a)
                        print_str("true");
                    else
                        print_str("false");
                }
                else static if (isSomeChar2!T)
                        print_char(a);
                else static if (isFloatingPoint!T)
                        print_float(a);
                else static if (isIntegral!T)
                {
                    static if (is(T : int))
                    {
                        static if (__traits(isUnsigned, T))
                               print_uint(a);
                        else
                            print_int(a);
                    }
                    else static if (is(T : long))
                    {
                        static if (__traits(isUnsigned, T))
                               print_ulong(a);
                        else
                            print_long(a);
                    }
                }
                else static if (isSomeString!T)
                {
                    auto l = str_len(a.ptr);
                    print_str_len(a.ptr, l);
                }
                else static if (is(T : const(char)*))
                {
                    auto l = str_len(a);
                    print_str_len(a, l);
                }
                else static if (is(T : const(char)[]))
                {
                    auto l = str_len(a.ptr);
                    print_str_len(a.ptr, l);
                }
                else static if (isPointer!T)
                {
                    // TODO: if pointer is null it tries to print as if it was a char*
                    print_ptr(a);
                }
                else
                {
                    print_str("[?:");
                    print_str(T.stringof);
                    print_str("]");
                }
            }
            else if (f == '}')
            {
                inside = false;
                c = i + 1;
                break;
            }
            else if (!inside)
            {
                int start = cast(int)i;
                int end = cast(int)i;
                for(int j = start; j < fmt.length; j++)
                {
                    if(fmt[j] == '{')
                    {
                        break;
                    }
                    end++;
                }

                c = end;

                // printf("%.*s", end - start, fmt[start .. end].ptr);
                print_str_len(&fmt[start], end - start);
            }
        }
    }
    // print remaining
    if(c < fmt.length)
    {
        //printf("%.*s", cast(int) (fmt.length - c), fmt[c .. $].ptr);
        print_str_len(&fmt[c], cast(int) (fmt.length - c));
    }
}


void print_path(string file, int line)
{
    version(WASM)
    {
        print_char('[');
        print_str(file.ptr);
        print_char(':');    
        print_int(line);
        print_char(']');
        print_char(' ');
    }
    else
        printf("[%s:%d] ", file.ptr, line);
}

version (WASM)
{

}
else
{
    void print_int(int value)
    {
        printf("%i", value);
    }

    void print_uint(uint value)
    {
        printf("%u", value);
    }

    void print_float(float value)
    {
        printf("%f", value);
    }

    void print_double(double value)
    {
        printf("%f", value);
    }

    void print_char(char value)
    {
        printf("%c", value);
    }

    void print_str(const char* value)
    {
        printf(value);
    }

    void print_ptr(const (void)* value)
    {
        printf("%p", value);
    }

    void print_str_len(const char* value, size_t len)
    {
        printf("%.*s", cast(int)len,  value);
    }

    void print_ulong(ulong value)
    {
        printf("%llu", value);
    }

    void print_long(long value)
    {
        printf("%lld", value);
    }
}