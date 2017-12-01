/*
    Adapted from the reference implementation of the General Decimal Arithmetic
    specification from the international Components for Unicode under the 
    permissive ICU License.

    This implementation is rewritten for the D Programming Language and is
    relicensed under the Boost Software License 1.0 and is written by Jack Stouffer
*/

module stdxdecimal;

import std.stdio;
import core.stdc.stdlib;
import std.traits;
import std.bigint;
import std.conv;

/**
 * Spec: http://speleotrove.com/decimal/decarith.html
 *
 * [sign, coefficient, exponent]
 */
struct Decimal
{
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

    this(T)(T val) if (isNumeric!T)
    {

    }

    this(string str)
    {

    }

    bool opEquals(T)(T f) if (isFloatingPoint!T)
    {
        return false;
    }

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

// construction
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

unittest {
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
    writeln(t3.toString());
    assert(t3.toString() == "988855.5555");
}
