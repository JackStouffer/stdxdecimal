/*
    Adapted from the specification of the General Decimal Arithmetic.

    This implementation is written for the D Programming Language
    by Jack Stouffer and is licensed under the Boost Software License 1.0.
*/
module stdxdecimal;

import std.stdio;
import std.range.primitives;
import std.traits;
import std.conv;

/**
 * Rounding mode
 */
enum Rounding
{
    /**
     * (Round toward 0; truncate.) The discarded digits are ignored; the result is unchanged.
     */
    Down,
    /**
     * If the discarded digits represent greater than or equal to half (0.5)
     * of the value of a one in the next left position then the result coefficient
     * should be incremented by 1 (rounded up). Otherwise the discarded digits are ignored.
     */
    HalfUp,
    /**
     * If the discarded digits represent greater than half (0.5) the value of a
     * one in the next left position then the result coefficient should be
     * incremented by 1 (rounded up). If they represent less than half, then the
     * result coefficient is not adjusted (that is, the discarded digits are ignored).
     *
     * Otherwise (they represent exactly half) the result coefficient is unaltered
     * if its rightmost digit is even, or incremented by 1 (rounded up) if its
     * rightmost digit is odd (to make an even digit).
     */
    HalfEven,
    /**
     * If all of the discarded digits are zero or if the sign is 1 the result is
     * unchanged. Otherwise, the result coefficient should be incremented by 1
     * (rounded up).
     */
    Ceiling,
    /**
     * If all of the discarded digits are zero or if the sign is 0 the result is
     * unchanged. Otherwise, the sign is 1 and the result coefficient should be
     * incremented by 1.
     */
    Floor,
    /**
     * If the discarded digits represent greater than half (0.5) of the value of
     * a one in the next left position then the result coefficient should be
     * incremented by 1 (rounded up). Otherwise (the discarded digits are 0.5 or
     * less) the discarded digits are ignored.
     */
    HalfDown,
    /**
     * (Round away from 0.) If all of the discarded digits are zero the result is
     * unchanged. Otherwise, the result coefficient should be incremented by 1 (rounded up).
     */
    Up,
    /**
     * (Round zero or five away from 0.) The same as round-up, except that rounding
     * up only occurs if the digit to be rounded up is 0 or 5, and after overflow
     * the result is the same as for round-down.
     */
    ZeroFiveUp
}

/**
 * Practically infinite above decimal place, limited to `abs(long.min)` number of
 * decimal places
 * 
 * Spec: http://speleotrove.com/decimal/decarith.html
 *
 * [sign, coefficient, exponent]
 */
struct Decimal(ulong precision = 9, Rounding mode = Rounding.HalfUp, Hook = DefaultHook)
{
    import std.experimental.allocator.common : stateSize;

package:
    // 1 indicates that the number is negative or is the negative zero
    // and 0 indicates that the number is zero or positive.
    bool sign;
    // quiet NaN
    bool qNaN;
    // signaling NaN
    bool sNaN;
    bool inf;

    // actual value of decimal given as (–1)^^sign × coefficient × 10^^exponent
    // TODO, given high enough precision, or some other argument, this should
    // automatically become a BigInt
    ulong coefficient;
    long exponent;

public:
    /**
     * `hook` is a member variable if it has state, or an alias for `Hook`
     * otherwise.
     */
    static if (stateSize!Hook > 0)
        Hook hook;
    else
        alias hook = Hook;

    /// Public flags
    bool clamped;
    /// ditto
    bool divisionByZero;
    /// ditto
    bool inexact;
    /// ditto
    bool invalidOperation;
    /// ditto
    bool overflow;
    /// ditto
    bool rounded;
    /// ditto
    bool subnormal;
    /// ditto
    bool underflow;

    /**
     * Note: Float construction less accurate that string, Use
     * string construction if possible
     */
    this(T)(T val) if (isNumeric!T)
    {
        // the behavior of conversion from built-in number types
        // isn't covered by the spec, so we can do whatever we
        // want here

        static if (isIntegral!T)
        {
            import std.math : abs;

            coefficient = abs(val);
            sign = val >= 0 ? 0 : 1;
        }
        else
        {
            import std.math : abs, isInfinity, isNaN;

            if (isInfinity(val))
            {
                inf = true;
                sign = val < 0 ? 0 : 1;
                return;
            }

            if (isNaN(val))
            {
                qNaN = true;
                sign = val == T.nan ? 0 : 1;
                return;
            }

            sign = val >= 0 ? 0 : 1;
            val = abs(val);

            // while the number still has a fractional part, multiply by 10,
            // counting each time until no fractional part
            T fraction = val - (cast(long) val);
            while (fraction > 0)
            {
                --exponent;
                val *= 10;
                fraction = val - (cast(long) val);
            }

            coefficient = cast(size_t) val;
        }
    }

    /**
     * implements spec to-number
     */
    this(S)(S str) if (isForwardRange!S && isSomeChar!(ElementEncodingType!S) && !isInfinite!S)
    {
        import std.algorithm.comparison : among, equal;
        import std.algorithm.iteration : filter, map;
        import std.algorithm.searching : startsWith;
        import std.ascii : isDigit, toLower;
        import std.utf : byChar, byCodeUnit;

        static bool asciiCmp(S1)(S1 a, string b)
        {
            return a.map!toLower.equal(b.byChar.map!toLower);
        }

        // valid characters in non-special number strings
        static bool charCheck(dchar a)
        {
            return isDigit(a) || a == 'E' || a == 'e' || a == '-' || a == '+' || a == '.';
        }

        static if (isSomeString!S)
            auto codeUnits = str.byCodeUnit;
        else
            alias codeUnits = str;

        if (codeUnits.empty)
        {
            qNaN = true;
            return;
        }

        immutable frontResult = codeUnits.front;
        if (frontResult == '+')
        {
            codeUnits.popFront;
        }
        if (frontResult == '-')
        {
            sign = 1;
            codeUnits.popFront;
        }

        if (codeUnits.empty)
        {
            sign = 0;
            qNaN = true;
            return;
        }

        if (codeUnits.among!((a, b) => asciiCmp(a.save, b))
               ("inf", "infinity"))
        {
            inf = true;
            return;
        }

        // having numbers after nan is valid in the spec
        if (codeUnits.save.map!toLower.startsWith("qnan".byChar) ||
            codeUnits.save.map!toLower.startsWith("nan".byChar))
        {
            qNaN = true;
            return;
        }

        if (codeUnits.save.map!toLower.startsWith("snan".byChar))
        {
            sNaN = true;
            return;
        }

        bool sawDecimal = false;
        bool sawExponent = false;
        bool sawExponentSign = false;
        byte exponentSign;
        long sciExponent = 0;
        for (; !codeUnits.empty; codeUnits.popFront)
        {
            auto digit = codeUnits.front;

            if (!charCheck(digit))
                goto Lerr;

            if (isDigit(digit))
            {
                if (!sawExponent)
                {
                    coefficient *= 10;
                    coefficient += cast(uint) (digit - '0');
                }

                if (sawDecimal && !sawExponent)
                    exponent--;

                if (sawExponent)
                {
                    while (!codeUnits.empty)
                    {
                        if (!isDigit(codeUnits.front))
                            goto Lerr;

                        sciExponent += cast(uint) (codeUnits.front - '0');
                        if (!codeUnits.empty)
                        {
                            codeUnits.popFront;
                            if (!codeUnits.empty)
                                sciExponent *= 10;
                        }
                    }

                    if (sawExponentSign && exponentSign == -1)
                        sciExponent *= -1;

                    exponent += sciExponent;

                    if (codeUnits.empty)
                        return;
                }
            }

            if (digit == '+' || digit == '-')
            {
                // already have exponent sign, bad input so cancel out
                if (sawExponentSign)
                    goto Lerr;

                if (sawExponent)
                {
                    if (digit == '-')
                        exponentSign = -1;
                    sawExponentSign = true;
                }
                else
                { // no exponent yet, bad input so cancel out
                    goto Lerr;
                }
            }

            if (digit == '.')
            {
                // already have decimal, bad input so cancel out
                if (sawDecimal)
                    goto Lerr;

                sawDecimal = true;
            }

            if (digit.toLower == 'e')
            {
                // already have exponent, bad input so cancel out
                if (sawExponent)
                    goto Lerr;

                sawExponent = true;
            }
        }
        return;

        Lerr:
            qNaN = true;
            coefficient = 0;
            exponent = 0;
            return;
    }

    bool opEquals(T)(T f) if (isNumeric!T)
    {
        return false;
    }

    bool opEquals(T)(T d) if (is(T : Decimal))
    {
        return false;
    }

    string toString()
    {
        import std.math : pow;
        import std.range : repeat, chain;
        import std.array : array;
        import std.utf : byCodeUnit;

        auto temp = coefficient.to!string;
        if (sign == 1)
            temp = "-" ~ temp;

        auto decimalPlace = exponent * -1;
        
        if (decimalPlace > 0)
        {
            if (temp.length - decimalPlace == 0)
                return "0." ~ temp;

            return temp[0 .. $ - decimalPlace] ~ "." ~ temp[$ - decimalPlace .. $];
        }

        if (decimalPlace < 0)
        {
            return temp.byCodeUnit.chain('0'.repeat(exponent)).array;
        }

        return temp;
    }
}

// string construction
@safe pure nothrow unittest
{
    static struct Test
    {
        string val;
        ubyte sign;
        int coefficient;
        long exponent;
    }

    static struct SpecialTest
    {
        string val;
        ubyte sign;
        bool qNaN;
        bool sNaN;
        bool inf;
    }

    auto nonspecialTestValues = [
        Test("1.0", 0, 10, -1),
        Test("0E+7", 0, 0, 7),
        Test("-0E-7", 1, 0, -7),
        Test("1.23E3", 0, 123, 1),
        Test("0001.0000", 0, 10000, -4),
        Test("-10.0004", 1, 100004, -4),
        Test("+15", 0, 15, 0),
        Test("-15", 1, 15, 0),
        Test("1234.5E-4", 0, 12345, -5),
        Test("30.5E10", 0, 305, 9) 
    ];

    auto specialTestValues = [
        SpecialTest("NaN", 0, true, false, false),
        SpecialTest("+nan", 0, true, false, false),
        SpecialTest("-nan", 1, true, false, false),
        SpecialTest("-NAN", 1, true, false, false),
        SpecialTest("Infinite", 0, true, false, false),
        SpecialTest("inf", 0, false, false, true),
        SpecialTest("-inf", 1, false, false, true),
        SpecialTest("snan", 0, false, true, false),
        SpecialTest("-snan", 1, false, true, false),
        SpecialTest("Jack", 0, true, false, false),
        SpecialTest("+", 0, true, false, false),
        SpecialTest("-", 0, true, false, false),
        SpecialTest("nan0123", 0, true, false, false),
        SpecialTest("-nan0123", 1, true, false, false),
        SpecialTest("snan0123", 0, false, true, false),
        SpecialTest("12+3", 0, true, false, false),
        SpecialTest("1.2.3", 0, true, false, false),
        SpecialTest("123.0E+7E+7", 0, true, false, false),
    ];

    foreach (el; nonspecialTestValues)
    {
        //writeln(el.val);
        auto d = Decimal!()(el.val);
        assert(d.coefficient == el.coefficient);
        assert(d.sign == el.sign);
        assert(d.exponent == el.exponent);
    }

    foreach (el; specialTestValues)
    {
        //writeln(el.val);
        auto d = Decimal!()(el.val);
        assert(d.qNaN == el.qNaN);
        assert(d.sNaN == el.sNaN);
        assert(d.inf == el.inf);
    }
}

// range construction
unittest
{
    import std.internal.test.dummyrange;
    import std.utf;
    auto r1 = new ReferenceForwardRange!dchar("123.456");
    auto d1 = Decimal!()(r1);
    assert(d1.coefficient == 123456);
    assert(d1.sign == 0);
    assert(d1.exponent == -3);

    auto r2 = new ReferenceForwardRange!dchar("-0.00004");
    auto d2 = Decimal!()(r2);
    assert(d2.coefficient == 4);
    assert(d2.sign == 1);
    assert(d2.exponent == -5);
}

// int construction
unittest
{
    static struct Test
    {
        long val;
        ubyte sign;
        long coefficient;
    }

    auto testValues = [
        Test(10, 0, 10),
        Test(-10, 1, 10),
        Test(-1000000, 1, 1000000),
        Test(long.max, 0, long.max),
        Test(long.min, 1, long.min),
    ];

    foreach (el; testValues)
    {
        //writeln(el.val);
        auto d = Decimal!()(el.val);
        assert(d.coefficient == el.coefficient);
        assert(d.sign == el.sign);
    }
}

// float construction
unittest
{
    static struct Test
    {
        double val;
        ubyte sign;
        int coefficient;
        long exponent;
    }

    static struct SpecialTest
    {
        double val;
        ubyte sign;
        bool qNaN;
        bool sNaN;
        bool inf;
    }

    auto nonspecialTestValues = [
        Test(0.02, 0, 2, -2),
        Test(0.00002, 0, 2, -5),
        Test(1.02, 0, 102, -2),
        Test(200.0, 0, 200, 0),
        Test(1234.5678, 0, 12345678, -4),
        Test(-1234.5678, 1, 12345678, -4),
        Test(-1234, 1, 1234, 0),
    ];

    auto specialTestValues = [
        SpecialTest(float.nan, 0, true, false, false),
        SpecialTest(-float.nan, 1, true, false, false),
        SpecialTest(float.infinity, 0, false, false, true),
        SpecialTest(-float.infinity, 1, false, false, true),
    ];

    foreach (el; nonspecialTestValues)
    {
        auto d = Decimal!()(el.val);
        assert(d.coefficient == el.coefficient);
        assert(d.sign == el.sign);
        assert(d.exponent == el.exponent);
    }

    foreach (el; specialTestValues)
    {
        auto d = Decimal!()(el.val);
        assert(d.qNaN == el.qNaN);
        assert(d.sNaN == el.sNaN);
        assert(d.inf == el.inf);
    }
}

// equals float
unittest
{
    //auto a = Decimal("1.0");
    //assert(a == 1.0);

    //auto b = Decimal("0001.0000");
    //assert(b == 1.0);

    //auto c = Decimal(1.0);
    //assert(c == 1.0);

    //auto d = Decimal(1);
    //assert(d == 1.0);
}

// to string
unittest
{
    auto t = Decimal!()();
    t.sign = 0;
    t.coefficient = 2708;
    t.exponent = -2;
    assert(t.toString() == "27.08");

    auto t2 = Decimal!()();
    t2.sign = 1;
    t2.coefficient = 1953;
    t2.exponent = 0;
    assert(t2.toString() == "-1953");

    auto t3 = Decimal!()();
    t3.sign = 0;
    t3.coefficient = 9_888_555_555;
    t3.exponent = -4;
    assert(t3.toString() == "988855.5555");

    auto t4 = Decimal!()("300088.44000");
    assert(t4.toString() == "300088.44000");

    auto t5 = Decimal!()("30.5E10");
    assert(t5.toString() == "305000000000");

    auto t6 = Decimal!()(10);
    assert(t6.toString() == "10");

    auto t7 = Decimal!()(12345678);
    assert(t7.toString() == "12345678");

    auto t8 = Decimal!()(1234.5678);
    assert(t8.toString() == "1234.5678");

    auto t9 = Decimal!()(0.1234);
    assert(t9.toString() == "0.1234");

    auto t10 = Decimal!()(1234.0);
    assert(t10.toString() == "1234");
}

/**
 * Factory function
 */
auto decimal(R, ulong precision = 9, Rounding mode = Rounding.HalfUp, Hook = DefaultHook)(R r)
if ((isForwardRange!R &&
    isSomeChar!(ElementEncodingType!R) &&
    !isInfinite!R) || isNumeric!R)
{
    return Decimal!(precision, mode, Hook)(r);
}

unittest
{
    auto d1 = decimal(5.5);
    assert(d1.toString == "5.5");
    //assert(d1 == 5.5);
}

/**
 * spec "Basic default context"
 *
 * Will halt program on division by zero, invalid operations,
 * overflows, and underflows
 */
struct DefaultHook
{
    ///
    static void onDivisionByZero(T)(T d) if (isInstanceOf!(Decimal, T))
    {
        assert(0, "Division by zero");
    }

    ///
    static void onInvalidOperation(T)(T d) if (isInstanceOf!(Decimal, T))
    {
        assert(0, "Invalid operation");
    }

    ///
    static void onOverflow(T)(T d) if (isInstanceOf!(Decimal, T))
    {
        assert(0, "Overflow");
    }

    ///
    static void onUnderflow(T)(T d) if (isInstanceOf!(Decimal, T))
    {
        assert(0, "Underflow");
    }
}
