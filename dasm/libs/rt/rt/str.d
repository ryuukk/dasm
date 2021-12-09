module rt.str;

import rt.memory;
import rt.dbg;

version(WASM)
{

}
else
{
    import core.stdc.string;
}


int str_len(const(char)* txt)
{
    if (!txt) return 0;
    
    int l = 0;
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


alias itoa = int_to_str;
size_t int_to_str(int value, char *sp, int radix = 10)
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

char* float_to_str(char* outstr, float value, int decimals, int minwidth = 0, bool rightjustify = false)
{
    // this is used to write a float value to string, outstr.  oustr is also the return value.
    int digit;
    float tens = 0.1;
    int tenscount = 0;
    int i;
    float tempfloat = value;
    int c = 0;
    int charcount = 1;
    int extra = 0;
    // make sure we round properly. this could use pow from <math.h>, but doesn't seem worth the import
    // if this rounding step isn't here, the value  54.321 prints as 54.3209

    // calculate rounding term d:   0.5/pow(10,decimals)
    float d = 0.5;
    if (value < 0)
        d *= -1.0;
    // divide by ten for each decimal place
    for (i = 0; i < decimals; i++)
        d/= 10.0;
    // this small addition, combined with truncation will round our values properly
    tempfloat +=  d;

    // first get value tens to be the large power of ten less than value
    if (value < 0)
        tempfloat *= -1.0;
    while ((tens * 10.0) <= tempfloat) {
        tens *= 10.0;
        tenscount += 1;
    }

    if (tenscount > 0)
        charcount += tenscount;
    else
        charcount += 1;

    if (value < 0)
        charcount += 1;
    charcount += 1 + decimals;

    minwidth += 1; // both count the null final character
    if (minwidth > charcount){
        extra = minwidth - charcount;
        charcount = minwidth;
    }

    if (extra > 0 && rightjustify) {
        for (int j = 0; j< extra; j++) {
            outstr[c++] = ' ';
        }
    }

    // write out the negative if needed
    if (value < 0)
        outstr[c++] = '-';

    if (tenscount == 0)
        outstr[c++] = '0';

    for (i=0; i< tenscount; i++) {
        digit = cast(int) (tempfloat/tens);
        itoa(digit, &outstr[c++], 10);
        tempfloat = tempfloat - (cast(float)digit * tens);
        tens /= 10.0;
    }

    // if no decimals after decimal, stop now and return

    // otherwise, write the point and continue on
    if (decimals > 0)
    outstr[c++] = '.';


    // now write out each decimal place by shifting digits one by one into the ones place and writing the truncated value
    for (i = 0; i < decimals; i++) {
        tempfloat *= 10.0;
        digit = cast(int) tempfloat;
        itoa(digit, &outstr[c++], 10);
        // once written, subtract off that digit
        tempfloat = tempfloat - cast(float) digit;
    }
    if (extra > 0 && !rightjustify) {
        for (int j = 0; j< extra; j++) {
            outstr[c++] = ' ';
        }
    }


    outstr[c++] = '\0';
    return outstr;
}

float string_to_float(const(char)* str)
{
    int len = 0, n = 0, i = 0;
    float f = 1.0, val = 0.0;
    bool neg = false;
    if (str[0] == '-')
    {
        i = 1;
        neg = true;
    }

    while (str[len])
        len++;
        
    if (!len)
        return 0;

    while (i < len && str[i] != '.')
        n = 10 * n + (str[i++] - '0');

    if (i == len)
        return n;
    i++;
    while (i < len)
    {
        f *= 0.1;
        val += f * (str[i++] - '0');
    }
    float ret = (val + n);
    if (neg)
        ret = -ret;
    return ret;
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

int count_digits(int value)
{
    int count = 0;
    do
    {
        value /= 10;
        ++count;
    }
    while (value != 0);
    return count;
}
struct StringBuilder
{
    char[] buffer;
    int pos;

    void append_int(int value)
    {
        auto c = count_digits(value);
        if (value < 0) c++;

        if (pos + c >  buffer.length) panic("nope");
        int_to_str(value, &buffer[pos]);
        pos += c;
    }

    void append_float(float value, int decimals)
    {
        auto c = count_digits(cast(int)value) + 1 + decimals;
        if (value < 0) c++;

        if (pos + c >  buffer.length) panic("nope");
        float_to_str(&buffer[pos], value, decimals);
        pos += c;
    }
}
