module rt.readers;

import rt.dbg;

public alias PReader = PReaderImpl!(true);
//public alias PReaderBE = PReaderImpl!(false);

struct PReaderImpl(bool LE)
{
	const(ubyte)[] _data;
	int currentPos;

	this(ubyte[] data)
	{
		_data = data;
		currentPos = 0;
	}

	void skip_all()
	{
        currentPos = cast(int)_data.length;
	}
	// todo: use that?
	bool check(int amount)
	{
		if(_data.length < currentPos + amount) return false;
		return true;
	}

	ubyte read_byte()
	{
        assert (currentPos < _data.length);
        
		ubyte value = _data[currentPos];
		currentPos++;
		return value;
	}

	float read_float()
	{
		assert(_data.length >= this.currentPos + 4);
		ubyte[4] data = _data[currentPos .. currentPos + 4];
		currentPos += 4;

		static if (LE)
			return *cast(float*) data;
		else
		{
            not_implemented();
        }
	}

	int read_int()
	{
		ubyte[4] data = _data[currentPos .. currentPos + 4];
		currentPos += 4;
		static if (LE)
			return *cast(int*) data;
		else
            not_implemented();
	}

	uint read_uint()
	{
		scope ubyte[4] data = _data[currentPos .. currentPos + 4];
		currentPos += 4;
		static if (LE)
			return *cast(uint*) data;
		else
            not_implemented();
	}

	short read_short()
	{
		scope ubyte[2] data = _data[currentPos .. currentPos + 2];
		currentPos += 2;

		static if (LE)
			return *cast(short*) data;
		else
            not_implemented();
	}

	ushort read_ushort()
	{
		scope ubyte[2] data = _data[currentPos .. currentPos + 2];
		currentPos += 2;
		static if (LE)
			return *cast(ushort*) data;
		else
            not_implemented();
	}

	double read_double()
	{
		scope ubyte[8] data = _data[currentPos .. currentPos + 8];
		currentPos += 8;
		static if (LE)
			return *cast(double*) data;
		else
            not_implemented();
	}


    const(ubyte)[] read_slice(int size)
    {
        auto ret = _data[currentPos .. currentPos + size];
        currentPos += size;
        return ret;
    }

    // no alloc
	string read_string()
	{
		short l = read_short();
		if(l == 0) return null;

		auto data = read_slice(cast(ushort) l);
		return cast(string) cast(char[]) data;
	}

	string read_cstring()
	{
		//debug_print(currentPos, currentPos + 15);
		auto length = 0;
		for(int i = currentPos; i < _data.length; i++)
		{
			if(_data[i] == 0) break;
			length++;
		}
		auto data = read_slice(cast(ushort) length);
		currentPos++;
		return cast(string) cast(char[]) data;
	}

	 void read_string_to(char[] str)
	 {
		auto s = read_string();
		// TODO: what to do if we have bigger data than str?
		for (int i = 0; i < str.length; i++)
		{
			if(i >= s.length) break;
			str[i] = s[i];
		}
		if(s.length < str.length)
			str[s.length] = 0;
		else
			str[$-1] = 0;
	}

	string read_utf32()
	{
		int l = read_int();
		if(l == 0) return null;
		
		scope auto data = read_slice(cast(ushort) l);
		return cast(string) cast(char[]) data;
	}

	
	bool read_bool()
	{
		bool value = true;
		if (read_byte() == 0)
			return false;
		return value;
	}

	void seek(int pos)
	{
		currentPos = pos;
	}

	ushort bytes_available()
	{
		return cast(ushort)(this._data.length - currentPos);
	}
}


public alias PWriter = PWriterImpl!(true);
//public alias PWriterBE = PWriterImpl!(false);
struct PWriterImpl(bool LE)
{
	ubyte[] buffer;
	uint position;

	this(ubyte[] buffer)
	{
		this.buffer = buffer;
		position = 0;
	}

	ubyte[] get_range()
	{
		return buffer[0 .. position];
	}

	void write_byte(ubyte data)
	{
		buffer[position] = data;
		position++;
	}

	void write_bytes(in ubyte[] data)
	{
		for (int i = 0; i < data.length; i++)
		{
			buffer[position + i] = data[i];
		}
		position += data.length;
	}

	void write_float(float data)
	{
		uint fd = *cast(uint*)&data;
        ubyte[4] value;
		static if(LE)
			value = (cast(ubyte*)&fd)[0 .. 4];
		else
            not_implemented();
		write_bytes(value);
	}

	void write_int(int data)
	 {
        ubyte[4] value;
		static if(LE)
			value = (cast(ubyte*)&data)[0 .. 4];
		else
            not_implemented();
		write_bytes(value);
	}

	void write_uint(uint data)
	 {
		static if(LE)
			ubyte[4] value = (cast(ubyte*)&data)[0 .. 4];
		else
            not_implemented();
		write_bytes(value);
	}

	void write_short(short data)
	 {
        ubyte[2] value;
		static if(LE)
			value = (cast(ubyte*)&data)[0 .. 2];
		else
            not_implemented();
		write_bytes(value);
	}

	void write_ushort(ushort data)
	 {
        ubyte[2] value;
		static if(LE)
		    value = (cast(ubyte*)&data)[0 .. 2];
		else
            not_implemented();
		write_bytes(value);
	}

	void write_double(double data)
	{
        ubyte[8] value;
		static if(LE)
			value = (cast(ubyte*)&data)[0 .. 8];
		else
            not_implemented();
		write_bytes(value);
	}

	void write_utf(in char[] data)
	{
		int size = cast(int)data.length;
		ubyte[] string = cast(ubyte[])data;
		write_int(size);
		if(size > 0)
			write_bytes(string);
	}
	void write_string(in char[] data)
	{
		short size = cast(short)data.length;
		ubyte[] string = cast(ubyte[])data;
		write_short(size);
		if(size > 0)
			write_bytes(string);
	}

	void write_cstring(char[] data)
	{
		auto l = 0;
		for(int i = 0; i < data.length; i++)
		{
			if(data[i] == 0) break;
			l++;
		}
		assert(l < short.max);

		write_short(cast(short) l);

		if(l > 0)
			write_bytes(cast(ubyte[]) data[0 .. l]);
	}

	void write_utf_bytes(in char[] data)
	 {
		ubyte[] str = cast(ubyte[])data;
		write_bytes(str);
	}

	void write_bool(bool data)
	{
		if(data) write_byte(1);
		if(!data) write_byte(0);
	}
}


package:
// TODO: move to bitops module

pragma(inline, false)
ushort byteswap(ushort x) pure
{
    /* Calling it bswap(ushort) would break existing code that calls bswap(uint).
     *
     * This pattern is meant to be recognized by the dmd code generator.
     * Don't change it without checking that an XCH instruction is still
     * used to implement it.
     * Inlining may also throw it off.
     */
    return cast(ushort) (((x >> 8) & 0xFF) | ((x << 8) & 0xFF00u));
}