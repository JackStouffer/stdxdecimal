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
    this(T)(T val) if (isNumeric!T)
    {

    }

    /**
     * implements spec to-number
     */
    this(string str)
    {
        import std.algorithm.comparison : among;
        import std.algorithm.searching : all, startsWith;
        import std.utf : byCodeUnit;
        import std.algorithm.comparison : equal;
        import std.algorithm.iteration : map, filter;
        import std.ascii : toLower, isDigit;
        import std.utf : byChar;
        import std.array : array;

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
        auto saved = codeUnits.save;
        for (; !saved.empty; saved.popFront)
        {
            auto digit = saved.front;

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
                    while (!saved.empty)
                    {
                        if (!isDigit(saved.front))
                            goto Lerr;

                        sciExponent += cast(uint) (saved.front - '0');
                        if (!saved.empty)
                        {
                            saved.popFront;
                            if (!saved.empty)
                                sciExponent *= 10;
                        }
                    }

                    if (sawExponentSign && exponentSign == -1)
                        sciExponent *= -1;

                    exponent += sciExponent;

                    if (saved.empty)
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

    bool opEquals(T)(T f) if (isFloatingPoint!T)
    {
        return false;
    }

    //bool opEquals(T)(T d) if (is(T : Decimal))
    //{
    //    if ((isInfinite == d.isInfinite && sign == d.sign))
    //    {
    //        return true;
    //    }

    //    return false;
    //}

    string toString()
    {
        // (–1)^^sign × coefficient × 10^^exponent
        import std.math : pow;

        BigInt signed = coefficient * (sign ? -1 : 1);
        auto temp = signed.toDecimalString();
        auto decimalPlace = exponent * -1;
        if (decimalPlace > 0)
        {
            return temp[0 .. $ - decimalPlace] ~ "." ~ temp[$ - decimalPlace .. $];
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
        writeln(el.val);
        auto d = Decimal(el.val);
        assert(d.coefficient == el.coefficient);
        assert(d.sign == el.sign);
        assert(d.exponent == el.exponent);
    }

    foreach (el; specialTestValues)
    {
        writeln(el.val);
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
}
