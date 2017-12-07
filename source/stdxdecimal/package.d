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
 * Practically infinite above decimal place, limited to `abs(long.min)` number of
 * decimal places
 * 
 * Spec: http://speleotrove.com/decimal/decarith.html
 *
 * [sign, coefficient, exponent]
 */
struct Decimal(Hook = Abort)
{
    import std.experimental.allocator.common : stateSize;

    static assert(
        hasMember!(Hook, "precision") && is(typeof(Hook.precision) : uint),
        "The Hook must have a defined precision"
    );
    static assert(
        hasMember!(Hook, "roundingMode") && is(typeof(Hook.roundingMode) == Rounding),
        "The Hook must have a defined Rounding"
    );
    static assert(
        hook.precision > 1,
        "Hook precision is too small"
    );

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

    enum hasClampedMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onClamped(d); });
    enum hasRoundedMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onRounded(d); });
    enum hasInexactMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onInexact(d); });
    enum hasDivisionByZeroMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onDivisionByZero(d); });
    enum hasInvalidOperationMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onInvalidOperation(d); });
    enum hasOverflowMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onOverflow(d); });
    enum hasSubnormalMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onSubnormal(d); });
    enum hasUnderflowMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onUnderflow(d); });

    /*
        rounds the coefficient via `Hook`s rounding mode. Also sets the proper
        flags and calls the proper `Hook` defined methods
     */
    auto round()
    {
        auto digits = numberOfDigits(coefficient);

        if (digits <= hook.precision)
            return;

        static if (hook.roundingMode == Rounding.Down)
        {
            while (digits > hook.precision)
            {
                coefficient /= 10;
                --digits;
                ++exponent;
            }
        }
        else static if (hook.roundingMode == Rounding.Up)
        {
            while (digits > hook.precision)
            {
                coefficient /= 10;
                --digits;
                ++exponent;
            }

            ++coefficient;
        }
        else static if (hook.roundingMode == Rounding.HalfUp)
        {
            while (digits > hook.precision + 1)
            {
                coefficient /= 10;
                --digits;
                ++exponent;
            }

            auto lastDigit = coefficient % 10;

            coefficient /= 10;
            ++exponent;

            if (lastDigit >= 5)
                ++coefficient;
        }
        else
        {
            static assert(0, "Not implemented");
        }

        inexact = true;
        rounded = true;

        // "any Inexact trap takes precedence over Rounded"
        static if (hasInexactMethod)
            hook.onInexact(this);
        static if (hasRoundedMethod)
            hook.onRounded(this);

        return;
    }

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

        round();
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

        // all variables are declared here to make gotos compile
        immutable frontResult = codeUnits.front;
        bool sawDecimal = false;
        bool sawExponent = false;
        bool sawExponentSign = false;
        byte exponentSign;
        long sciExponent = 0;

        if (frontResult == '+')
        {
            codeUnits.popFront;
        }
        else if (frontResult == '-')
        {
            sign = 1;
            codeUnits.popFront;
        }

        if (codeUnits.empty)
        {
            sign = 0;
            goto Lerr;
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
                    {
                        round();
                        return;
                    }
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

        round();
        return;

        Lerr:
            qNaN = true;
            coefficient = 0;
            exponent = 0;

            invalidOperation = true;
            static if (hasInvalidOperationMethod)
                hook.onInvalidOperation(this);

            return;
    }

    ///
    bool opEquals(T)(T f) if (isNumeric!T)
    {
        return false;
    }

    ///
    bool opEquals(T)(T d) if (is(T : Decimal))
    {
        return false;
    }

    ///
    auto toString()
    {
        return toDecimalString();
    }

    ///
    alias toString = toDecimalString;

    /// Decimal strings
    auto toDecimalString() const
    {
        import std.array : appender;
        auto app = appender!string();
        toDecimalString(app);
        return app.data;
    }

    /// ditto
    void toDecimalString(Writer)(Writer w) const if (isOutputRange!(Writer, char))
    {
        import std.math : pow;
        import std.range : repeat;

        if (sign == 1)
            w.put('-');

        if (inf)
        {
            w.put("Infinity");
            return;
        }

        if (qNaN)
        {
            w.put("NaN");
            return;
        }

        if (sNaN)
        {
            w.put("sNaN");
            return;
        }

        auto temp = coefficient.toChars;
        auto decimalPlace = exponent * -1;

        if (decimalPlace > 0)
        {
            if (temp.length - decimalPlace == 0)
            {
                w.put("0.");
                w.put(temp);
                return;
            }

            if ((cast(long) temp.length) - decimalPlace > 0)
            {
                w.put(temp[0 .. $ - decimalPlace]);
                w.put('.');
                w.put(temp[$ - decimalPlace .. $]);
                return;
            }

            if ((cast(long) temp.length) - decimalPlace < 0)
            {
                w.put("0.");
                w.put('0'.repeat(decimalPlace - temp.length));
                w.put(temp);
                return;
            }
        }

        if (decimalPlace < 0)
        {
            w.put(temp);
            w.put('0'.repeat(exponent));
            return;
        }

        w.put(temp);
    }
}

// string construction
@safe pure nothrow
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
        bool inf;
        bool invalid;
    }

    auto nonspecialTestValues = [
        Test("0", 0, 0, 0),
        Test("+0", 0, 0, 0),
        Test("-0", 1, 0, 0),
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
        SpecialTest("Infinite", 0, true, false, false, true),
        SpecialTest("inf", 0, false, false, true),
        SpecialTest("-inf", 1, false, false, true),
        SpecialTest("snan", 0, false, true, false),
        SpecialTest("-snan", 1, false, true, false),
        SpecialTest("Jack", 0, true, false, false, true),
        SpecialTest("+", 0, true, false, false, true),
        SpecialTest("-", 0, true, false, false, true),
        SpecialTest("nan0123", 0, true, false, false),
        SpecialTest("-nan0123", 1, true, false, false),
        SpecialTest("snan0123", 0, false, true, false),
        SpecialTest("12+3", 0, true, false, false, true),
        SpecialTest("1.2.3", 0, true, false, false, true),
        SpecialTest("123.0E+7E+7", 0, true, false, false, true),
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
        auto d = Decimal!(NoOp)(el.val);
        assert(d.qNaN == el.qNaN);
        assert(d.sNaN == el.sNaN);
        assert(d.inf == el.inf);
        assert(d.invalidOperation == el.invalid);
    }
}

// range construction
@system unittest
{
    import std.internal.test.dummyrange;
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
@safe pure nothrow
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
        Test(int.max, 0, int.max),
        Test(-2147483648, 1, 2147483648),
    ];

    foreach (el; testValues)
    {
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
    t.coefficient = 2_708;
    t.exponent = -2;
    assert(t.toString() == "27.08");

    auto t2 = Decimal!()();
    t2.sign = 1;
    t2.coefficient = 1_953;
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

    auto t7 = Decimal!()(12_345_678);
    assert(t7.toString() == "12345678");

    auto t8 = Decimal!()(1234.5678);
    assert(t8.toString() == "1234.5678");

    auto t9 = Decimal!()(0.1234);
    assert(t9.toString() == "0.1234");

    auto t10 = Decimal!()(1234.0);
    assert(t10.toString() == "1234");

    auto t11 = Decimal!()("1.2345678E-7");
    assert(t11.toString() == "0.00000012345678");

    auto t12 = Decimal!()("INF");
    assert(t12.toString() == "Infinity");

    auto t13 = Decimal!()("-INF");
    assert(t13.toString() == "-Infinity");

    auto t14 = Decimal!()("NAN");
    assert(t14.toString() == "NaN");

    auto t15 = Decimal!()("-NAN");
    assert(t15.toString() == "-NaN");
}

// test rounding
// @safe pure nothrow
unittest
{
    import std.exception : assertThrown;

    static struct Test
    {
        ulong coefficient;
        ulong expected;
        bool inexact;
        bool rounded;
    }

    static struct DownHook
    {
        enum uint precision = 5;
        enum Rounding roundingMode = Rounding.Down;
    }

    static struct UpHook
    {
        enum uint precision = 5;
        enum Rounding roundingMode = Rounding.Up;
    }

    static struct HalfUpHook
    {
        enum uint precision = 5;
        enum Rounding roundingMode = Rounding.HalfUp;
    }

    auto downValues = [
        Test(12345, 12345, false, false),
        Test(123449, 12344, true, true),
        Test(1234499999, 12344, true, true),
        Test(123451, 12345, true, true),
        Test(123450000001, 12345, true, true),
        Test(1234649999, 12346, true, true),
        Test(123465, 12346, true, true),
        Test(1234650001, 12346, true, true)
    ];
    auto upValues = [
        Test(12345, 12345, false, false),
        Test(1234499, 12345, true, true),
        Test(123449999999, 12345, true, true),
        Test(123450000001, 12346, true, true),
        Test(123451, 12346, true, true),
        Test(1234649999, 12347, true, true),
        Test(123465, 12347, true, true),
        Test(123454, 12346, true, true)
    ];
    auto halfUpValues = [
        Test(12345, 12345, false, false),
        Test(123449, 12345, true, true),
        Test(1234499, 12345, true, true),
        Test(12344999, 12345, true, true),
        Test(123451, 12345, true, true),
        Test(1234501, 12345, true, true),
        Test(123464999, 12346, true, true),
        Test(123465, 12347, true, true),
        Test(1234650001, 12347, true, true),
        Test(123456, 12346, true, true)
    ];

    foreach (e; downValues)
    {
        auto d = Decimal!(DownHook)(e.coefficient);
        assert(d.coefficient == e.expected);
        assert(d.rounded == e.rounded);
        assert(d.inexact == e.inexact);
    }
    foreach (e; upValues)
    {
        auto d = Decimal!(UpHook)(e.coefficient);
        assert(d.coefficient == e.expected);
        assert(d.rounded == e.rounded);
        assert(d.inexact == e.inexact);
    }
    foreach (e; halfUpValues)
    {
        auto d = Decimal!(HalfUpHook)(e.coefficient);
        assert(d.coefficient == e.expected);
        assert(d.rounded == e.rounded);
        assert(d.inexact == e.inexact);
    }

    // Test that the exponent is properly changed
    auto de = decimal!(HalfUpHook)("1.2345678E-7");
    assert(de.exponent == -11);

    // test calling of defined hook methods
    static struct ThrowHook
    {
        enum uint precision = 5;
        enum Rounding roundingMode = Rounding.HalfUp;

        static void onRounded(T)(T d)
        {
            throw new Exception("Rounded");
        }
    }

    assertThrown!Exception(Decimal!(ThrowHook)(1_234_567));
}

/**
 * Factory function
 */
auto decimal(Hook = Abort, R)(R r)
if ((isForwardRange!R &&
    isSomeChar!(ElementEncodingType!R) &&
    !isInfinite!R) || isNumeric!R)
{
    return Decimal!(Hook)(r);
}

///
unittest
{
    auto d1 = decimal(5.5);
    assert(d1.toString == "5.5");

    auto d2 = decimal("500.555");
}

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
 * Will halt program on division by zero, invalid operations,
 * overflows, and underflows
 *
 * Has 16 significant digits, rounds half up
 */
struct Abort
{
    ///
    enum Rounding roundingMode = Rounding.HalfUp;
    ///
    enum uint precision = 16;

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

/**
 * Will throw exceptions on division by zero, invalid operations,
 * overflows, and underflows
 *
 * Has 16 significant digits, rounds half up
 */
struct Throw
{
    ///
    enum Rounding roundingMode = Rounding.HalfUp;
    ///
    enum uint precision = 16;

    ///
    static void onDivisionByZero(T)(T d) if (isInstanceOf!(Decimal, T))
    {
        throw new DivisionByZero();
    }

    ///
    static void onInvalidOperation(T)(T d) if (isInstanceOf!(Decimal, T))
    {
        throw new InvalidOperation();
    }

    ///
    static void onOverflow(T)(T d) if (isInstanceOf!(Decimal, T))
    {
        throw new Overflow();
    }

    ///
    static void onUnderflow(T)(T d) if (isInstanceOf!(Decimal, T))
    {
        throw new Underflow();
    }
}

/**
 * Does nothing on invalid operations except the proper flags
 *
 * Has 16 significant digits, rounds half up
 */
struct NoOp
{
    ///
    enum Rounding roundingMode = Rounding.HalfUp;
    ///
    enum uint precision = 16;
}

/**
 * Thrown when using $(LREF Throw) and division by zero occurs
 */
class DivisionByZero : Exception
{
    /++
        Params:
            msg  = The message for the exception.
            file = The file where the exception occurred.
            line = The line number where the exception occurred.
            next = The previous exception in the chain of exceptions, if any.
    +/
    this(string msg, string file = __FILE__, size_t line = __LINE__,
         Throwable next = null) @nogc @safe pure nothrow
    {
        super(msg, file, line, next);
    }

    /++
        Params:
            msg  = The message for the exception.
            next = The previous exception in the chain of exceptions.
            file = The file where the exception occurred.
            line = The line number where the exception occurred.
    +/
    this(string msg, Throwable next, string file = __FILE__,
         size_t line = __LINE__) @nogc @safe pure nothrow
    {
        super(msg, file, line, next);
    }
}

/**
 * Thrown when using $(LREF Throw) and an invalid operation occurs
 */
class InvalidOperation : Exception
{
    /++
        Params:
            msg  = The message for the exception.
            file = The file where the exception occurred.
            line = The line number where the exception occurred.
            next = The previous exception in the chain of exceptions, if any.
    +/
    this(string msg, string file = __FILE__, size_t line = __LINE__,
         Throwable next = null) @nogc @safe pure nothrow
    {
        super(msg, file, line, next);
    }

    /++
        Params:
            msg  = The message for the exception.
            next = The previous exception in the chain of exceptions.
            file = The file where the exception occurred.
            line = The line number where the exception occurred.
    +/
    this(string msg, Throwable next, string file = __FILE__,
         size_t line = __LINE__) @nogc @safe pure nothrow
    {
        super(msg, file, line, next);
    }
}

/**
 * Thrown when using $(LREF Throw) and overflow occurs
 */
class Overflow : Exception
{
    /++
        Params:
            msg  = The message for the exception.
            file = The file where the exception occurred.
            line = The line number where the exception occurred.
            next = The previous exception in the chain of exceptions, if any.
    +/
    this(string msg, string file = __FILE__, size_t line = __LINE__,
         Throwable next = null) @nogc @safe pure nothrow
    {
        super(msg, file, line, next);
    }

    /++
        Params:
            msg  = The message for the exception.
            next = The previous exception in the chain of exceptions.
            file = The file where the exception occurred.
            line = The line number where the exception occurred.
    +/
    this(string msg, Throwable next, string file = __FILE__,
         size_t line = __LINE__) @nogc @safe pure nothrow
    {
        super(msg, file, line, next);
    }
}

/**
 * Thrown when using $(LREF Throw) and underflow occurs
 */
class Underflow : Exception
{
    /++
        Params:
            msg  = The message for the exception.
            file = The file where the exception occurred.
            line = The line number where the exception occurred.
            next = The previous exception in the chain of exceptions, if any.
    +/
    this(string msg, string file = __FILE__, size_t line = __LINE__,
         Throwable next = null) @nogc @safe pure nothrow
    {
        super(msg, file, line, next);
    }

    /++
        Params:
            msg  = The message for the exception.
            next = The previous exception in the chain of exceptions.
            file = The file where the exception occurred.
            line = The line number where the exception occurred.
    +/
    this(string msg, Throwable next, string file = __FILE__,
         size_t line = __LINE__) @nogc @safe pure nothrow
    {
        super(msg, file, line, next);
    }
}

/*
 * Get the number of digits in the decimal representation of a number
 */
private auto numberOfDigits(T)(T x) if (isIntegral!T)
{
    import std.algorithm.comparison : max;
    import std.math : floor, log10;

    static if (is(Signed!T == T))
    {
        import std.math : abs;
        x = abs(x);
    }

    return (cast(uint) x.log10.floor.max(0)) + 1;
}

@safe @nogc pure nothrow unittest
{
    assert(numberOfDigits(0) == 1);
    assert(numberOfDigits(1) == 1);
    assert(numberOfDigits(1_000UL) == 4);
    assert(numberOfDigits(-1_000L) == 4);
    assert(numberOfDigits(1_000_000) == 7);
    assert(numberOfDigits(-1_000_000) == 7);
    assert(numberOfDigits(123_456) == 6);
}
