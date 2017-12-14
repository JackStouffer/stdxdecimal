/**
    Adapted from the specification of the General Decimal Arithmetic.

    This implementation is written for the D Programming Language
    by Jack Stouffer and is licensed under the Boost Software License 1.0.
*/
module stdxdecimal;

import std.stdio;
import std.range.primitives;
import std.traits;

/**
 * Behavior is defined by `Hook`. Number of significant digits is limited by 
 * `Hook.precision`.
 *
 * Spec: http://speleotrove.com/decimal/decarith.html
 */
struct Decimal(Hook = Abort)
{
    import std.experimental.allocator.common : stateSize;

    static assert(
        hasMember!(Hook, "precision") && is(typeof(Hook.precision) : uint),
        "The Hook must have a defined precision that's convertible to uint"
    );
    static assert(
        isEnum!(Hook.precision),
        "Hook.precision must be readable at compile-time"
    );
    static assert(
        hasMember!(Hook, "roundingMode") && is(typeof(Hook.roundingMode) == Rounding),
        "The Hook must have a defined Rounding"
    );
    static assert(
        isEnum!(Hook.roundingMode),
        "Hook.roundingMode must be readable at compile-time"
    );
    static assert(
        hook.precision > 1,
        "Hook.precision is too small (must be at least 2)"
    );

package:
    // "1 indicates that the number is negative or is the negative zero
    // and 0 indicates that the number is zero or positive."
    bool sign;
    // quiet NaN
    bool qNaN;
    // signaling NaN
    bool sNaN;
    // Infinite
    bool inf;

    // actual value of decimal given as (–1)^^sign × coefficient × 10^^exponent
    static if (useBigInt)
    {
        import std.bigint : BigInt;
        BigInt coefficient;
    }
    else
    {
        ulong coefficient;
    }
    int exponent;

    enum hasClampedMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onClamped(d); });
    enum hasRoundedMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onRounded(d); });
    enum hasInexactMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onInexact(d); });
    enum hasDivisionByZeroMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onDivisionByZero(d); });
    enum hasInvalidOperationMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onInvalidOperation(d); });
    enum hasOverflowMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onOverflow(d); });
    enum hasSubnormalMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onSubnormal(d); });
    enum hasUnderflowMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onUnderflow(d); });

    // The cut off point is set at 9 because 999_999_999 ^^ 2
    // can still fit in a ulong
    enum useBigInt = Hook.precision > 9;

    /*
        rounds the coefficient via `Hook`s rounding mode.

        Rounded is always set if the coefficient is changed

        Inexact is set if the rounded digits were non-zero
     */
    auto round()
    {
        static if (hook.precision < 20)
        {
            enum ulong max = 10UL ^^ hook.precision;
            if (coefficient < max)
                return;
        }

        auto digits = numberOfDigits(coefficient);
        if (digits <= hook.precision)
            return;

        int lastDigit;

        // TODO: as soon as inexact == true, we can quit the
        // loops and do a single division if ulong or just a
        // few divisions if bigint, cuts down on total divisions
        static if (hook.roundingMode == Rounding.Down)
        {
            while (digits > hook.precision)
            {
                if (!inexact)
                    lastDigit = coefficient % 10;
                coefficient /= 10;
                --digits;
                ++exponent;

                if (!inexact && lastDigit != 0)
                    inexact = true;
            }
        }
        else static if (hook.roundingMode == Rounding.Up)
        {
            while (digits > hook.precision)
            {
                if (!inexact)
                    lastDigit = coefficient % 10;
                coefficient /= 10;
                --digits;
                ++exponent;

                if (!inexact && lastDigit != 0)
                    inexact = true;
            }

            // If all of the discarded digits are zero the result is unchanged
            if (inexact)
                ++coefficient;
        }
        else static if (hook.roundingMode == Rounding.HalfUp)
        {
            while (digits > hook.precision + 1)
            {
                if (!inexact)
                    lastDigit = coefficient % 10;

                coefficient /= 10;
                --digits;
                ++exponent;

                if (!inexact && lastDigit != 0)
                    inexact = true;
            }

            lastDigit = coefficient % 10;
            if (lastDigit != 0)
                inexact = true;
            coefficient /= 10;
            ++exponent;

            if (lastDigit >= 5)
                ++coefficient;
        }
        else
        {
            static assert(0, "Not implemented");
        }

        rounded = true;

        static if (hasInexactMethod)
            if (inexact)
                hook.onInexact(this);

        static if (hasRoundedMethod)
            hook.onRounded(this);

        return;
    }

    /*
        Separated into its own function for readability as well as
        allowing opCmp to skip the rounding step
     */
    auto addImpl(string op, bool round, T)(T rhs) const
    {
        import std.algorithm.comparison : min;
        import std.math : abs;

        static if (!useBigInt)
            import core.checkedint : mulu;

        static if (op == "-")
            rhs.sign = rhs.sign == 0 ? 1 : 0;

        Decimal!(hook) res;

        if (sNaN || rhs.sNaN || qNaN || rhs.qNaN)
        {
            res.qNaN = true;
            
            // the sign of the first nan is simply propagated
            if ((sNaN || qNaN))
            {
                res.sign = sign;
            }
            else if (rhs.sNaN || rhs.qNaN)
            {
                static if (op == "-")
                    res.sign = 0 ? 1 : 0;
                else
                    res.sign = sign;
            }

            if (sNaN || rhs.sNaN)
            {
                res.invalidOperation = true;
                static if (hasInvalidOperationMethod)
                    res.hook.onInvalidOperation(res);
            }
            
            return res;
        }

        if (inf && rhs.inf)
        {
            if (sign == 1 && rhs.sign == 1)
            {
                res.sign = 1;
                res.inf = true;
                return res;
            }

            if (sign == 0 && rhs.sign == 0)
            {
                res.inf = true;
                return res;
            }

            // -Inf + Inf makes no sense
            res.qNaN = true;
            res.invalidOperation = true;
            return res;
        }

        if (inf)
        {
            res.inf = true;
            res.sign = sign;
            return res;
        }

        if (rhs.inf)
        {
            res.inf = true;
            res.sign = rhs.sign;
            return res;
        }

        Unqual!(typeof(coefficient)) alignedCoefficient = coefficient;
        Unqual!(typeof(rhs.coefficient)) rhsAlignedCoefficient = rhs.coefficient;

        if (exponent != rhs.exponent)
        {
            long diff;
            bool overflow;

            if (exponent > rhs.exponent)
            {
                diff = abs(exponent - rhs.exponent);

                static if (useBigInt)
                {
                    alignedCoefficient *= 10 ^^ diff;
                }
                else
                {
                    alignedCoefficient = mulu(alignedCoefficient, 10 ^^ diff, overflow);
                    // the Overflow condition is only raised if exponents are incorrect,
                    // so this is actually the condition "Insufficient Storage"
                    if (overflow)
                        assert(0, "Arithmetic operation failed due to coefficient overflow");
                }
            }
            else
            {
                diff = abs(rhs.exponent - exponent);

                static if (useBigInt)
                {
                    rhsAlignedCoefficient *= 10 ^^ diff;
                }
                else
                {
                    rhsAlignedCoefficient = mulu(rhsAlignedCoefficient, 10 ^^ diff, overflow);
                    if (overflow)
                        assert(0, "Arithmetic operation failed due to coefficient overflow");
                }
            }
        }

        // If the signs of the operands differ then the smaller aligned coefficient
        // is subtracted from the larger; otherwise they are added.
        if (sign == rhs.sign)
        {
            if (alignedCoefficient >= rhsAlignedCoefficient)
                res.coefficient = alignedCoefficient + rhsAlignedCoefficient;
            else
                res.coefficient = rhsAlignedCoefficient + alignedCoefficient;
        }
        else
        {
            if (alignedCoefficient >= rhsAlignedCoefficient)
                res.coefficient = alignedCoefficient - rhsAlignedCoefficient;
            else
                res.coefficient = rhsAlignedCoefficient - alignedCoefficient;
        }

        res.exponent = min(exponent, rhs.exponent);

        if (res.coefficient != 0)
        {
            // the sign of the result is the sign of the operand having
            // the larger absolute value.
            if (alignedCoefficient >= rhsAlignedCoefficient)
                res.sign = sign;
            else
                res.sign = rhs.sign;
        }
        else
        {
            if (sign == 1 && rhs.sign == 1)
                res.sign = 1;

            static if (hook.roundingMode == Rounding.Floor)
                if (sign != rhs.sign)
                    res.sign = 1;
        }

        static if (round)
            res.round();

        return res;
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
     * Note: Float construction less accurate than string, Use
     * string construction if possible
     */
    this(T)(const T num) pure if (isNumeric!T)
    {
        // the behavior of conversion from built-in number types
        // isn't covered by the spec, so we can do whatever we
        // want here

        static if (isIntegral!T)
        {
            import std.math : abs;

            coefficient = abs(num);
            sign = num >= 0 ? 0 : 1;
        }
        else
        {
            import std.math : abs, isInfinity, isNaN;

            Unqual!T val = num;

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
            Unqual!T fraction = val - (cast(long) val);
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

    /**
     * The result has the hook of the left hand side. Invalid operations
     * call `onInvalidOperation` on the `hook` on the result and set the
     * result's flag to `true`. Does not effect the left hand side of the
     * operation.
     *
     * When the right hand side is a built-in numeric type, the default
     * hook `Abort` is used for its decimal representation.
     */
    auto opBinary(string op, T)(T rhs) const
        if (op == "+" || op == "-" || op == "*" || op == "/")
    {
        static if (isNumeric!T)
        {
            auto temp = decimal(rhs);
            return mixin("this " ~ op ~ " temp");
        }
        else static if (op == "+" || op == "-")
        {
            return addImpl!(op, true)(rhs);
        }
        else static if (op == "*")
        {
            Decimal!(Hook) res;

            if (sNaN || rhs.sNaN || qNaN || rhs.qNaN)
            {
                res.qNaN = true;
                
                // the sign of the first nan is simply propagated
                if (sNaN || qNaN)
                    res.sign = sign;
                else if (rhs.sNaN || rhs.qNaN)
                    res.sign = rhs.sign;

                if (sNaN || rhs.sNaN)
                {
                    res.invalidOperation = true;
                    static if (hasInvalidOperationMethod)
                        res.hook.onInvalidOperation(res);
                }
                
                return res;
            }

            res.sign = sign ^ rhs.sign;

            if (inf && rhs.inf)
            {
                res.inf = true;
                return res;
            }

            if (inf || rhs.inf)
            {
                if ((inf && rhs.coefficient == 0) || (rhs.inf && coefficient == 0))
                {
                    res.qNaN = true;
                    res.invalidOperation = true;
                    static if (hasInvalidOperationMethod)
                        res.hook.onInvalidOperation(res);
                }
                else
                {
                    res.inf = true;
                }

                return res;
            }

            res.coefficient = coefficient * rhs.coefficient;
            res.exponent = exponent + rhs.exponent;

            res.round();
            return res;
        }
        else static if (op == "/")
        {
            Decimal!(Hook) res;

            if (sNaN || rhs.sNaN || qNaN || rhs.qNaN)
            {
                res.qNaN = true;
                
                // the sign of the first nan is simply propagated
                if (sNaN || qNaN)
                    res.sign = sign;
                else if (rhs.sNaN || rhs.qNaN)
                    res.sign = rhs.sign;

                if (sNaN || rhs.sNaN)
                {
                    res.invalidOperation = true;
                    static if (hasInvalidOperationMethod)
                        res.hook.onInvalidOperation(res);
                }
                
                return res;
            }

            if (inf && rhs.inf)
            {
                res.qNaN = true;
                res.invalidOperation = true;
                static if (hasInvalidOperationMethod)
                    res.hook.onInvalidOperation(res);
                return res;
            }

            if (rhs.coefficient == 0 && coefficient == 0)
            {
                res.qNaN = true;
                res.divisionByZero = true;

                static if (hasDivisionByZeroMethod)
                    res.hook.onDivisionByZero(res);

                return res;
            }

            res.sign = sign ^ rhs.sign;

            if (inf && !rhs.inf)
            {
                res.inf = true;
                return res;
            }

            if (!inf && rhs.inf)
                return res;

            if (rhs.coefficient == 0 && coefficient != 0)
            {
                res.divisionByZero = true;
                res.invalidOperation = true;
                res.inf = true;

                static if (hasDivisionByZeroMethod)
                    res.hook.onDivisionByZero(res);
                static if (hasInvalidOperationMethod)
                    res.hook.onInvalidOperation(res);

                return res;
            }

            int adjust;
            Unqual!(typeof(coefficient)) dividend = coefficient;
            Unqual!(typeof(rhs.coefficient)) divisor = rhs.coefficient;

            if (dividend !=0)
            {
                while (dividend < divisor)
                {
                    dividend *= 10;
                    ++adjust;
                }

                while (dividend >= divisor * 10)
                {
                    divisor *= 10;
                    --adjust;
                }

                while (true)
                {
                    while (divisor <= dividend)
                    {
                        dividend -= divisor;
                        ++res.coefficient;
                    }

                    if ((dividend == 0 && adjust >= 0) || numberOfDigits(res.coefficient) == hook.precision + 1)
                    {
                        break;
                    }
                    else
                    {
                        res.coefficient *= 10;
                        dividend *= 10;
                        ++adjust;
                    }
                }
            }

            res.exponent = exponent - (rhs.exponent + adjust);
            res.round();
            return res;
        }
        else
        {
            static assert(0, "Not implemented yet");
        }
    }

    /**
     * The spec says that comparing `NAN`s should yield `NAN`.
     * Unfortunately this isn't possible in D, as the return value of `opCmp` must be
     * [`-1`, `1`].
     *
     * Further, in D, the NaN values of floating point types always return `false` in
     * any comparison. But, this makes sorting an array with NaN values impossible.
     *
     * So, `-INF` is less than all numbers, `-NAN` is greater than `-INF` but
     * less than all other numbers, `NAN` is greater than `-NAN` but less than all other
     * numbers and inf is greater than all numbers. `-NAN` and `NAN` are equal to
     * themselves. 
     *
     * Signaling NAN is an invalid operation, and will trigger the appropriate hook
     * method and always yield `-1`.
     */
    int opCmp(T)(T d) // For some reason isInstanceOf refuses to work here
    {
        static if (!isNumeric!T)
        {
            if (sNaN || d.sNaN)
            {
                invalidOperation = true;
                static if (hasInvalidOperationMethod)
                    hook.onInvalidOperation(this);
                return -1;
            }

            if (inf)
            {
                if (sign == 1 && (inf != d.inf || sign != d.sign))
                    return -1;
                if (sign == 0 && (inf != d.inf || sign != d.sign))
                    return 1;
                if (d.inf && sign == d.sign)
                    return 0;
            }

            if (qNaN && d.qNaN)
            {
                if (sign == d.sign)
                    return 0;
                if (sign == 1)
                    return -1;

                return 1;
            }

            if (qNaN && !d.qNaN)
                return -1;
            if (!qNaN && d.qNaN)
                return 1;

            Decimal!(Hook) lhs;

            // If the signs of the operands differ, a value representing each
            // operand (’-1’ if the operand is less than zero, ’0’ if the
            // operand is zero or negative zero, or ’1’ if the operand is
            // greater than zero) is used in place of that operand for the
            // comparison instead of the actual operand.
            if (sign != d.sign)
            {
                if (sign == 0)
                {
                    if (coefficient > 0)
                        lhs.coefficient = 1;
                }
                else
                {
                    if (coefficient > 0)
                    {
                        lhs.sign = 1;
                        lhs.coefficient = 1;
                    }
                }

                if (d.sign == 0)
                {
                    if (d.coefficient > 0)
                        d.coefficient = 1;
                }
                else
                {
                    if (d.coefficient > 0)
                    {
                        d.sign = 1;
                        d.coefficient = 1;
                    }
                }
            }
            else
            {
                lhs.sign = sign;
                lhs.coefficient = coefficient;
                lhs.exponent = exponent;
            }

            auto res = lhs.addImpl!("-", false)(d);

            if (res.sign == 0)
            {
                if (res.coefficient == 0)
                    return 0;
                else
                    return 1;
            }

            return -1;
        }
        else
        {
            return this.opCmp(d.decimal);
        }
    }

    ///
    bool opEquals(T)(T d)
    {
        return this.opCmp(d) == 0;
    }

    ///
    alias toString = toDecimalString;

    /**
     * Decimal strings
     *
     * Special Values:
     *     Quiet Not A Number = `NaN`
     *     Signal Not A Number = `sNaN`
     *     Infinite = `Infinity`
     *
     *     If negative, then all of above have `-` pre-pended
     */
    auto toDecimalString() const
    {
        import std.array : appender;
        import std.math : abs;

        auto app = appender!string();
        if (exponent > 10 || exponent < -10)
            app.reserve(abs(exponent) + hook.precision);
        toDecimalString(app);
        return app.data;
    }

    /// ditto
    void toDecimalString(Writer)(auto ref Writer w) const if (isOutputRange!(Writer, char))
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

        static if (useBigInt)
        {
            import std.bigint : toDecimalString;
            auto temp = coefficient.toDecimalString;
        }
        else
        {
            import std.conv : toChars;
            auto temp = coefficient.toChars;
        }

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
        SpecialTest("infinity", 0, false, false, true),
        SpecialTest("-INFINITY", 1, false, false, true),
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
@system pure
unittest
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
        Test(-147_483_648, 1, 147_483_648),
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

// addition and subtraction
@system
unittest
{
    static struct Test
    {
        string val1;
        string val2;
        string expected;
        bool invalidOperation;
    }

    auto testPlusValues = [
        Test("-0", "-0", "-0"),
        Test("-0", "0", "0"),
        Test("1", "2", "3"),
        Test("-5", "-3", "-8"),
        Test("5.75", "3.3", "9.05"),
        Test("1.23456789", "1.00000000", "2.23456789"),
        Test("10E5", "10E4", "1100000"),
        Test("0.9998", "0.0000", "0.9998"),
        Test("1", "0.0001", "1.0001"),
        Test("1", "0.00", "1.00"),
        Test("123.00", "3000.00", "3123.00"),
        Test("123.00", "3000.00", "3123.00"),
        Test("sNaN", "sNaN", "NaN", true),
        Test("-sNaN", "sNaN", "-NaN", true),
        Test("NaN", "sNaN", "NaN", true),
        Test("sNaN", "1000", "NaN", true),
        Test("1000", "sNaN", "NaN", true),
        Test("1000", "NaN", "NaN"),
        Test("NaN", "NaN", "NaN"),
        Test("-NaN", "NaN", "-NaN"),
        Test("NaN", "Inf", "NaN"),
        Test("-NaN", "Inf", "-NaN"),
        Test("-Inf", "-Inf", "-Infinity"),
        Test("-Inf", "Inf", "NaN", true),
        Test("Inf", "-Inf", "NaN", true),
        Test("-Inf", "-1000", "-Infinity"),
        Test("-Inf", "1000", "-Infinity"),
        Test("Inf", "-1000", "Infinity"),
        Test("Inf", "1000", "Infinity")
    ];

    auto testMinusValues = [
        Test("-0", "0", "-0"),
        Test("0", "-0", "0"),
        Test("0", "0", "0"),
        Test("1.3", "0.3", "1.0"),
        Test("1.3", "2.07", "-0.77"),
        Test("1.25", "1.25", "0.00"),
        Test("3", "-3.0", "6.0"),
        Test("1.23456789", "1.00000000", "0.23456789"),
        Test("10.2345679", "10.2345675", "0.0000004"),
        Test("0.999999999", "1", "-0.000000001"),
        Test("2.000E-3", "1.00200", "-1.000000"),
        Test("-Inf", "Inf", "-Infinity"),
        Test("-Inf", "1000", "-Infinity"),
        Test("1000", "-Inf", "Infinity"),
        Test("NaN", "Inf", "NaN"),
        Test("Inf", "NaN", "NaN"),
        Test("NaN", "NaN", "NaN"),
        Test("-NaN", "NaN", "-NaN"),
        Test("sNaN", "0", "NaN", true),
        Test("sNaN", "-Inf", "NaN", true),
        Test("sNaN", "NaN", "NaN", true),
        Test("1000", "sNaN", "NaN", true),
        Test("-sNaN", "sNaN", "-NaN", true),
        Test("Inf", "Inf", "NaN", true),
        Test("-Inf", "-Inf", "NaN", true),
    ];

    foreach (el; testPlusValues)
    {
        auto v1 = decimal!(NoOp)(el.val1);
        auto v2 = decimal(el.val2);
        auto res = v1 + v2;
        assert(res.toString() == el.expected);
        assert(res.invalidOperation == el.invalidOperation);
    }

    foreach (el; testMinusValues)
    {
        auto v1 = decimal!(NoOp)(el.val1);
        auto v2 = decimal(el.val2);
        auto res = v1 - v2;
        assert(res.toString() == el.expected);
        assert(res.invalidOperation == el.invalidOperation);
    }

    // check that float and int compile
    assert(decimal("2.22") + 0.01 == decimal("2.23"));
    assert(decimal("2.22") + 1 == decimal("3.22"));

    static struct CustomHook
    {
        enum Rounding roundingMode = Rounding.HalfUp;
        enum uint precision = 3;
    }

    // rounding test on addition
    auto d1 = decimal!(CustomHook)("0.999E-2");
    auto d2 = decimal!(CustomHook)("0.1E-2");
    auto v = d1 + d2;
    assert(v.toString == "0.0110");
    assert(v.inexact);
    assert(v.rounded);

    // higher precision tests
    auto d3 = decimal!(HighPrecision)("10000e+9");
    auto d4 = decimal!(HighPrecision)("7");
    auto v2 = d3 - d4;
    assert(v2.toString() == "9999999999993");

    auto d5 = decimal!(HighPrecision)("1e-50");
    auto d6 = decimal!(HighPrecision)("4e-50");
    auto v3 = d5 + d6;
    assert(v3.toString() == "0.00000000000000000000000000000000000000000000000005");
}

// multiplication
@system
unittest
{
    static struct Test
    {
        string val1;
        string val2;
        string expected;
        bool invalidOperation;
        bool rounded;
    }

    auto testValues = [
        Test("0", "0", "0"),
        Test("0", "-0", "-0"),
        Test("-0", "0", "-0"),
        Test("-0", "-0", "0"),
        Test("-00.00", "0E-3", "-0.00000"),
        Test("1.20", "3", "3.60"),
        Test("7", "3", "21"),
        Test("0.9", "0.8", "0.72"),
        Test("0.9", "-0", "-0.0"),
        Test("-1.20", "-2", "2.40"),
        Test("123.45", "1e7", "1234500000"),
        Test("12345", "10E-3", "123.450"),
        Test("1.23456789", "1.00000000", "1.23456789", false, true),
        Test("123456789", "10", "1234567890", false, true),
        Test("Inf", "-Inf", "-Infinity"),
        Test("-1000", "Inf", "-Infinity"),
        Test("Inf", "1000", "Infinity"),
        Test("0", "Inf", "NaN", true),
        Test("-Inf", "-Inf", "Infinity"),
        Test("Inf", "Inf", "Infinity"),
        Test("NaN", "Inf", "NaN"),
        Test("NaN", "-1000", "NaN"),
        Test("-NaN", "-1000", "-NaN"),
        Test("-NaN", "-NaN", "-NaN"),
        Test("-NaN", "-Inf", "-NaN"),
        Test("Inf", "-NaN", "-NaN"),
        Test("sNaN", "1000", "NaN", true),
        Test("1000", "sNaN", "NaN", true),
        Test("-sNaN", "1000", "-NaN", true),
    ];

    foreach (el; testValues)
    {
        auto d = decimal!(NoOp)(el.val1) * decimal!(NoOp)(el.val2);
        assert(d.toString() == el.expected);
        assert(d.invalidOperation == el.invalidOperation);
        assert(d.rounded == el.rounded);
    }
}

// division
@system
unittest
{
    import std.exception : assertThrown;

    static struct Test
    {
        string val1;
        string val2;
        string expected;
        bool divisionByZero;
        bool invalidOperation;
        bool inexact;
        bool rounded;
    }

    auto testValues = [
        Test("5", "2", "2.5"),
        Test("1", "10", "0.1"),
        Test("1", "4", "0.25"),
        Test("12", "12", "1"),
        Test("8.00", "2", "4.00"),
        Test("1000", "100", "10"),
        Test("2.40E+6", "2", "1200000"),
        Test("2.4", "-1", "-2.4"),
        Test("0.0", "1", "0.0"),
        Test("0.0", "-1", "-0.0"),
        Test("-0.0", "-1", "0.0"),
        Test("1", "3", "0.333333333", false, false, true, true),
        Test("2", "3", "0.666666667", false, false, true, true),
        Test("0", "0", "NaN", true, false),
        Test("1000", "0", "Infinity", true, true),
        Test("-1000", "0", "-Infinity", true, true),
        Test("Inf", "-Inf", "NaN", false, true),
        Test("-Inf", "Inf", "NaN", false, true),
        Test("Inf", "1000", "Infinity"),
        Test("Inf", "-1000", "-Infinity"),
        Test("1000", "Inf", "0"),
        Test("1000", "-Inf", "-0"),
        Test("Inf", "Inf", "NaN", false, true),
        Test("-Inf", "-Inf", "NaN", false, true),
        Test("NaN", "NaN", "NaN"),
        Test("-NaN", "NaN", "-NaN"),
        Test("NaN", "-Inf", "NaN"),
        Test("-NaN", "Inf", "-NaN"),
        Test("NaN", "-1000", "NaN"),
        Test("Inf", "NaN", "NaN"),
    ];

    foreach (el; testValues)
    {
        auto d = decimal!(NoOp)(el.val1) / decimal!(NoOp)(el.val2);
        assert(d.toString() == el.expected);
        assert(d.divisionByZero == el.divisionByZero);
        assert(d.invalidOperation == el.invalidOperation);
        assert(d.inexact == el.inexact);
        assert(d.rounded == el.rounded);
    }

    // test that the proper DivisionByZero function is called
    assertThrown!DivisionByZero(() { cast(void) (decimal!(Throw)(1) / decimal(0)); } ());
}

// cmp and equals
@system pure nothrow
unittest
{
    static struct Test
    {
        string val1;
        string val2;
        int expected;
        bool invalidOperation;
    }

    auto testValues = [
        Test("inf", "0", 1),
        Test("-inf", "0", -1),
        Test("-inf", "-inf", 0),
        Test("inf", "-inf", 1),
        Test("-inf", "inf", -1),
        Test("NaN", "1000", -1),
        Test("-NaN", "1000", -1),
        Test("1000", "NAN", 1),
        Test("1000", "-NAN", 1),
        Test("NaN", "inf", -1),
        Test("-NaN", "inf", -1),
        Test("-NaN", "NaN", -1),
        Test("NaN", "-NaN", 1),
        Test("-NaN", "-NaN", 0),
        Test("NaN", "NaN", 0),
        Test("sNaN", "NaN", -1, true),
        Test("sNaN", "-Inf", -1, true),
        Test("sNaN", "100", -1, true),
        Test("0", "-0", 0),
        Test("2.1", "3", -1),
        Test("2.1", "2.1", 0),
        Test("2.1", "2.10", 0),
        Test("3", "2.1", 1),
        Test("2.1", "-3", 1),
        Test("-3", "2.1", -1),
        Test("00", "00", 0),
        Test("70E-1", "7", 0),
        Test("8", "0.7E+1", 1),
        Test("-8.0", "7.0", -1),
        Test("80E-1", "-9", 1),
        Test("1E-15", "1", -1),
        Test("-0E2", "0", 0),
        Test("-8", "-70E-1", -1),
        Test("-12.1234", "-12.000000000", -1),
    ];

    foreach (el; testValues)
    {
        auto v1 = decimal!(NoOp)(el.val1);
        auto v2 = decimal!(NoOp)(el.val2);
        assert(v1.opCmp(v2) == el.expected);
        assert(v1.invalidOperation == el.invalidOperation);
    }

    // make sure equals compiles, already covered behavior in
    // cmp tests
    assert(decimal("19.9999") != decimal("21.222222"));
    assert(decimal("22.000") == decimal("22"));
    assert(decimal("22.000") == 22);
    assert(decimal("22.2") == 22.2);
}

// to string
@system unittest
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

    auto t4 = Decimal!()("300088.44");
    assert(t4.toString() == "300088.44");

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
@system
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
        Test(1234650001, 12346, true, true),
        Test(1234500, 12345, false, true)
    ];
    auto upValues = [
        Test(12345, 12345, false, false),
        Test(1234499, 12345, true, true),
        Test(123449999999, 12345, true, true),
        Test(123450000001, 12346, true, true),
        Test(123451, 12346, true, true),
        Test(1234649999, 12347, true, true),
        Test(123465, 12347, true, true),
        Test(123454, 12346, true, true),
        Test(1234500, 12345, false, true)
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
        Test(123456, 12346, true, true),
        Test(1234500, 12345, false, true)
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
    auto d1 = decimal!(HalfUpHook)("1.2345678E-7");
    assert(d1.exponent == -11);

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

    // test rounding with BigInt
    static struct HigherHook
    {
        enum uint precision = 16;
        enum Rounding roundingMode = Rounding.HalfUp;
    }

    auto d2 = decimal!(HigherHook)("10000000000000005");
    assert(d2.rounded);
    assert(d2.toString() == "10000000000000010");
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
    /**
     * A precision of 9 allows all possible the results of +,-,*, and /
     * to fit into a `ulong` with no issues.
     */
    enum uint precision = 9;

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
 * Same as abort, but offers 64 significant digits
 *
 * Note: Using any precision over `9` is an order of magnitude slower
 * due to implementation constraints. Only use this if you really need
 * data that precise
 */
static struct HighPrecision
{
    enum Rounding roundingMode = Rounding.HalfUp;
    enum uint precision = 64;

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
    enum uint precision = 9;

    ///
    static void onDivisionByZero(T)(T d) if (isInstanceOf!(Decimal, T))
    {
        throw new DivisionByZero("Result: " ~ d.toString());
    }

    ///
    static void onInvalidOperation(T)(T d) if (isInstanceOf!(Decimal, T))
    {
        throw new InvalidOperation("Result: " ~ d.toString());
    }

    ///
    static void onOverflow(T)(T d) if (isInstanceOf!(Decimal, T))
    {
        throw new Overflow("Result: " ~ d.toString());
    }

    ///
    static void onUnderflow(T)(T d) if (isInstanceOf!(Decimal, T))
    {
        throw new Underflow("Result: " ~ d.toString());
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
    enum uint precision = 9;
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
private auto numberOfDigits(T)(T x)
{
    static if (isIntegral!T)
    {
        static if (is(Signed!T == T))
        {
            import std.math : abs;
            x = abs(x);
        }

        // manual ifs are two orders of magnitude faster than using log10
        if (x == 0UL) return 1;
        if (x < 10UL) return 1;
        if (x < 100UL) return 2;
        if (x < 1_000UL) return 3;
        if (x < 10_000UL) return 4;
        if (x < 100_000UL) return 5;
        if (x < 1_000_000UL) return 6;
        if (x < 10_000_000UL) return 7;
        if (x < 100_000_000UL) return 8;
        if (x < 1_000_000_000UL) return 9;
        if (x < 10_000_000_000UL) return 10;
        if (x < 100_000_000_000UL) return 11;
        if (x < 1_000_000_000_000UL) return 12;
        if (x < 10_000_000_000_000UL) return 13;
        if (x < 100_000_000_000_000UL) return 14;
        if (x < 1_000_000_000_000_000UL) return 15;
        if (x < 10_000_000_000_000_000UL) return 16;
        if (x < 100_000_000_000_000_000UL) return 17;
        if (x < 1_000_000_000_000_000_000UL) return 18;
        return 19;
    }
    else
    {
        if (x < 0)
            x *= -1;

        immutable len = x.ulongLength;

        if (len == 1)
        {
            if (x == 0UL) return 1;
            if (x < 10UL) return 1;
            if (x < 100UL) return 2;
            if (x < 1_000UL) return 3;
            if (x < 10_000UL) return 4;
            if (x < 100_000UL) return 5;
            if (x < 1_000_000UL) return 6;
            if (x < 10_000_000UL) return 7;
            if (x < 100_000_000UL) return 8;
            if (x < 1_000_000_000UL) return 9;
            if (x < 10_000_000_000UL) return 10;
            if (x < 100_000_000_000UL) return 11;
            if (x < 1_000_000_000_000UL) return 12;
            if (x < 10_000_000_000_000UL) return 13;
            if (x < 100_000_000_000_000UL) return 14;
            if (x < 1_000_000_000_000_000UL) return 15;
            if (x < 10_000_000_000_000_000UL) return 16;
            if (x < 100_000_000_000_000_000UL) return 17;
            if (x < 1_000_000_000_000_000_000UL) return 18;
        }

        uint digits = 19;
        Unqual!(T) num = 10_000_000_000_000_000_000UL;

        if (len == 3)
        {
            digits = 39;
            num *= 10_000_000_000_000_000_000UL;
            num *= 10;
        }
        else if (len == 4)
        {
            digits = 58;
            num *= 10_000_000_000_000_000_000UL;
            num *= 10_000_000_000_000_000_000UL;
            num *= 10UL;
        }
        else if (len > 4)
        {
            digits = 78;
            num *= 10_000_000_000_000_000_000UL;
            num *= 10_000_000_000_000_000_000UL;
            num *= 10_000_000_000_000_000_000UL;
            num *= 10UL;
        }

        for (;; num *= 10, digits++)
        {
            if (x < num)
                return digits;
        }
    }
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


@system pure unittest
{
    import std.bigint;
    import std.range : chain, repeat;
    import std.utf : byCodeUnit;

    assert(numberOfDigits(BigInt("0")) == 1);
    assert(numberOfDigits(BigInt("1")) == 1);
    assert(numberOfDigits(BigInt("1_000")) == 4);
    assert(numberOfDigits(BigInt("-1_000")) == 4);
    assert(numberOfDigits(BigInt("1_000_000")) == 7);
    assert(numberOfDigits(BigInt("123_456")) == 6);
    assert(numberOfDigits(BigInt("123_456")) == 6);
    assert(numberOfDigits(BigInt("123_456_789_101_112_131_415_161")) == 24);
    assert(numberOfDigits(BigInt("1_000_000_000_000_000_000_000_000")) == 25);
    assert(numberOfDigits(BigInt("1_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000")) == 46);
    assert(numberOfDigits(BigInt("1".byCodeUnit.chain('0'.repeat(60)))) == 61);
}

/*
 * Detect whether $(D X) is an enum type, or manifest constant.
 */
private template isEnum(X...) if (X.length == 1)
{
    static if (is(X[0] == enum))
    {
        enum isEnum = true;
    }
    else static if (!is(X[0]) &&
                    !is(typeof(X[0]) == void) &&
                    !isFunction!(X[0]))
    {
        enum isEnum =
            !is(typeof({ auto ptr = &X[0]; }))
         && !is(typeof({ enum off = X[0].offsetof; }));
    }
    else
        enum isEnum = false;
}
