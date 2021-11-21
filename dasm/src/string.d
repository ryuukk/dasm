module string;

size_t str_len(const char* txt)
{
    size_t l = 0;
    while(txt[l] != '\0')
        l++;
    return l;
}
