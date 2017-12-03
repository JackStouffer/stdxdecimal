/*
    Adapted from the specification of the General Decimal Arithmetic.

    This implementation is rewritten for the D Programming Language and is
    licensed under the Boost Software License 1.0 and is written by Jack Stouffer
*/

module stdxdecimal;

import std.stdio;
import std.range.primitives;
import core.stdc.stdlib;
import std.traits;
import std.bigint;
import std.conv;

/**
 * Practically infinite above decimal place, limited to `long.min` number of
 * decimal places
 * 
 * Spec: http://speleotrove.com/decimal/decarith.html
 *
 * [sign, coefficient, exponent]
 */
struct Decimal
{
package:
    // 1 indicates that the number is negative or is the negative zero
    // and 0 indicates that the number is zero or positive.
    ubyte sign;
    BigInt coefficient;
    long exponent;
    // quiet NaN
    bool qNaN;
    // signaling NaN
    bool sNaN;
    bool isInfinite;

public:
    /**
     * Note: Float construction less accurate that string, Use
     * string construction if possible
     */
    this(T)(T val) if (isNumeric!T)
    {
        // the behavior of conversion from built-in number types
        // isn't covered by the spec, so we can do what ever we
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
                isInfinite = true;
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
                exponent--;
                val *= 10;
                fraction = val - (cast(long) val);
            }

            coefficient = cast(size_t) val;
        }
    }

    /**
     * implements spec to-number
     */
    this(string str)
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
        static bool charCheck(char a)
        {
            return isDigit(a) || a == 'E' || a == 'e' || a == '-' || a == '+' || a == '.';
        }

        auto codeUnits = str.byCodeUnit;

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
            isInfinite = true;
            return;
        }

        // having numbers after nan is valid in the spec
        if (codeUnits.save.map!toLower.startsWith("qnan") ||
            codeUnits.save.map!toLower.startsWith("nan"))
        {
            qNaN = true;
            return;
        }

        if (codeUnits.save.map!toLower.startsWith("snan"))
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
        // (–1)^^sign × coefficient × 10^^exponent
        import std.math : pow;
        import std.range : repeat, chain;
        import std.array : array;
        import std.utf : byCodeUnit;

        BigInt signed = coefficient * (sign ? -1 : 1);
        auto temp = signed.toDecimalString();
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
unittest
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
        bool isInfinite;
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
        auto d = Decimal(el.val);
        assert(d.coefficient == el.coefficient);
        assert(d.sign == el.sign);
        assert(d.exponent == el.exponent);
    }

    foreach (el; specialTestValues)
    {
        //writeln(el.val);
        auto d = Decimal(el.val);
        assert(d.qNaN == el.qNaN);
        assert(d.sNaN == el.sNaN);
        assert(d.isInfinite == el.isInfinite);
    }
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
        auto d = Decimal(el.val);
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
        bool isInfinite;
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
        auto d = Decimal(el.val);
        assert(d.coefficient == el.coefficient);
        assert(d.sign == el.sign);
        assert(d.exponent == el.exponent);
    }

    foreach (el; specialTestValues)
    {
        auto d = Decimal(el.val);
        assert(d.qNaN == el.qNaN);
        assert(d.sNaN == el.sNaN);
        assert(d.isInfinite == el.isInfinite);
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
    auto t = Decimal();
    t.sign = 0;
    t.coefficient = 2708;
    t.exponent = -2;
    assert(t.toString() == "27.08");

    auto t2 = Decimal();
    t2.sign = 1;
    t2.coefficient = 1953;
    t2.exponent = 0;
    assert(t2.toString() == "-1953");

    auto t3 = Decimal();
    t3.sign = 0;
    t3.coefficient = 9_888_555_555;
    t3.exponent = -4;
    assert(t3.toString() == "988855.5555");

    auto t4 = Decimal("300088.44000");
    assert(t4.toString() == "300088.44000");

    auto t5 = Decimal("30.5E10");
    assert(t5.toString() == "305000000000");

    auto t6 = Decimal(10);
    assert(t6.toString() == "10");

    auto t7 = Decimal(12345678);
    assert(t7.toString() == "12345678");

    auto t8 = Decimal(1234.5678);
    assert(t8.toString() == "1234.5678");

    auto t9 = Decimal(0.1234);
    assert(t9.toString() == "0.1234");

    auto t10 = Decimal(1234.0);
    assert(t10.toString() == "1234");
}
