module math;

import dbg;


extern(C):


enum float FLOAT_ROUNDING_ERROR = 0.000001f;
enum float PI = 3.14159265358979323846; 
enum float PI2 = PI * 2;
enum float PIDIV2 = PI / 2;
enum float DEG2RAD = PI / 180.0f;
enum float RAD2DEG = 180.0f / PI;

enum isFloatingPoint(T) = __traits(isFloating, T) && is(T : real);

version (WASM)
{
    pragma(LDC_intrinsic, "llvm.sqrt.f32")
    float sqrt(float);
    pragma(LDC_intrinsic, "llvm.cos.f32")
    float cosf(float);
    pragma(LDC_intrinsic, "llvm.sinf.f32")
    float sinf(float);

    float acosf(float value);
    float tanf(float value);
    float absf(float value);
}
else
{
    import cmath = core.stdc.math;
    import ccmath = core.math;

    float acosf(float value)
    {
        return cmath.acosf(value);
    }

    float sqrt(float value)
    {
        return ccmath.sqrt(value);
    }

    float sinf(float value)
    {
        return ccmath.sin(value);
    }

    float cosf(float value)
    {
        return ccmath.cos(value);
    }

    float tanf(float value)
    {
        return cmath.tanf(value);
    }

    float absf(float value)
    {
        return cmath.fabs(value);
    }

}

T max(T, U)(T a, U b)
if (is(T == U) && is(typeof(a < b)))
{
   /* Handle the common case without all the template expansions
    * of the general case
    */
    return a < b ? b : a;
}

auto abs(Num)(Num x)
if ((is(immutable Num == immutable short) || is(immutable Num == immutable byte)) ||
    (is(typeof(Num.init >= 0)) && is(typeof(-Num.init))))
{
    static if (isFloatingPoint!(Num))
        return absf(x);
    else
    {
        static if (is(immutable Num == immutable short) || is(immutable Num == immutable byte))
            return x >= 0 ? x : cast(Num) -int(x);
        else
            return x >= 0 ? x : -x;
    }
}

struct v2
{
    float x = 0f;
    float y = 0f;

    this(float x, float y)
    {
        this.x = x;
        this.y = y;
    }

    pragma(inline)
    {
        v2 opBinary(string op)(v2 other)
        {
            static if (op == "+")
                return v2(x + other.x, y + other.y);
            else static if (op == "-")
                return v2(x - other.x, y - other.y);
            else static if (op == "*")
                return v2(x * other.x, y * other.y);
            else static if (op == "/")
                return v2(x / other.x, y / other.y);
            else static if (op == "+=")
                return v2(x + other.x, y + other.y);
            else
                static assert(0, "Operator " ~ op ~ " not implemented");
        }
        v2 opOpAssign(string op)(v2 other)
        {
            static if (op == "+")
            {
                x += other.x;
                y += other.y;
                return this;
            }
            else static if (op == "-")
            {
                x -= other.x;
                y -= other.y;
                return this;
            }
            else static if (op == "*")
            {
                x *= other.x;
                y *= other.y;
                return this;
            }
            else static if (op == "/")
            {
                x /= other.x;
                y /= other.y;
                return this;
            }
            else
                static assert(0, "Operator " ~ op ~ " not implemented");
        }

        float len()
        {
            return cast(float) sqrt(x * x + y * y);
        }

        void nor()
        {
            float l = len();
            if (l != 0)
            {
                x /= l;
                y /= l;
            }
        }

        static v2 normalize(v2 other)
        {
            float l = other.len();
            if (l != 0)
            {
                v2 ret;
                ret.x = other.x / l;
                ret.y = other.y / l;
            }
            return other;
        }

        static v2 normalize(float x, float y)
        {
            v2 ret = v2(x, y);
            float l = ret.len();
            if (l != 0)
            {
                ret.x = x / l;
                ret.y = y / l;
            }
            return ret;
        }
    }
}

struct v3
{
    float x = 0f;
    float y = 0f;
    float z = 0f;

    enum v3 UNIT_X = v3(1,0,0);
    enum v3 UNIT_Y = v3(0,1,0);
    enum v3 UNIT_Z = v3(0,0,1);
    enum v3 ZERO =  v3(0,0,0);

    this(float v)
    {
        x = y = z = v;
    }

    this(float x, float y, float z)
    {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    pragma(inline)
    static v3 set(float x, float y, float z)
    {
        return v3(x, y, z);
    }

    pragma(inline)
    float len2()
    {
        return x * x + y * y + z * z;
    }

    pragma(inline)
    v3 nor()
    {
        float len2 = len2();
        if (len2 == 0f || len2 == 1f)
            return v3(x, y, z);

        float scalar = 1f / sqrt(len2);

        return v3(x * scalar, y * scalar, z * scalar);
    }

    pragma(inline)
    float dot(v3 vector)
    {
        return x * vector.x + y * vector.y + z * vector.z;
    }

    pragma(inline)
    v3 crs(v3 vector)
    {
        return v3(y * vector.z - z * vector.y, z * vector.x - x * vector.z,
                x * vector.y - y * vector.x);
    }

    pragma(inline)
    v3 mul(in mat4 m)
    {
        return v3(x * m.m00 + y * m.m01 + z * m.m02 + m.m03,
                x * m.m10 + y * m.m11 + z * m.m12 + m.m13, x * m.m20 + y * m.m21 + z * m.m22 + m
                .m23);
    }

    pragma(inline)
    void prj(mat4 matrix)
    {
        auto l_w = 1f / (x * matrix.m30 + y * matrix.m31 + z * matrix.m32 + matrix.m33);

        auto cpy_x = (x * matrix.m00 + y * matrix.m01 + z * matrix.m02 + matrix.m03) * l_w;
        auto cpy_y = (x * matrix.m10 + y * matrix.m11 + z * matrix.m12 + matrix.m13) * l_w;
        auto cpy_z = (x * matrix.m20 + y * matrix.m21 + z * matrix.m22 + matrix.m23) * l_w;

        this.x = cpy_x;
        this.y = cpy_y;
        this.z = cpy_z;
    }

    pragma(inline)
    bool is_zero()
    {
        return x == 0 && y == 0 && z == 0;
    }

    pragma(inline)
    v3 opUnary(string s)() if (s == "-")
    {
        return v3(-x, -y, -z);
    }

    pragma(inline)
    v3 opBinary(string op)(v3 other)
    {
        static if (op == "+")
            return v3(x + other.x, y + other.y, z + other.z);
        else static if (op == "-")
            return v3(x - other.x, y - other.y, z - other.z);
        else static if (op == "*")
            return v3(x * other.x, y * other.y, z * other.z);
        else static if (op == "/")
            return v3(x / other.x, y / other.y, z / other.z);
        else static if (op == "+=")
            return v3(x + other.x, y + other.y, z + other.z);
        else
            static assert(0, "Operator " ~ op ~ " not implemented");
    }

    pragma(inline)
    v3 opOpAssign(string op)(v3 other)
    {
        static if (op == "+")
        {
            x += other.x;
            y += other.y;
            z += other.z;
        }
        else static if (op == "-")
        {
            x -= other.x;
            y -= other.y;
            z -= other.z;
        }
        else static if (op == "*")
        {
            x *= other.x;
            y *= other.y;
            z *= other.z;
        }
        else static if (op == "/")
        {
            x /= other.x;
            y /= other.y;
            z /= other.z;
        }
        return this;
    }

    v3 opBinary(string op)(float other)
    {
        static if (op == "+")
            return v3(x + other, y + other, z + other);
        else static if (op == "-")
            return v3(x - other, y - other, z - other);
        else static if (op == "*")
            return v3(x * other, y * other, z * other);
        else static if (op == "/")
            return v3(x / other, y / other, z / other);
        else
            static assert(0, "Operator " ~ op ~ " not implemented");
    }

    pragma(inline)
    static float len(float x, float y, float z)
    {
        return sqrt(x * x + y * y + z * z);
    }

    pragma(inline)
    static v3 lerp(in v3 lhs, in v3 rhs, float t)
    {
        if (t > 1f)
        {
            return rhs;
        }
        else
        {
            if (t < 0f)
            {
                return lhs;
            }
        }
        v3 res;
        res.x = (rhs.x - lhs.x) * t + lhs.x;
        res.y = (rhs.y - lhs.y) * t + lhs.y;
        res.z = (rhs.z - lhs.z) * t + lhs.z;
        return res;
    }

    pragma(inline)
    static float dot(in v3 lhs, in v3 rhs)
    {
        return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z;
    }

    pragma(inline)
    static v3 cross(in v3 lhs, in v3 rhs)
    {
        v3 res;
        res.x = lhs.y * rhs.z - lhs.z * rhs.y;
        res.y = lhs.z * rhs.x - lhs.x * rhs.z;
        res.z = lhs.x * rhs.y - lhs.y * rhs.x;
        return res;
    }

    pragma(inline)
    static v3 rotate(in v3 lhs, in v3 axis, float angle)
    {
        auto rotation = quat.fromAxis(axis, angle);
        auto matrix = mat4.set(0, 0, 0, rotation.x, rotation.y, rotation.z, rotation.w);

        return transform(lhs, matrix);
    }

    pragma(inline)
    static v3 transform(in v3 lhs, in mat4 matrix)
    {
        float inv_w = 1.0f / (lhs.x * matrix.m30 + lhs.y * matrix.m31 + lhs.z
                * matrix.m32 + matrix.m33);
        v3 ret;
        ret.x = (lhs.x * matrix.m00 + lhs.y * matrix.m01 + lhs.z * matrix.m02 + matrix.m03) * inv_w;
        ret.y = (lhs.x * matrix.m10 + lhs.y * matrix.m11 + lhs.z * matrix.m12 + matrix.m13) * inv_w;
        ret.z = (lhs.x * matrix.m20 + lhs.y * matrix.m21 + lhs.z * matrix.m22 + matrix.m23) * inv_w;
        return ret;
    }
}

struct mat4
{
    enum M00 = 0;
    enum M01 = 4;
    enum M02 = 8;
    enum M03 = 12;
    enum M10 = 1;
    enum M11 = 5;
    enum M12 = 9;
    enum M13 = 13;
    enum M20 = 2;
    enum M21 = 6;
    enum M22 = 10;
    enum M23 = 14;
    enum M30 = 3;
    enum M31 = 7;
    enum M32 = 11;
    enum M33 = 15;
    float m00 = 0;
    float m10 = 0;
    float m20 = 0;
    float m30 = 0;
    float m01 = 0;
    float m11 = 0;
    float m21 = 0;
    float m31 = 0;
    float m02 = 0;
    float m12 = 0;
    float m22 = 0;
    float m32 = 0;
    float m03 = 0;
    float m13 = 0;
    float m23 = 0;
    float m33 = 0;
    this(float m00, float m01, float m02, float m03, float m04, float m05,
            float m06, float m07, float m08, float m09, float m10, float m11,
            float m12, float m13, float m14, float m15)
    {
        this.m00 = m00;
        this.m10 = m01;
        m20 = m02;
        m30 = m03;
        this.m01 = m04;
        this.m11 = m05;
        m21 = m06;
        m31 = m07;
        this.m02 = m08;
        this.m12 = m09;
        m22 = m10;
        m32 = m11;
        this.m03 = m12;
        this.m13 = m13;
        m23 = m14;
        m33 = m15;
    }

    pragma(inline)
    {
        static mat4 identity()
        {
            mat4 ret;
            ret.m00 = 1f;
            ret.m01 = 0f;
            ret.m02 = 0f;
            ret.m03 = 0f;
            ret.m10 = 0f;
            ret.m11 = 1f;
            ret.m12 = 0f;
            ret.m13 = 0f;
            ret.m20 = 0f;
            ret.m21 = 0f;
            ret.m22 = 1f;
            ret.m23 = 0f;
            ret.m30 = 0f;
            ret.m31 = 0f;
            ret.m32 = 0f;
            ret.m33 = 1f;
            return ret;
        }

        mat4 idt()
        {
            m00 = 1f;
            m01 = 0f;
            m02 = 0f;
            m03 = 0f;
            m10 = 0f;
            m11 = 1f;
            m12 = 0f;
            m13 = 0f;
            m20 = 0f;
            m21 = 0f;
            m22 = 1f;
            m23 = 0f;
            m30 = 0f;
            m31 = 0f;
            m32 = 0f;
            m33 = 1f;
            return this;
        }

        static mat4 inv(in mat4 mat)
        {
            float lDet = mat.m30 * mat.m21 * mat.m12 * mat.m03 - mat.m20 * mat.m31
                * mat.m12 * mat.m03 - mat.m30 * mat.m11 * mat.m22 * mat.m03 + mat.m10
                * mat.m31 * mat.m22 * mat.m03 + mat.m20 * mat.m11 * mat.m32 * mat.m03
                - mat.m10 * mat.m21 * mat.m32 * mat.m03 - mat.m30 * mat.m21 * mat.m02
                * mat.m13 + mat.m20 * mat.m31 * mat.m02 * mat.m13 + mat.m30 * mat.m01
                * mat.m22 * mat.m13 - mat.m00 * mat.m31 * mat.m22 * mat.m13 - mat.m20
                * mat.m01 * mat.m32 * mat.m13 + mat.m00 * mat.m21 * mat.m32 * mat.m13
                + mat.m30 * mat.m11 * mat.m02 * mat.m23 - mat.m10 * mat.m31 * mat.m02
                * mat.m23 - mat.m30 * mat.m01 * mat.m12 * mat.m23 + mat.m00 * mat.m31
                * mat.m12 * mat.m23 + mat.m10 * mat.m01 * mat.m32 * mat.m23 - mat.m00
                * mat.m11 * mat.m32 * mat.m23 - mat.m20 * mat.m11 * mat.m02 * mat.m33
                + mat.m10 * mat.m21 * mat.m02 * mat.m33 + mat.m20 * mat.m01 * mat.m12
                * mat.m33 - mat.m00 * mat.m21 * mat.m12 * mat.m33 - mat.m10 * mat.m01
                * mat.m22 * mat.m33 + mat.m00 * mat.m11 * mat.m22 * mat.m33;
            if (lDet == 0.0f)
                panic("non-invertible matrix");
            float invDet = 1.0f / lDet;
            mat4 tmp = mat4.identity;
            tmp.m00 = mat.m12 * mat.m23 * mat.m31 - mat.m13 * mat.m22 * mat.m31
                + mat.m13 * mat.m21 * mat.m32 - mat.m11 * mat.m23 * mat.m32 - mat.m12
                * mat.m21 * mat.m33 + mat.m11 * mat.m22 * mat.m33;
            tmp.m01 = mat.m03 * mat.m22 * mat.m31 - mat.m02 * mat.m23 * mat.m31
                - mat.m03 * mat.m21 * mat.m32 + mat.m01 * mat.m23 * mat.m32 + mat.m02
                * mat.m21 * mat.m33 - mat.m01 * mat.m22 * mat.m33;
            tmp.m02 = mat.m02 * mat.m13 * mat.m31 - mat.m03 * mat.m12 * mat.m31
                + mat.m03 * mat.m11 * mat.m32 - mat.m01 * mat.m13 * mat.m32 - mat.m02
                * mat.m11 * mat.m33 + mat.m01 * mat.m12 * mat.m33;
            tmp.m03 = mat.m03 * mat.m12 * mat.m21 - mat.m02 * mat.m13 * mat.m21
                - mat.m03 * mat.m11 * mat.m22 + mat.m01 * mat.m13 * mat.m22 + mat.m02
                * mat.m11 * mat.m23 - mat.m01 * mat.m12 * mat.m23;
            tmp.m10 = mat.m13 * mat.m22 * mat.m30 - mat.m12 * mat.m23 * mat.m30
                - mat.m13 * mat.m20 * mat.m32 + mat.m10 * mat.m23 * mat.m32 + mat.m12
                * mat.m20 * mat.m33 - mat.m10 * mat.m22 * mat.m33;
            tmp.m11 = mat.m02 * mat.m23 * mat.m30 - mat.m03 * mat.m22 * mat.m30
                + mat.m03 * mat.m20 * mat.m32 - mat.m00 * mat.m23 * mat.m32 - mat.m02
                * mat.m20 * mat.m33 + mat.m00 * mat.m22 * mat.m33;
            tmp.m12 = mat.m03 * mat.m12 * mat.m30 - mat.m02 * mat.m13 * mat.m30
                - mat.m03 * mat.m10 * mat.m32 + mat.m00 * mat.m13 * mat.m32 + mat.m02
                * mat.m10 * mat.m33 - mat.m00 * mat.m12 * mat.m33;
            tmp.m13 = mat.m02 * mat.m13 * mat.m20 - mat.m03 * mat.m12 * mat.m20
                + mat.m03 * mat.m10 * mat.m22 - mat.m00 * mat.m13 * mat.m22 - mat.m02
                * mat.m10 * mat.m23 + mat.m00 * mat.m12 * mat.m23;
            tmp.m20 = mat.m11 * mat.m23 * mat.m30 - mat.m13 * mat.m21 * mat.m30
                + mat.m13 * mat.m20 * mat.m31 - mat.m10 * mat.m23 * mat.m31 - mat.m11
                * mat.m20 * mat.m33 + mat.m10 * mat.m21 * mat.m33;
            tmp.m21 = mat.m03 * mat.m21 * mat.m30 - mat.m01 * mat.m23 * mat.m30
                - mat.m03 * mat.m20 * mat.m31 + mat.m00 * mat.m23 * mat.m31 + mat.m01
                * mat.m20 * mat.m33 - mat.m00 * mat.m21 * mat.m33;
            tmp.m22 = mat.m01 * mat.m13 * mat.m30 - mat.m03 * mat.m11 * mat.m30
                + mat.m03 * mat.m10 * mat.m31 - mat.m00 * mat.m13 * mat.m31 - mat.m01
                * mat.m10 * mat.m33 + mat.m00 * mat.m11 * mat.m33;
            tmp.m23 = mat.m03 * mat.m11 * mat.m20 - mat.m01 * mat.m13 * mat.m20
                - mat.m03 * mat.m10 * mat.m21 + mat.m00 * mat.m13 * mat.m21 + mat.m01
                * mat.m10 * mat.m23 - mat.m00 * mat.m11 * mat.m23;
            tmp.m30 = mat.m12 * mat.m21 * mat.m30 - mat.m11 * mat.m22 * mat.m30
                - mat.m12 * mat.m20 * mat.m31 + mat.m10 * mat.m22 * mat.m31 + mat.m11
                * mat.m20 * mat.m32 - mat.m10 * mat.m21 * mat.m32;
            tmp.m31 = mat.m01 * mat.m22 * mat.m30 - mat.m02 * mat.m21 * mat.m30
                + mat.m02 * mat.m20 * mat.m31 - mat.m00 * mat.m22 * mat.m31 - mat.m01
                * mat.m20 * mat.m32 + mat.m00 * mat.m21 * mat.m32;
            tmp.m32 = mat.m02 * mat.m11 * mat.m30 - mat.m01 * mat.m12 * mat.m30
                - mat.m02 * mat.m10 * mat.m31 + mat.m00 * mat.m12 * mat.m31 + mat.m01
                * mat.m10 * mat.m32 - mat.m00 * mat.m11 * mat.m32;
            tmp.m33 = mat.m01 * mat.m12 * mat.m20 - mat.m02 * mat.m11 * mat.m20
                + mat.m02 * mat.m10 * mat.m21 - mat.m00 * mat.m12 * mat.m21 - mat.m01
                * mat.m10 * mat.m22 + mat.m00 * mat.m11 * mat.m22;

            tmp.m00 = tmp.m00 * invDet;
            tmp.m01 = tmp.m01 * invDet;
            tmp.m02 = tmp.m02 * invDet;
            tmp.m03 = tmp.m03 * invDet;
            tmp.m10 = tmp.m10 * invDet;
            tmp.m11 = tmp.m11 * invDet;
            tmp.m12 = tmp.m12 * invDet;
            tmp.m13 = tmp.m13 * invDet;
            tmp.m20 = tmp.m20 * invDet;
            tmp.m21 = tmp.m21 * invDet;
            tmp.m22 = tmp.m22 * invDet;
            tmp.m23 = tmp.m23 * invDet;
            tmp.m30 = tmp.m30 * invDet;
            tmp.m31 = tmp.m31 * invDet;
            tmp.m32 = tmp.m32 * invDet;
            tmp.m33 = tmp.m33 * invDet;
            return tmp;
        }

        float det3x3()
        {
            return m00 * m11 * m22 + m01 * m12 * m20 + m02 * m10 * m21 - m00 * m12 * m21
                - m01 * m10 * m22 - m02 * m11 * m20;
        }

        v3 get_translation()
        {        
    	    v3 position;
    	    position.x = m03;
    	    position.y = m13;
    	    position.z = m23;
    	    return position;
        }
        
        bool has_rot_or_scl () {
            return !(m00 == 1 && m11 == 1 &&  m22 == 1
                     &&  m01 == 0 
                     &&  m02 == 0 
                     &&  m10 == 0 
                     &&  m12 == 0
                     &&  m20 == 0 
                     &&  m21 == 0);
        }
    }
    static mat4 create_orthographic_offcenter(float x, float y, float width, float height)
    {
        return create_orthographic(x, x + width, y, y + height, 0, 1);
    }

    static mat4 create_orthographic(float left, float right, float bottom,
            float top, float near = 0f, float far = 1f)
    {
        auto ret = mat4.identity();

        float x_orth = 2 / (right - left);
        float y_orth = 2 / (top - bottom);
        float z_orth = -2 / (far - near);

        float tx = -(right + left) / (right - left);
        float ty = -(top + bottom) / (top - bottom);
        float tz = -(far + near) / (far - near);

        ret.m00 = x_orth;
        ret.m10 = 0;
        ret.m20 = 0;
        ret.m30 = 0;
        ret.m01 = 0;
        ret.m11 = y_orth;
        ret.m21 = 0;
        ret.m31 = 0;
        ret.m02 = 0;
        ret.m12 = 0;
        ret.m22 = z_orth;
        ret.m32 = 0;
        ret.m03 = tx;
        ret.m13 = ty;
        ret.m23 = tz;
        ret.m33 = 1;

        return ret;
    }

    static mat4 create_look_at(v3 position, v3 target, v3 up)
    {

        auto tmp = target - position;

        auto ret = create_look_at(tmp, up) * createTranslation(-position.x,
                -position.y, -position.z);

        return ret;
    }

    pragma(inline)
    static mat4 createTranslation(float x, float y, float z)
    {
        auto ret = mat4.identity();
        ret.m03 = x;
        ret.m13 = y;
        ret.m23 = z;
        return ret;
    }

    pragma(inline)
    static mat4 createRotation(v3 axis, float degrees)
    {
        not_implemented();
        return mat4.identity();
    }

    pragma(inline)
    static mat4 createScale(v3 scale)
    {
        auto ret = mat4.identity;
        ret.m00 = scale.x;
        ret.m01 = 0;
        ret.m02 = 0;
        ret.m03 = 0;
        ret.m10 = 0;
        ret.m11 = scale.y;
        ret.m12 = 0;
        ret.m13 = 0;
        ret.m20 = 0;
        ret.m21 = 0;
        ret.m22 = scale.z;
        ret.m23 = 0;
        ret.m30 = 0;
        ret.m31 = 0;
        ret.m32 = 0;
        ret.m33 = 1;
        return ret;
    }

    pragma(inline)
    static mat4 create_projection(float near, float far, float fovy, float aspectRatio)
    {
        auto ret = mat4.identity();
        float l_fd = cast(float)(1.0 / tanf((fovy * (PI / 180)) / 2.0));
        float l_a1 = (far + near) / (near - far);
        float l_a2 = (2 * far * near) / (near - far);
        ret.m00 = l_fd / aspectRatio;
        ret.m10 = 0;
        ret.m20 = 0;
        ret.m30 = 0;
        ret.m01 = 0;
        ret.m11 = l_fd;
        ret.m21 = 0;
        ret.m31 = 0;
        ret.m02 = 0;
        ret.m12 = 0;
        ret.m22 = l_a1;
        ret.m32 = -1;
        ret.m03 = 0;
        ret.m13 = 0;
        ret.m23 = l_a2;
        ret.m33 = 0;
        return ret;
    }

    pragma(inline)
    static mat4 create_look_at(v3 direction, v3 up)
    {
        auto l_vez = direction.nor();
        auto l_vex = direction.nor();

        l_vex = l_vex.crs(up).nor();
        auto l_vey = l_vex.crs(l_vez).nor();

        auto ret = mat4.identity();
        ret.m00 = l_vex.x;
        ret.m01 = l_vex.y;
        ret.m02 = l_vex.z;
        ret.m10 = l_vey.x;
        ret.m11 = l_vey.y;
        ret.m12 = l_vey.z;
        ret.m20 = -l_vez.x;
        ret.m21 = -l_vez.y;
        ret.m22 = -l_vez.z;

        return ret;
    }

    pragma(inline)
    static mat4 set(float translationX, float translationY, float translationZ, float quaternionX, float quaternionY, float quaternionZ, float quaternionW)
    {
        float xs = quaternionX * 2.0f, ys = quaternionY * 2.0f, zs = quaternionZ * 2.0f;
        float wx = quaternionW * xs, wy = quaternionW * ys, wz = quaternionW * zs;
        float xx = quaternionX * xs, xy = quaternionX * ys, xz = quaternionX * zs;
        float yy = quaternionY * ys, yz = quaternionY * zs, zz = quaternionZ * zs;

        mat4 ret;
        ret.m00 = (1.0f - (yy + zz));
        ret.m01 = (xy - wz);
        ret.m02 = (xz + wy);
        ret.m03 = translationX;

        ret.m10 = (xy + wz);
        ret.m11 = (1.0f - (xx + zz));
        ret.m12 = (yz - wx);
        ret.m13 = translationY;

        ret.m20 = (xz - wy);
        ret.m21 = (yz + wx);
        ret.m22 = (1.0f - (xx + yy));
        ret.m23 = translationZ;

        ret.m30 = 0.0f;
        ret.m31 = 0.0f;
        ret.m32 = 0.0f;
        ret.m33 = 1.0f;
        return ret;
    }

    pragma(inline)
    static mat4 set(in v3 translation, in quat rotation)
    {
        float xs = rotation.x * 2.0f, ys = rotation.y * 2.0f, zs = rotation.z * 2.0f;
        float wx = rotation.w * xs, wy = rotation.w * ys, wz = rotation.w * zs;
        float xx = rotation.x * xs, xy = rotation.x * ys, xz = rotation.x * zs;
        float yy = rotation.y * ys, yz = rotation.y * zs, zz = rotation.z * zs;

        auto ret = mat4.identity();
        ret.m00 = (1.0f - (yy + zz));
        ret.m01 = (xy - wz);
        ret.m02 = (xz + wy);
        ret.m03 = translation.x;

        ret.m10 = (xy + wz);
        ret.m11 = (1.0f - (xx + zz));
        ret.m12 = (yz - wx);
        ret.m13 = translation.y;

        ret.m20 = (xz - wy);
        ret.m21 = (yz + wx);
        ret.m22 = (1.0f - (xx + yy));
        ret.m23 = translation.z;

        ret.m30 = 0.0f;
        ret.m31 = 0.0f;
        ret.m32 = 0.0f;
        ret.m33 = 1.0f;
        return ret;
    }

    pragma(inline)
    static mat4 set(in v3 translation, in quat rotation, in v3 scale)
    {
        float xs = rotation.x * 2.0f, ys = rotation.y * 2.0f, zs = rotation.z * 2.0f;
        float wx = rotation.w * xs, wy = rotation.w * ys, wz = rotation.w * zs;
        float xx = rotation.x * xs, xy = rotation.x * ys, xz = rotation.x * zs;
        float yy = rotation.y * ys, yz = rotation.y * zs, zz = rotation.z * zs;

        auto ret = mat4.identity();
        ret.m00 = scale.x * (1.0f - (yy + zz));
        ret.m01 = scale.y * (xy - wz);
        ret.m02 = scale.z * (xz + wy);
        ret.m03 = translation.x;

        ret.m10 = scale.x * (xy + wz);
        ret.m11 = scale.y * (1.0f - (xx + zz));
        ret.m12 = scale.z * (yz - wx);
        ret.m13 = translation.y;

        ret.m20 = scale.x * (xz - wy);
        ret.m21 = scale.y * (yz + wx);
        ret.m22 = scale.z * (1.0f - (xx + yy));
        ret.m23 = translation.z;

        ret.m30 = 0.0f;
        ret.m31 = 0.0f;
        ret.m32 = 0.0f;
        ret.m33 = 1.0f;
        return ret;
    }

    pragma(inline)
    static mat4 mult(in mat4 lhs, in mat4 rhs)
    {
        return mat4(lhs.m00 * rhs.m00 + lhs.m01 * rhs.m10 + lhs.m02 * rhs.m20 + lhs.m03 * rhs.m30,
                lhs.m10 * rhs.m00 + lhs.m11 * rhs.m10 + lhs.m12 * rhs.m20 + lhs.m13 * rhs.m30,
                lhs.m20 * rhs.m00 + lhs.m21 * rhs.m10 + lhs.m22 * rhs.m20 + lhs.m23 * rhs.m30,
                lhs.m30 * rhs.m00 + lhs.m31 * rhs.m10 + lhs.m32 * rhs.m20 + lhs.m33 * rhs.m30,

                lhs.m00 * rhs.m01 + lhs.m01 * rhs.m11 + lhs.m02 * rhs.m21 + lhs.m03 * rhs.m31,
                lhs.m10 * rhs.m01 + lhs.m11 * rhs.m11 + lhs.m12 * rhs.m21 + lhs.m13 * rhs.m31,
                lhs.m20 * rhs.m01 + lhs.m21 * rhs.m11 + lhs.m22 * rhs.m21 + lhs.m23 * rhs.m31,
                lhs.m30 * rhs.m01 + lhs.m31 * rhs.m11 + lhs.m32 * rhs.m21 + lhs.m33 * rhs.m31,

                lhs.m00 * rhs.m02 + lhs.m01 * rhs.m12 + lhs.m02 * rhs.m22 + lhs.m03 * rhs.m32,
                lhs.m10 * rhs.m02 + lhs.m11 * rhs.m12 + lhs.m12 * rhs.m22 + lhs.m13 * rhs.m32,
                lhs.m20 * rhs.m02 + lhs.m21 * rhs.m12 + lhs.m22 * rhs.m22 + lhs.m23 * rhs.m32,
                lhs.m30 * rhs.m02 + lhs.m31 * rhs.m12 + lhs.m32 * rhs.m22 + lhs.m33 * rhs.m32,

                lhs.m00 * rhs.m03 + lhs.m01 * rhs.m13 + lhs.m02 * rhs.m23 + lhs.m03 * rhs.m33,
                lhs.m10 * rhs.m03 + lhs.m11 * rhs.m13 + lhs.m12 * rhs.m23 + lhs.m13 * rhs.m33,
                lhs.m20 * rhs.m03 + lhs.m21 * rhs.m13 + lhs.m22 * rhs.m23 + lhs.m23 * rhs.m33,
                lhs.m30 * rhs.m03 + lhs.m31 * rhs.m13 + lhs.m32 * rhs.m23 + lhs.m33 * rhs.m33);
    }

    pragma(inline)
    mat4 opBinary(string op)(mat4 rhs)
    {
        static if (op == "*")
            return mat4(m00 * rhs.m00 + m01 * rhs.m10 + m02 * rhs.m20 + m03 * rhs.m30,
                    m10 * rhs.m00 + m11 * rhs.m10 + m12 * rhs.m20 + m13 * rhs.m30,
                    m20 * rhs.m00 + m21 * rhs.m10 + m22 * rhs.m20 + m23 * rhs.m30,
                    m30 * rhs.m00 + m31 * rhs.m10 + m32 * rhs.m20 + m33 * rhs.m30,

                    m00 * rhs.m01 + m01 * rhs.m11 + m02 * rhs.m21 + m03 * rhs.m31,
                    m10 * rhs.m01 + m11 * rhs.m11 + m12 * rhs.m21 + m13 * rhs.m31,
                    m20 * rhs.m01 + m21 * rhs.m11 + m22 * rhs.m21 + m23 * rhs.m31,
                    m30 * rhs.m01 + m31 * rhs.m11 + m32 * rhs.m21 + m33 * rhs.m31,

                    m00 * rhs.m02 + m01 * rhs.m12 + m02 * rhs.m22 + m03 * rhs.m32,
                    m10 * rhs.m02 + m11 * rhs.m12 + m12 * rhs.m22 + m13 * rhs.m32,
                    m20 * rhs.m02 + m21 * rhs.m12 + m22 * rhs.m22 + m23 * rhs.m32,
                    m30 * rhs.m02 + m31 * rhs.m12 + m32 * rhs.m22 + m33 * rhs.m32,

                    m00 * rhs.m03 + m01 * rhs.m13 + m02 * rhs.m23 + m03 * rhs.m33,
                    m10 * rhs.m03 + m11 * rhs.m13 + m12 * rhs.m23 + m13 * rhs.m33,
                    m20 * rhs.m03 + m21 * rhs.m13 + m22 * rhs.m23 + m23 * rhs.m33,
                    m30 * rhs.m03 + m31 * rhs.m13 + m32 * rhs.m23 + m33 * rhs.m33);
        else
            static assert(0, "Operator " ~ op ~ " not implemented");
    }

    pragma(inline)
    static mat4 multiply(in mat4 lhs, in mat4 rhs)
    {
        return mat4(lhs.m00 * rhs.m00 + lhs.m01 * rhs.m10 + lhs.m02 * rhs.m20 + lhs.m03 * rhs.m30,
                lhs.m10 * rhs.m00 + lhs.m11 * rhs.m10 + lhs.m12 * rhs.m20 + lhs.m13 * rhs.m30,
                lhs.m20 * rhs.m00 + lhs.m21 * rhs.m10 + lhs.m22 * rhs.m20 + lhs.m23 * rhs.m30,
                lhs.m30 * rhs.m00 + lhs.m31 * rhs.m10 + lhs.m32 * rhs.m20 + lhs.m33 * rhs.m30,

                lhs.m00 * rhs.m01 + lhs.m01 * rhs.m11 + lhs.m02 * rhs.m21 + lhs.m03 * rhs.m31,
                lhs.m10 * rhs.m01 + lhs.m11 * rhs.m11 + lhs.m12 * rhs.m21 + lhs.m13 * rhs.m31,
                lhs.m20 * rhs.m01 + lhs.m21 * rhs.m11 + lhs.m22 * rhs.m21 + lhs.m23 * rhs.m31,
                lhs.m30 * rhs.m01 + lhs.m31 * rhs.m11 + lhs.m32 * rhs.m21 + lhs.m33 * rhs.m31,

                lhs.m00 * rhs.m02 + lhs.m01 * rhs.m12 + lhs.m02 * rhs.m22 + lhs.m03 * rhs.m32,
                lhs.m10 * rhs.m02 + lhs.m11 * rhs.m12 + lhs.m12 * rhs.m22 + lhs.m13 * rhs.m32,
                lhs.m20 * rhs.m02 + lhs.m21 * rhs.m12 + lhs.m22 * rhs.m22 + lhs.m23 * rhs.m32,
                lhs.m30 * rhs.m02 + lhs.m31 * rhs.m12 + lhs.m32 * rhs.m22 + lhs.m33 * rhs.m32,

                lhs.m00 * rhs.m03 + lhs.m01 * rhs.m13 + lhs.m02 * rhs.m23 + lhs.m03 * rhs.m33,
                lhs.m10 * rhs.m03 + lhs.m11 * rhs.m13 + lhs.m12 * rhs.m23 + lhs.m13 * rhs.m33,
                lhs.m20 * rhs.m03 + lhs.m21 * rhs.m13 + lhs.m22 * rhs.m23 + lhs.m23 * rhs.m33,
                lhs.m30 * rhs.m03 + lhs.m31 * rhs.m13 + lhs.m32 * rhs.m23 + lhs.m33 * rhs.m33);
    }
}

struct quat
{
    float x = 0f;
    float y = 0f;
    float z = 0f;
    float w = 0f;

    this(float x, float y, float z, float w)
    {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }

    pragma(inline)
    float len2()
    {
        return x * x + y * y + z * z + w * w;
    }

    pragma(inline)
    quat nor()
    {
        float invMagnitude = 1f / cast(float) sqrt(x * x + y * y + z * z + w * w);
        x *= invMagnitude;
        y *= invMagnitude;
        z *= invMagnitude;
        w *= invMagnitude;
        return this;
    }

    pragma(inline)
    void slerp(in quat end, float alpha)
    {
        float d = x * end.x + y * end.y + z * end.z + w * end.w;
        float absDot = d < 0.0f ? -d : d;

        // Set the first and second scale for the interpolation
        float scale0 = 1.0f - alpha;
        float scale1 = alpha;

        // Check if the angle between the 2 quaternions was big enough to
        // warrant such calculations
        if ((1 - absDot) > 0.1)
        { // Get the angle between the 2 quaternions,
            // and then store the sin() of that angle
            float angle = cast(float) acosf(absDot);
            float invSinTheta = 1.0f / cast(float) sinf(angle);

            // Calculate the scale for q1 and q2, according to the angle and
            // it's sine value
            scale0 = (sinf((1.0f - alpha) * angle) * invSinTheta);
            scale1 = (sinf((alpha * angle)) * invSinTheta);
        }

        if (d < 0.0f)
            scale1 = -scale1;

        // Calculate the x, y, z and w values for the quaternion by using a
        // special form of linear interpolation for quaternions.
        x = (scale0 * x) + (scale1 * end.x);
        y = (scale0 * y) + (scale1 * end.y);
        z = (scale0 * z) + (scale1 * end.z);
        w = (scale0 * w) + (scale1 * end.w);
    }

    pragma(inline)
    static quat identity()
    {
        return quat(0, 0, 0, 1);
    }

    pragma(inline)
    static quat fromAxis(float x, float y, float z, float rad)
    {
        float d = v3.len(x, y, z);
        if (d == 0f)
            return quat.identity;
        d = 1f / d;
        float l_ang = rad < 0 ? PI2 - (-rad % PI2) : rad % PI2;
        float l_sin = sinf(l_ang / 2);
        float l_cos = cosf(l_ang / 2);

        return quat(d * x * l_sin, d * y * l_sin, d * z * l_sin, l_cos).nor();
    }

    pragma(inline)
    static quat fromAxis(in v3 axis, float rad)
    {
        return fromAxis(axis.x, axis.y, axis.z, rad);
    }

    pragma(inline)
    static quat slerp(in quat quaternion1, quat quaternion2, float amount)
    {
        float num2;
        float num3;
        quat quaternion;
        float num = amount;
        float num4 = (((quaternion1.x * quaternion2.x) + (
                quaternion1.y * quaternion2.y)) + (quaternion1.z * quaternion2.z)) + (
                quaternion1.w * quaternion2.w);
        bool flag = false;
        if (num4 < 0f)
        {
            flag = true;
            num4 = -num4;
        }
        if (num4 > 0.999999f)
        {
            num3 = 1f - num;
            num2 = flag ? -num : num;
        }
        else
        {
            float num5 = acosf(num4);
            float num6 = (1.0f / sinf(num5));
            num3 = (sinf(((1f - num) * num5))) * num6;
            num2 = flag ? ((-sinf((num * num5))) * num6) : ((sinf((num * num5))) * num6);
        }
        quaternion.x = (num3 * quaternion1.x) + (num2 * quaternion2.x);
        quaternion.y = (num3 * quaternion1.y) + (num2 * quaternion2.y);
        quaternion.z = (num3 * quaternion1.z) + (num2 * quaternion2.z);
        quaternion.w = (num3 * quaternion1.w) + (num2 * quaternion2.w);
        return quaternion;
    }

    pragma(inline)
    static quat lerp(in quat lhs, in quat rhs, float t)
    {
        if (t > 1f)
        {
            return rhs;
        }
        else
        {
            if (t < 0f)
            {
                return lhs;
            }
        }

        quat res;
        res.x = (rhs.x - lhs.x) * t + lhs.x;
        res.y = (rhs.y - lhs.y) * t + lhs.y;
        res.z = (rhs.z - lhs.z) * t + lhs.z;
        res.w = (rhs.w - lhs.w) * t + lhs.w;
        res.nor();
        return res;
    }

        static quat mult(const ref quat lhs, const ref quat rhs)
        {
            quat q;
            q.w = lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z;
            q.x = lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y;
            q.y = lhs.w * rhs.y + lhs.y * rhs.w + lhs.z * rhs.x - lhs.x * rhs.z;
            q.z = lhs.w * rhs.z + lhs.z * rhs.w + lhs.x * rhs.y - lhs.y * rhs.x;
            return q;
        }
}

