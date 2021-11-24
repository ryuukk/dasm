module str;

import memory;
import dbg;


size_t str_len(const char* txt)
{
    size_t l = 0;
    while(txt[l] != '\0')
        l++;
    return l;
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