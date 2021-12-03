module str;

import memory;
import dbg;

version(WASM)
{

}
else
{
    import core.stdc.string;
}


size_t str_len(const(char)* txt)
{
    if (!txt) return 0;
    
    size_t l = 0;
    while(txt[l] != '\0')
        l++;
    return l;
}
bool str_ends_with(const(char)* S, const(char)* E)
{
    return (strcmp(S + str_len(S) - ((E).sizeof-1), E) == 0);
}


extern(C) int strcmp(const(char)* l, const(char)* r)
{
	for (; *l==*r && *l; l++, r++){}
	return *cast(ubyte*)l - *cast(ubyte*)r;
}

void strcpy(char *dst, const char *src)
{
    assert(dst);
    assert(src);

    auto l = str_len(src) + 1;
    memcpy(cast(void*)dst, cast(const(void)*)src, l);
}


size_t itoa(int value, char *sp, int radix)
{
    char[32] tmp;// be careful with the length of the buffer
    char *tp = tmp.ptr;
    int i;
    uint v;

    int sign = (radix == 10 && value < 0);    
    if (sign)
        v = -value;
    else
        v = cast(uint)value;

    while (v || tp == tmp.ptr)
    {
        i = v % radix;
        v /= radix;
        if (i < 10)
          *tp++ = cast(char)(i+'0');
        else
          *tp++ = cast(char)( i + 'a' - 10);
    }

    size_t len = tp - tmp.ptr;

    if (sign) 
    {
        *sp++ = '-';
        len++;
    }

    while (tp > tmp.ptr)
        *sp++ = *--tp;

    return len;
}


char[] concat_str(char[] a, char[] b)
{
    auto end = str_len(a.ptr);
    for (size_t i = 0; i < b.length; i++)
    {
        if (end + i >= a.length) break;
        a[end + i] = b[i];
    }
    return a;
}