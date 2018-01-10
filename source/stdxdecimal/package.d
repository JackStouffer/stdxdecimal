/**
 * Quick_Start:
 * ---
 * import stdxdecimal;
 *
 * void main()
 * {
 *     auto d1 = decimal("1.23E-10");
 *     d1 -= decimal("2.00E-10");
 *     assert(d1.toString() == "-0.000000000077");
 * }
 * ---
 *
 * This module defines an exact decimal type, `Decimal`, to a specific number of digits.
 * This is designed to be a drop in replacement for built-in floating point numbers,
 * allowing all the same possible operations.
 *
 * Floating point numbers (`float`, `double`, `real`) are inherently inaccurate because
 * they $(HTTPS en.wikipedia.org/wiki/Floating-point_arithmetic#Accuracy_problems, cannot represent)
 * all possible numbers with a decimal part. `Decimal` on the other hand, is able to
 * represent all possible numbers with a decimal part (limited by memory size and `Hook`).
 *
 * Adapted from the specification of the
 * $(HTTP speleotrove.com/decimal/decarith.html, General Decimal Arithmetic).
 *
 * Custom_Behavior:
 *     The behavior of `Decimal` is controlled by the template parameter `Hook`,
 *     which can be a user defined type or one of the `Hook`s provided by this
 *     module.
 *
 *     The following behaviors are controlled by `Hook`:
 *
 *     $(UL
 *         $(LI The number of significant digits to store.)
 *         $(LI The rounding method.)
 *         $(LI The min and max exponents.)
 *         $(LI What to do when exceptional conditions arise.)
 *     )
 *
 *     The following predefined `Hook`s are available:
 *
 *     $(TABLE
 *         $(TR
 *             $(TD $(LREF Abort))
 *             $(TD `precision` is set to 9, rounding is `HalfUp`, and the program
 *                  will `assert(0)` on divsion by zero, overflow, underflow, and
 *                  invalid operations.
 *             )
 *         )
 *         $(TR
 *             $(TD $(LREF Throw))
 *             $(TD `precision` is set to 9, rounding is `HalfUp`, and the program
 *                  will throw an exception on divsion by zero, overflow, underflow, and
 *                  invalid operations.
 *             )
 *         )
 *         $(TR
 *             $(TD $(LREF HighPrecision))
 *             $(TD `precision` is set to 64, rounding is `HalfUp`, and the program
 *                  will `assert(0)` on divsion by zero, overflow, underflow, and
 *                  invalid operations.
 *             )
 *         )
 *         $(TR
 *             $(TD $(LREF NoOp))
 *             $(TD `precision` is set to 9, rounding is `HalfUp`, and nothing will
 *                  happen on exceptional conditions.
 *             )
 *         )
 *     )
 * 
 * Percision_and_Rounding:
 *     `Decimal` accurately stores as many as `Hook.precision` significant digits.
 *     Once the number of digits `> Hook.precision`, then the number is rounded.
 *     Rounding is performed according to the rules laid out in $(LREF RoundingMode).
 *
 *     By default, the precision is 9, and the rounding mode is `RoundingMode.HalfUp`.
 *
 *     `Hook.precision` must be `<= uint.max - 1` and `> 1`.
 *
 * Note_On_Speed:
 *     The more digits of precision you define in hook, the slower many operations
 *     will become. It's recommended that you use the least amount of precision
 *     necessary for your code.
 *
 * Exceptional_Conditions:
 *     Certain operations will cause a `Decimal` to enter into an invalid state,
 *     e.g. dividing by zero. When this happens, Decimal does two things
 *
 *     $(OL
 *         $(LI Sets a public `bool` variable to `true`.)
 *         $(LI Calls a specific function in `Hook`, if it exists, with the
 *         operation's result as the only parameter.)
 *     )
 *
 *    The following table lists all of the conditions
 *
 *    $(TABLE
 *        $(THEAD
 *            $(TR
 *                $(TH Name)
 *                $(TH Flag)
 *                $(TH Method)
 *                $(TH Description)
 *            )
 *        )
 *        $(TBODY
 *            $(TR
 *                $(TD Clamped)
 *                $(TD `clamped`)
 *                $(TD `onClamped`)
 *                $(TD Occurs when the exponent has been altered to fit in-between
 *                     `Hook.maxExponent` and `Hook.minExponent`.
 *                )
 *            )
 *            $(TR
 *                $(TD Inexact)
 *                $(TD `inexact`)
 *                $(TD `onInexact`)
 *                $(TD Occurs when the result of an operation is not perfectly accurate.
 *                     Mostly occurs when rounding removed non-zero digits.
 *                )
 *            )
 *            $(TR
 *                $(TD Invalid Operation)
 *                $(TD `invalidOperation`)
 *                $(TD `onInvalidOperation`)
 *                $(TD Flagged when an operation makes no sense, e.g. multiplying `0`
 *                     and `Infinity` or add -Infinity to Infinity. 
 *                )
 *            )
 *            $(TR
 *                $(TD Division by Zero)
 *                $(TD `divisionByZero`)
 *                $(TD `onDivisionByZero`)
 *                $(TD Specific invalid operation. Occurs whenever the dividend of a
 *                     division or modulo is equal to zero.
 *                )
 *            )
 *            $(TR
 *                $(TD Rounded)
 *                $(TD `rounded`)
 *                $(TD `onRounded`)
 *                $(TD Occurs when the `Decimal`'s result had more than `Hook.precision`
 *                     significant digits and was reduced.
 *                )
 *            )
 *            $(TR
 *                $(TD Subnormal)
 *                $(TD `subnormal`)
 *                $(TD `onSubnormal`)
 *                $(TD Flagged when the exponent is less than `Hook.maxExponent` but the
 *                     digits of the `Decimal` are not inexact.
 *                )
 *            )
 *            $(TR
 *                $(TD Overflow)
 *                $(TD `overflow`)
 *                $(TD `onOverflow`)
 *                $(TD Not to be confused with integer overflow, this is flagged when
 *                     the exponent of the result of an operation would have been above
 *                     `Hook.maxExponent` and the result is inexact. Inexact and Rounded
 *                     are always set with this flag.
 *                )
 *            )
 *            $(TR
 *                $(TD Underflow)
 *                $(TD `underflow`)
 *                $(TD `onUnderflow`)
 *                $(TD Not to be confused with integer underflow, this is flagged when
 *                     the exponent of the result of an operation would have been below
 *                     `Hook.minExponent`. Inexact, Rounded, and Subnormal are always set with
 *                     this flag.
 *                )
 *            )
 *        )
 *    )
 *
 *    Each function documentation lists the specific states that will led to one
 *    of these flags.
 *
 * Differences_From_The_Specification:
 *     $(UL
 *         $(LI There's no concept of a Signaling NaN in this module.)
 *         $(LI There's no concept of a Diagnostic NaN in this module.)
 *         $(LI `compare`, implemented as `opCmp`, does not propagate `NaN` due
 *         to D's `opCmp` semantics.)
 *     )
 *
 * Version:
 *     `v0.5`. Still work in progress. For missing features, see `README.md`
 *
 * License:
 *     $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).
 *
 * Authors:
 *     Jack Stouffer
*/
module stdxdecimal;

version(unittest) { import std.stdio; }
import std.range.primitives;
import std.traits;
import std.bigint;
import std.bitmanip;

/**
 * A exact decimal type, accurate to `Hook.precision` digits. Designed to be a
 * drop in replacement for floating points.
 * 
 * Behavior is defined by `Hook`. See the module overview for more information.
 */
struct Decimal(Hook = Abort)
{
    import std.experimental.allocator.common : stateSize;

    static assert(
        (hasMember!(Hook, "precision") && is(typeof(Hook.precision) : uint))
        || !hasMember!(Hook, "precision"),
        "Hook.precision must be implicitly convertible to uint"
    );
    static assert(
        (hasMember!(Hook, "precision") && isEnum!(Hook.precision))
        || !hasMember!(Hook, "precision"),
        "Hook.precision must be readable at compile-time"
    );
    static assert(
        (hasMember!(Hook, "precision") && hook.precision > 1)
        || !hasMember!(Hook, "precision"),
        "Hook.precision is too small (must be at least 2)"
    );
    static assert(
        (hasMember!(Hook, "precision") && hook.precision < uint.max)
        || !hasMember!(Hook, "precision"),
        "Hook.precision must be < uint.max"
    );
    static assert(
        (hasMember!(Hook, "roundingMode") && is(typeof(Hook.roundingMode) == Rounding))
        || !hasMember!(Hook, "precision"),
        "Hook.roundingMode must be of type Rounding"
    );
    static assert(
        (hasMember!(Hook, "precision") && isEnum!(Hook.roundingMode))
        || !hasMember!(Hook, "precision"),
        "Hook.roundingMode must be readable at compile-time"
    );
    static assert(
        (hasMember!(Hook, "maxExponent") && isEnum!(Hook.maxExponent))
        || !hasMember!(Hook, "maxExponent"),
        "Hook.maxExponent must be readable at compile-time"
    );
    static assert(
        (hasMember!(Hook, "minExponent") && isEnum!(Hook.minExponent))
        || !hasMember!(Hook, "minExponent"),
        "Hook.minExponent must be readable at compile-time"
    );

    mixin(bitfields!(
        bool, "sign", 1,
        bool, "isNan", 1,
        bool, "isInf", 1,
        bool, "clamped", 1,
        bool, "divisionByZero", 1,
        bool, "inexact", 1,
        bool, "invalidOperation", 1,
        bool, "overflow", 1,
        bool, "rounded", 1,
        bool, "subnormal", 1,
        bool, "underflow", 1,
        uint, "", 5
    ));

package:
    BigInt coefficient;
    int exponent;

    // choose between default or defined parameters
    static if (hasMember!(Hook, "precision"))
        enum uint precision = Hook.precision;
    else
        enum uint precision = 16;

    static if (hasMember!(Hook, "roundingMode"))
        enum Rounding roundingMode = Hook.roundingMode;
    else
        enum Rounding roundingMode = Rounding.HalfUp;

    static if (hasMember!(Hook, "maxExponent") && isEnum!(Hook.maxExponent))
        enum int maxExponent = Hook.maxExponent;
    else
        enum int maxExponent = 999;

    static if (hasMember!(Hook, "minExponent") && isEnum!(Hook.minExponent))
        enum int minExponent = Hook.minExponent;
    else
        enum int minExponent = -999;

    static assert(
        minExponent < maxExponent,
        "minExponent must be less than maxExponent"
    );

    enum hasClampedMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onClamped(d); });
    enum hasRoundedMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onRounded(d); });
    enum hasInexactMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onInexact(d); });
    enum hasDivisionByZeroMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onDivisionByZero(d); });
    enum hasInvalidOperationMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onInvalidOperation(d); });
    enum hasOverflowMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onOverflow(d); });
    enum hasSubnormalMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onSubnormal(d); });
    enum hasUnderflowMethod = __traits(compiles, { auto d = Decimal!(Hook)(0); hook.onUnderflow(d); });

    /*
        rounds num via `Hook`s rounding mode.

        Rounded is always set if the coefficient is changed

        Inexact is set if the rounded digits were non-zero
     */
    auto round(T)(T num) pure
    {
        version (D_InlineAsm_X86) {}
        else
        {
            enum BigInt max = BigInt(10) ^^ precision;
            if (num < max)
                return num;
        }

        auto digits = numberOfDigits(num);
        if (digits <= precision)
            return num;

        Unqual!(T) lastDigit;

        // TODO: as soon as inexact == true, we can quit the
        // loops and do a single division
        static if (roundingMode == Rounding.Down)
        {
            while (digits > precision)
            {
                if (!inexact)
                    lastDigit = num % 10;

                num /= 10;

                --digits;
                ++exponent;

                if (!inexact && lastDigit != 0)
                    inexact = true;
            }
        }
        else static if (roundingMode == Rounding.Up)
        {
            while (digits > precision)
            {
                if (!inexact)
                    lastDigit = num % 10;

                num /= 10;

                --digits;
                ++exponent;

                if (!inexact && lastDigit != 0)
                    inexact = true;
            }

            // If all of the discarded digits are zero the result is unchanged
            if (inexact)
                ++num;
        }
        else static if (roundingMode == Rounding.HalfUp)
        {
            while (digits > precision + 1)
            {
                if (!inexact)
                    lastDigit = num % 10;

                num /= 10;

                --digits;
                ++exponent;

                if (!inexact && lastDigit != 0)
                    inexact = true;
            }

            lastDigit = num % 10;
            num /= 10;

            if (lastDigit != 0)
                inexact = true;
            ++exponent;

            if (lastDigit >= 5)
                ++num;
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

        return num;
    }

    /*
        Separated into its own function for readability as well as
        allowing opCmp to skip the rounding step
     */
    ref Decimal!(Hook) addImpl(string op, bool doRound, T)(T rhs)
    {
        import std.algorithm.comparison : min;
        import std.math : abs;
        import std.conv : to;

        bool rhsSign;

        static if (op == "-")
            rhsSign = rhs.sign == 0 ? 1 : 0;
        else
            rhsSign = rhs.sign;

        if (isNan || rhs.isNan)
        {
            isNan = true;
            isInf = false;

            // the sign of the first isNan is simply propagated
            if (isNan)
            {
                sign = sign;
            }
            else if (rhs.isNan)
            {
                static if (op == "-")
                    sign = 0 ? 1 : 0;
                else
                    sign = sign;
            }

            coefficient = 0;
            exponent = 0;
            return this;
        }

        if (isInf && rhs.isInf)
        {
            if (sign == 1 && rhsSign == 1)
            {
                sign = 1;
                isInf = true;
                return this;
            }

            if (sign == 0 && rhsSign == 0)
            {
                isInf = true;
                return this;
            }

            // -Inf + Inf makes no sense
            isNan = true;
            isInf = false;
            coefficient = 0;
            exponent = 0;
            sign = 0;
            invalidOperation = true;
            static if (hasInvalidOperationMethod)
                hook.onInvalidOperation(this);
            return this;
        }

        if (isInf)
        {
            isInf = true;
            sign = sign;
            coefficient = 0;
            exponent = 0;
            return this;
        }

        if (rhs.isInf)
        {
            isInf = true;
            sign = rhsSign;
            coefficient = 0;
            exponent = 0;
            return this;
        }

        BigInt alignedCoefficient = coefficient;
        BigInt rhsAlignedCoefficient = rhs.coefficient;

        if (exponent != rhs.exponent)
        {
            long diff;

            if (exponent > rhs.exponent)
            {
                diff = abs(exponent - rhs.exponent);
                alignedCoefficient *= BigInt(10) ^^ diff;
            }
            else
            {
                diff = abs(rhs.exponent - exponent);
                rhsAlignedCoefficient *= BigInt(10) ^^ diff;
            }
        }

        exponent = min(exponent, rhs.exponent);
        // If the signs of the operands differ then the smaller aligned coefficient
        // is subtracted from the larger; otherwise they are added.
        if (sign == rhsSign)
        {
            coefficient = alignedCoefficient + rhsAlignedCoefficient;
        }
        else
        {
            if (alignedCoefficient >= rhsAlignedCoefficient)
            {
                coefficient = alignedCoefficient - rhsAlignedCoefficient;
            }
            else
            {
                coefficient = rhsAlignedCoefficient - alignedCoefficient;
            }
        }

        if (coefficient != 0)
        {
            // the sign of the result is the sign of the operand having
            // the larger absolute value.
            if (alignedCoefficient >= rhsAlignedCoefficient)
                sign = sign;
            else
                sign = rhsSign;
        }
        else
        {
            if (sign == 1 && rhsSign == 1)
                sign = 1;
            else
                sign = 0;

            static if (roundingMode == Rounding.Floor)
                if (sign != rhsSign)
                    sign = 1;
        }

        static if (doRound)
            coefficient = round(coefficient);

        return this;
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

    /**
     * Constructs an exact decimal type from a built in number
     * 
     * Params:
     *     num = the number to convert to exact decimal
     * 
     * Note:
     *     Using `float` types for construction is less accurate than using a string
     *     representation due to floating point inaccuracy. If possible, it's always
     *     better to use string construction.
     */
    this(T)(T num) pure // for some reason doesn't infer pure
    if (isNumeric!T)
    {
        opAssign(num);
    }

    /**
     * Converts a string representing a number to an exact decimal.
     *
     * If the string does not represent a number, then the result is `NaN`
     * and `invalidOperation` is `true`.
     *
     * Params:
     *     str = The string to convert from
     *
     * String_Spec:
     * -------
     * sign           ::=  + | -
     * digit          ::=  0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
     * indicator      ::=  e | E
     * digits         ::=  digit [digit]...
     * decimal-part   ::=  digits . [digits] | [.] digits
     * exponent-part  ::=  indicator [sign] digits
     * infinity       ::=  Infinity | Inf
     * nan            ::=  NaN [digits]
     * numeric-value  ::=  decimal-part [exponent-part] | infinity
     * numeric-string ::=  [sign] numeric-value | [sign] nan
     * -------
     *
     * Exceptional_Conditions:
     *     invalidOperation is flagged when `str` is not a valid string
     */
    this(S)(S str)
    if (isForwardRange!S && isSomeChar!(ElementEncodingType!S) && !isInfinite!S && !isSomeString!S)
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

        // TODO: filter out underscores

        if (str.empty)
        {
            isNan = true;
            return;
        }

        immutable frontResult = str.front;
        bool sawDecimal = false;
        bool sawExponent = false;
        bool sawExponentSign = false;
        byte exponentSign;
        int sciExponent = 0;

        if (frontResult == '+')
        {
            str.popFront;
        }
        else if (frontResult == '-')
        {
            sign = 1;
            str.popFront;
        }

        if (str.empty)
        {
            sign = 0;
            goto Lerr;
        }

        if (str.among!((a, b) => asciiCmp(a.save, b))
               ("inf", "infinity"))
        {
            isInf = true;
            return;
        }

        // having numbers after nan is valid in the spec
        if (str.save.map!toLower.startsWith("nan".byChar))
        {
            isNan = true;
            return;
        }

        // leading zeros
        while (!str.empty && str.front == '0')
            str.popFront;

        for (; !str.empty; str.popFront)
        {
            auto digit = str.front;

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
                    while (!str.empty)
                    {
                        if (!isDigit(str.front))
                            goto Lerr;

                        sciExponent += cast(uint) (str.front - '0');
                        if (!str.empty)
                        {
                            str.popFront;
                            if (!str.empty)
                                sciExponent *= 10;
                        }
                    }

                    if (sawExponentSign && exponentSign == -1)
                        sciExponent *= -1;

                    exponent += sciExponent;

                    if (str.empty)
                    {
                        coefficient = round(coefficient);
                        return;
                    }
                }

                continue;
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

                continue;
            }

            if (digit == '.')
            {
                // already have decimal, bad input so cancel out
                if (sawDecimal)
                    goto Lerr;

                sawDecimal = true;
                continue;
            }

            if (digit.toLower == 'e')
            {
                // already have exponent, bad input so cancel out
                if (sawExponent)
                    goto Lerr;

                sawExponent = true;
                continue;
            }

            goto Lerr;
        }

        coefficient = round(coefficient);
        return;

        Lerr:
            isNan = true;
            coefficient = 0;
            exponent = 0;

            invalidOperation = true;
            static if (hasInvalidOperationMethod)
                hook.onInvalidOperation(this);

            return;
    }

    /// ditto
    this(S)(S str) pure if (isSomeString!S)
    {
        // hack to allow pure annotation for immutable construction
        // see Issue 17330
        import std.utf : byCodeUnit;
        this(str.byCodeUnit);
    }

    /**
     * Changes the value of this decimal to the value of a built-in number 
     *
     * Params:
     *     num = the number to convert to exact decimal
     * 
     * Note:
     *     Using `float` types for construction is less accurate than using a string
     *     representation due to floating point inaccuracy. If possible, it's always
     *     better to use string construction.
     */
    auto opAssign(T)(T num) if (isNumeric!T)
    {
        // the behavior of conversion from built-in number types
        // isn't covered by the spec, so we can do whatever we
        // want here

        static if (isIntegral!T)
        {
            static if (isSigned!T)
            {
                import std.math : abs;

                // work around int.min bug where abs(int.min) == int.min
                static if (T.sizeof <= int.sizeof)
                    coefficient = abs(cast(long) num);
                else
                    coefficient = abs(num);
                
                sign = num >= 0 ? 0 : 1;
            }
            else
            {
                coefficient = num;
            }
        }
        else
        {
            import std.math : abs, isInfinity, isIdentical, isNaN;

            Unqual!T val = num;

            if (isInfinity(val))
            {
                isInf = true;
                sign = val > 0 ? 0 : 1;
                return this;
            }

            if (isNaN(val))
            {
                isNan = true;
                sign = isIdentical(val, T.nan) ? 0 : 1;
                return this;
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

        coefficient = round(coefficient);
        return this;
    }

    /**
     * Performs a binary operation between two decimals, or a decimal and
     * a built in number.
     * 
     * The result has the hook of the left hand side. On non-assignment
     * operations invalid operations do not effect the left hand side of
     * the operation.
     *
     * When the right hand side is a built-in numeric type, the default
     * hook `Abort` is used for its decimal representation.
     *
     * Params:
     *     rhs = the right-hand side of the operation
     *
     * Exceptional_Conditions:
     *     `invalidOperation` is flagged under the following conditions
     *     $(UL
     *         $(LI Adding Infinity and -Infinity, and vice-versa)
     *         $(LI Multiplying +/-Infinity by +/-zero)
     *         $(LI Dividing anything but zero by zero)
     *         $(LI Dividing +/-Infinity by +/-Infinity)
     *     )
     *     `divisionByZero` is flagged when dividing anything but zero by zero
     */
    auto opBinary(string op, T)(T rhs) const
    if (op == "+" || op == "-" || op == "*" || op == "/")
    {
        auto lhs = dup();
        return lhs.opOpAssign!(op, T)(rhs);
    }

    /// ditto
    ref Decimal!(Hook) opOpAssign(string op, T)(T rhs)
    if (op == "+" || op == "-" || op == "*" || op == "/")
    {
        static if (isNumeric!T)
        {
            auto temp = decimal(rhs);
            return mixin("this " ~ op ~ "= temp");
        }
        else static if (op == "+" || op == "-")
        {
            return addImpl!(op, true)(rhs);
        }
        else static if (op == "*")
        {
            if (isNan || rhs.isNan)
            {
                // the sign of the first nan is simply propagated
                if (isNan)
                    sign = sign;
                else if (rhs.isNan)
                    sign = rhs.sign;

                isNan = true;
                isInf = false;
                coefficient = 0;
                exponent = 0;

                return this;
            }

            sign = sign ^ rhs.sign;

            if (isInf && rhs.isInf)
            {
                isInf = true;
                coefficient = 0;
                exponent = 0;
                return this;
            }

            if (isInf || rhs.isInf)
            {
                if ((isInf && rhs.coefficient == 0) || (rhs.isInf && coefficient == 0))
                {
                    isNan = true;
                    coefficient = 0;
                    exponent = 0;
                    invalidOperation = true;
                    static if (hasInvalidOperationMethod)
                        hook.onInvalidOperation(this);
                }
                else
                {
                    isInf = true;
                    coefficient = 0;
                    exponent = 0;
                }

                return this;
            }

            static if (is(typeof(coefficient) == typeof(rhs.coefficient)))
            {
                coefficient = coefficient * rhs.coefficient;
            }
            else
            {
                import std.conv : to;
                coefficient = coefficient * to!(typeof(coefficient))(rhs.coefficient);
            }
            
            exponent = exponent + rhs.exponent;

            coefficient = round(coefficient);
            return this;
        }
        else static if (op == "/")
        {
            if (isNan || rhs.isNan)
            {
                // the sign of the first nan is simply propagated
                if (isNan)
                    sign = sign;
                else if (rhs.isNan)
                    sign = rhs.sign;

                isInf = false;
                isNan = true;
                coefficient = 0;
                exponent = 0;

                return this;
            }

            if (isInf && rhs.isInf)
            {
                isInf = false;
                isNan = true;
                coefficient = 0;
                exponent = 0;
                sign = 0;
                invalidOperation = true;
                static if (hasInvalidOperationMethod)
                    hook.onInvalidOperation(this);
                return this;
            }

            if (rhs.coefficient == 0 && coefficient == 0)
            {
                isNan = true;
                coefficient = 0;
                exponent = 0;
                divisionByZero = true;

                static if (hasDivisionByZeroMethod)
                    hook.onDivisionByZero(this);

                return this;
            }

            sign = sign ^ rhs.sign;

            if (isInf && !rhs.isInf)
            {
                isInf = true;
                coefficient = 0;
                exponent = 0;
                return this;
            }

            if (!isInf && rhs.isInf)
            {
                coefficient = 0;
                exponent = 0;
                return this;
            }

            if (rhs.coefficient == 0 && coefficient != 0)
            {
                divisionByZero = true;
                invalidOperation = true;
                isInf = true;

                static if (hasDivisionByZeroMethod)
                    hook.onDivisionByZero(this);
                static if (hasInvalidOperationMethod)
                    hook.onInvalidOperation(this);

                return this;
            }

            int adjust;
            BigInt res;
            BigInt dividend = coefficient;
            BigInt divisor = rhs.coefficient;

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
                        ++res;
                    }

                    if ((dividend == 0 && adjust >= 0) || numberOfDigits(res) == precision + 1)
                    {
                        break;
                    }
                    else
                    {
                        res *= 10;
                        dividend *= 10;
                        ++adjust;
                    }
                }
            }

            coefficient = round(res);
            exponent = exponent - (rhs.exponent + adjust);
            return this;
        }
        else
        {
            static assert(0, "Not implemented yet");
        }
    }

    /**
     * Returns:
     *     `+` simply returns a copy of `this` unchanged. `-` returns a
     *     copy of `this` with the sign flipped for everything but `0`
     *     and `NaN`s.
     *
     *     Does not modify the decimal in place.
     */
    auto opUnary(string op)() const
    if (op == "-" || op == "+")
    {
        auto res = dup();

        static if (op == "-")
            if ((!isNan && coefficient != 0) || isInf)
                res.sign = sign == 0 ? 1 : 0;

        return res;
    }

    /**
     * Modifies the decimal in place by adding or subtracting 1 for
     * `++` and `--` respectively.
     */
    ref Decimal!(Hook) opUnary(string op)()
    if (op == "++" || op == "--")
    {
        static immutable one = decimal(1);
        static if (op == "++")
            this += one;
        else
            this -= one;

        return this;
    }

    // goes against D's normal nan rules because they're really annoying when
    // sorting an array of floating point numbers
    /**
     * `-Infinity` is less than all numbers, `-NaN` is greater than `-Infinity` but
     * less than all other numbers, `NaN` is greater than `-NaN` but less than all other
     * numbers and `Infinity` is greater than all numbers. `-NaN` and `NaN` are equal to
     * themselves.
     *
     * Params:
     *     d = the decimal or built-in number to compare to
     *
     * Returns:
     *     Barring special values, `0` if subtracting the two numbers yields
     *     `0`, `-1` if the result is less than `0`, and `1` if the result is
     *     greater than zero
     */
    int opCmp(T)(T d) const if (isNumeric!T || isInstanceOf!(TemplateOf!(Decimal), T))
    {
        static if (!isNumeric!T)
        {
            if (isInf)
            {
                if (sign == 1 && (isInf != d.isInf || sign != d.sign))
                    return -1;
                if (sign == 0 && (isInf != d.isInf || sign != d.sign))
                    return 1;
                if (d.isInf && sign == d.sign)
                    return 0;
            }

            if (isNan && d.isNan)
            {
                if (sign == d.sign)
                    return 0;
                if (sign == 1)
                    return -1;

                return 1;
            }

            if (isNan && !d.isNan)
                return -1;
            if (!isNan && d.isNan)
                return 1;
            if (sign != d.sign && coefficient != 0 && d.coefficient != 0)
                return sign ? -1 : 1;
            if (coefficient == d.coefficient && coefficient == 0)
                return 0;

            auto lhs = dup();
            lhs.addImpl!("-", false)(d);

            if (lhs.sign == 0)
            {
                if (lhs.coefficient == 0)
                    return 0;
                else
                    return 1;
            }

            return -1;
        }
        else
        {
            static if (isIntegral!T)
            {
                if (exponent == 0 && sign == 0)
                {
                    if (coefficient == d)
                        return 0;
                    if (coefficient < d)
                        return -1;
                    if (coefficient > d)
                        return 1;
                }
            }

            return this.opCmp(d.decimal);
        }
    }

    /// Returns: `true` if `opCmp` would return `0`
    bool opEquals(T)(T d) const
    {
        return this.opCmp(d) == 0;
    }

    /**
     * Throws:
     *     A `ConvException` if `isIntegral!T` and the decimal is NaN or Infinite.
     *
     *     A `ConvOverflowException` if `isIntegral!T` and the decimal's value
     *     is outside of `T.min` and `T.max`.
     * Returns:
     *     For `bool`, follows the normal `cast(bool)` rules for floats in D.
     *     Numbers `<= -1` returns `true`, numbers between `-1` and `1` return
     *     false, numbers `>= 1` return `true`.
     *
     *     For floating point types, returns a floating point type as close to the
     *     decimal as possible.
     */
    auto opCast(T)() const
    if (is(T == bool) || isNumeric!T)
    {
        static if (is(T == bool))
        {
            static immutable negone = decimal(-1);
            static immutable one = decimal(1);

            if (isNan || isInf)
                return true;

            if (this <= negone || this >= one)
                return true;

            return false;
        }
        else static if (isIntegral!T)
        {
            import std.algorithm.comparison : max;
            import std.conv : to, text, ConvException, ConvOverflowException;
            import std.math : abs;

            if (isNan || isInf)
                throw new ConvException(text(
                    "Can't cast ", toDecimalString(), " ", Decimal.stringof, " to ", T.stringof
                ));
            if (this > T.max || this < T.min)
                throw new ConvOverflowException(text(
                    "Can't cast ", toDecimalString(), " ", Decimal.stringof, " to ", T.stringof
                ));

            T res = to!(T)(coefficient);

            if (exponent < 0)
                res /= max(10 ^^ abs(exponent), 1);
            if (exponent > 0)
                res *= max(10 ^^ abs(exponent), 1);

            if (sign)
                res *= -1;

            return res;
        }
        else
        {
            import std.conv : to;

            if (isInf)
            {
                if (sign == 0)
                    return T.infinity;
                return -T.infinity;
            }
            if (isNan)
            {
                if (sign == 0)
                    return T.nan;
                return -T.nan;
            }

            // this really needs to be reworked, the problem really
            // is that both BigInt and uint128 both cast to ints but
            // not to floats, and casting to ints cuts off more than
            // half of the number, this method however gets pretty close
            // to the equivalent floating point representation of the
            // decimal
            T res = coefficient.toDecimalString.to!T;
            
            res *= 10.0 ^^ exponent;
            if (sign == 1)
                res *= -1;
            return res;
        }
    }

    /**
     * Convenience function to reset all exceptional condition flags to `false` at once
     */
    void resetFlags() @safe @nogc pure nothrow
    {
        clamped = false;
        divisionByZero = false;
        inexact = false;
        invalidOperation = false;
        overflow = false;
        rounded = false;
        subnormal = false;
        underflow = false;
    }

    /// Returns: A mutable copy of this `Decimal`. Also copies current flags.
    Decimal!(Hook) dup()() const
    {
        Unqual!(typeof(this)) res;
        res.coefficient = coefficient;
        res.exponent = exponent;
        res.sign = sign;
        res.isNan = isNan;
        res.isInf = isInf;
        res.clamped = clamped;
        res.divisionByZero = divisionByZero;
        res.inexact = inexact;
        res.invalidOperation = invalidOperation;
        res.overflow = overflow;
        res.rounded = rounded;
        res.subnormal = subnormal;
        res.underflow = underflow;

        return res;
    }

    /// Returns: An immutable copy of this `Decimal`. Also copies current flags.
    immutable(Decimal!(Hook)) idup()() const
    {
        return dup!()();
    }

    /// Returns: A decimal representing a positive NaN
    static Decimal!(Hook) nan()() @property
    {
        Decimal!(Hook) res;
        res.isNan = true;
        return res;
    }

    /// Returns: A decimal representing positive Infinity
    static Decimal!(Hook) infinity()() @property
    {
        Decimal!(Hook) res;
        res.isInf = true;
        return res;
    }

    /**
     * Returns: The maximum value that this decimal type can represent.
     * Equal to `(1 * 10 ^^ (maxExponent + 1)) - 1`
     */
    static Decimal!(Hook) max()() @property
    {
        import std.range : repeat;
        Decimal!(Hook) res;
        res.coefficient = BigInt('9'.repeat(precision));
        res.exponent = maxExponent;
        return res;
    }

    /**
     * Returns: The minimum value that this decimal type can represent.
     * Equal to `-1 * 10 ^^ minExponent`
     */
    static Decimal!(Hook) min()() @property
    {
        Decimal!(Hook) res;
        res.coefficient = 1;
        res.exponent = minExponent;
        res.sign = 1;
        return res;
    }

    ///
    alias toString = toDecimalString;

    /// Returns: Returns the decimal string representation of this decimal.
    auto toDecimalString() const
    {
        import std.array : appender;
        import std.math : abs;

        auto app = appender!string();
        if (exponent > 10 || exponent < -10)
            app.reserve(abs(exponent) + precision);
        toDecimalString(app);
        return app.data;
    }

    /// ditto
    void toDecimalString(Writer)(ref Writer w) const if (isOutputRange!(Writer, char))
    {
        import std.math : pow;
        import std.range : repeat;

        if (sign == 1)
            put(w, '-');

        if (isInf)
        {
            put(w, "Infinity");
            return;
        }

        if (isNan)
        {
            put(w, "NaN");
            return;
        }

        auto temp = coefficient.toDecimalString;
        auto decimalPlace = exponent * -1;

        if (decimalPlace > 0)
        {
            if (temp.length - decimalPlace == 0)
            {
                put(w, "0.");
                put(w, temp);
                return;
            }

            if ((cast(long) temp.length) - decimalPlace > 0)
            {
                put(w, temp[0 .. $ - decimalPlace]);
                put(w, '.');
                put(w, temp[$ - decimalPlace .. $]);
                return;
            }

            if ((cast(long) temp.length) - decimalPlace < 0)
            {
                put(w, "0.");
                put(w, '0'.repeat(decimalPlace - temp.length));
                put(w, temp);
                return;
            }
        }

        if (decimalPlace < 0)
        {
            put(w, temp);
            put(w, '0'.repeat(exponent));
            return;
        }

        put(w, temp);
    }
}

// string construction
@system
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
        bool isNan;
        bool isInf;
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
        Test("0001.0000", 0, 10_000, -4),
        Test("-10.0004", 1, 100_004, -4),
        Test("+15", 0, 15, 0),
        Test("-15", 1, 15, 0),
        Test("1234.5E-4", 0, 12_345, -5),
        Test("30.5E10", 0, 305, 9) 
    ];

    auto specialTestValues = [
        SpecialTest("NaN", 0, true, false, false),
        SpecialTest("+nan", 0, true, false, false),
        SpecialTest("-nan", 1, true, false, false),
        SpecialTest("-NAN", 1, true, false, false),
        SpecialTest("Infinite", 0, true, false, true),
        SpecialTest("infinity", 0, false, true, false),
        SpecialTest("-INFINITY", 1, false, true, false),
        SpecialTest("inf", 0, false, true, false),
        SpecialTest("-inf", 1, false, true, false),
        SpecialTest("Jack", 0, true, false, true),
        SpecialTest("+", 0, true, false, true),
        SpecialTest("-", 0, true, false, true),
        SpecialTest("nan0123", 0, true, false, false),
        SpecialTest("-nan0123", 1, true, false, false),
        SpecialTest("12+3", 0, true, false, true),
        SpecialTest("1.2.3", 0, true, false, true),
        SpecialTest("123.0E+7E+7", 0, true, false, true),
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
        assert(d.isNan == el.isNan);
        assert(d.isInf == el.isInf);
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
    assert(d1.coefficient == 123_456);
    assert(d1.sign == 0);
    assert(d1.exponent == -3);

    auto r2 = new ReferenceForwardRange!dchar("-0.00004");
    auto d2 = Decimal!()(r2);
    assert(d2.coefficient == 4);
    assert(d2.sign == 1);
    assert(d2.exponent == -5);
}

// int construction
@system
unittest
{
    static struct Test
    {
        long val;
        ubyte sign;
        long coefficient;
    }

    static immutable testValues = [
        Test(10, 0, 10),
        Test(-10, 1, 10),
        Test(-1_000_000, 1, 1_000_000),
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
@system
unittest
{
    static struct Test
    {
        double val;
        ubyte sign;
        long coefficient;
        long exponent;
    }

    static struct SpecialTest
    {
        double val;
        ubyte sign;
        bool isNan;
        bool isInf;
    }

    auto nonspecialTestValues = [
        Test(0.02, 0, 2, -2),
        Test(0.00002, 0, 2, -5),
        Test(1.02, 0, 102, -2),
        Test(200.0, 0, 200, 0),
        Test(1234.5678, 0, 12_345_678, -4),
        Test(-1234.5678, 1, 12_345_678, -4),
        Test(-1234, 1, 1234, 0),
        Test(int.min, 1, 2147483648, 0),
    ];

    auto specialTestValues = [
        SpecialTest(float.nan, 0, true, false),
        SpecialTest(-float.nan, 1, true, false),
        SpecialTest(float.infinity, 0, false, true),
        SpecialTest(-float.infinity, 1, false, true),
    ];

    foreach (el; nonspecialTestValues)
    {
        auto d = Decimal!()(el.val);
        assert(d.coefficient == el.coefficient);
        assert(d.sign == el.sign);
        assert(d.exponent == el.exponent);

        Decimal!() d2;
        d2 = el.val;
        assert(d2.coefficient == el.coefficient);
        assert(d2.sign == el.sign);
        assert(d2.exponent == el.exponent);
    }

    foreach (el; specialTestValues)
    {
        auto d = Decimal!()(el.val);
        assert(d.sign == el.sign);
        assert(d.isNan == el.isNan);
        assert(d.isInf == el.isInf);

        Decimal!() d2;
        d2 = el.val;
        assert(d2.sign == el.sign);
        assert(d2.isNan == el.isNan);
        assert(d2.isInf == el.isInf);
    }
}

// static ctors
@system pure
unittest
{
    alias DType = Decimal!();

    auto d1 = DType.nan;
    assert(d1.isNan == true);
    auto d2 = DType.infinity;
    assert(d2.isInf == true);

    auto d3 = DType.max;
    assert(d3 == decimal("9999999999999999E999"));
    auto d4 = DType.min;
    assert(d4 == decimal("-1E-999"));
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
        Test("10E25", "10E4", "100000000000000000000000000"),
        Test("0.9998", "0.0000", "0.9998"),
        Test("1", "0.0001", "1.0001"),
        Test("1", "0.00", "1.00"),
        Test("123.00", "3000.00", "3123.00"),
        Test("123.00", "3000.00", "3123.00"),
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

    // test that opOpAssign works properly
    auto d1 = decimal("3.55");
    d1 += 0.45;
    assert(d1.toString() == "4.00");
    auto d2 = decimal("3.55");
    d2 -= 0.55;
    assert(d2.toString() == "3.00");

    static struct CustomHook
    {
        enum Rounding roundingMode = Rounding.HalfUp;
        enum uint precision = 3;
    }

    // rounding test on addition
    auto d3 = decimal!(CustomHook)("0.999E-2");
    auto d4 = decimal!(CustomHook)("0.1E-2");
    auto v = d3 + d4;
    assert(v.toString == "0.0110");
    assert(v.inexact);
    assert(v.rounded);

    // higher precision tests
    auto d5 = decimal!(HighPrecision)("10000e+9");
    auto d6 = decimal!(HighPrecision)("7");
    auto v2 = d5 - d6;
    assert(v2.toString() == "9999999999993");

    auto d7 = decimal!(HighPrecision)("1e-50");
    auto d8 = decimal!(HighPrecision)("4e-50");
    auto v3 = d7 + d8;
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
        Test("1.23456789", "1.00000000", "1.234567890000000", false, true),
        Test("123456789", "10", "1234567890", false, false),
        Test("123456789", "100000000000000", "12345678900000000000000", false, true),
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
        Test("Inf", "-NaN", "-NaN")
    ];

    foreach (el; testValues)
    {
        auto d = decimal!(NoOp)(el.val1) * decimal!(NoOp)(el.val2);
        assert(d.toString() == el.expected);
        assert(d.invalidOperation == el.invalidOperation);
        assert(d.rounded == el.rounded);
    }

    // test that opOpAssign works properly
    auto d1 = decimal("2.5");
    d1 *= 5.4;
    assert(d1.toString() == "13.50");
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
        Test("1", "3", "0.3333333333333333", false, false, true, true),
        Test("2", "3", "0.6666666666666667", false, false, true, true),
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

    // test that opOpAssign works properly
    auto d1 = decimal(1000);
    d1 /= 10;
    assert(d1.toString() == "100");

    // test that the proper DivisionByZero function is called
    assertThrown!DivisionByZero(() { cast(void) (decimal!(Throw)(1) / decimal(0)); } ());
}

// cmp and equals
@system
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

// unary
@system
unittest
{
    auto testPlusValues = [
        ["1", "1"],
        ["0", "0"],
        ["00.00", "0.00"],
        ["-2000000", "-2000000"],
        ["Inf", "Infinity"],
        ["NaN", "NaN"],
        ["-NaN", "-NaN"],
    ];

    auto testMinusValues = [
        ["1", "-1"],
        ["-1", "1"],
        ["0.00", "0.00"],
        ["-2000000", "2000000"],
        ["Inf", "-Infinity"],
        ["NaN", "NaN"],
        ["-NaN", "-NaN"]
    ];

    auto testPlusPlusValues = [
        ["1", "2"],
        ["-1", "0"],
        ["0.00", "1.00"],
        ["1.0000001", "2.0000001"],
        ["-2000000", "-1999999"],
        ["Inf", "Infinity"],
        ["-Inf", "-Infinity"],
        ["NaN", "NaN"],
        ["-NaN", "-NaN"]
    ];

    auto testMinusMinusValues = [
        ["1", "0"],
        ["-1", "-2"],
        ["1.00", "0.00"],
        ["1.0000001", "0.0000001"],
        ["-2000000", "-2000001"],
        ["Inf", "Infinity"],
        ["-Inf", "-Infinity"],
        ["NaN", "NaN"],
        ["-NaN", "-NaN"]
    ];

    foreach (el; testPlusValues)
    {
        auto d1 = decimal!(NoOp)(el[0]);
        auto d2 = +d1;
        assert(d2.toString == el[1]);
    }
    foreach (el; testMinusValues)
    {
        auto d1 = decimal!(NoOp)(el[0]);
        auto d2 = -d1;
        assert(d2.toString == el[1]);
    }
    foreach (el; testPlusPlusValues)
    {
        auto d1 = decimal!(NoOp)(el[0]);
        ++d1;
        assert(d1.toString == el[1]);
    }
    foreach (el; testMinusMinusValues)
    {
        auto d1 = decimal!(NoOp)(el[0]);
        --d1;
        assert(d1.toString == el[1]);
    }
}

// opCast
@system
unittest
{
    import std.exception : assertThrown;
    import std.conv : ConvException, ConvOverflowException;
    import std.math : approxEqual, isNaN;

    assert((cast(bool) decimal("0.0")) == false);
    assert((cast(bool) decimal("0.5")) == false);
    assert((cast(bool) decimal("-0.5")) == false);
    assert((cast(bool) decimal("-1.0")) == true);
    assert((cast(bool) decimal("1.0")) == true);
    assert((cast(bool) decimal("1.1")) == true);
    assert((cast(bool) decimal("-1.1")) == true);
    assert((cast(bool) decimal("Infinity")) == true);
    assert((cast(bool) decimal("-Infinity")) == true);
    assert((cast(bool) decimal("-NaN")) == true);
    assert((cast(bool) decimal("NaN")) == true);

    assert((cast(real) decimal("0.0")).approxEqual(0));
    assert((cast(real) decimal("0.0123")).approxEqual(0.0123));
    assert((cast(real) decimal("123")).approxEqual(123.0));
    assert((cast(real) decimal("10.8888")).approxEqual(10.8888));
    assert(isNaN((cast(real) decimal("NaN"))));
    assert(isNaN((cast(real) decimal("-NaN"))));
    assert((cast(real) decimal("Inf")) == real.infinity);
    assert((cast(real) decimal("-Inf")) == -real.infinity);

    assert((cast(int) decimal("1")) == 1);
    assert((cast(int) decimal("1.0")) == 1);
    assert((cast(int) decimal("0.0")) == 0);
    assert((cast(int) decimal("-0")) == 0);
    assert((cast(int) decimal("-1")) == -1);
    assert((cast(int) decimal("0.0001")) == 0);
    assert((cast(int) decimal("10000.0001")) == 10000);
    assert((cast(ulong) decimal("-0")) == 0);
    assert((cast(ulong) decimal("0.0001")) == 0);
    assert((cast(ulong) decimal("10000.0001")) == 10000);

    assertThrown!(ConvOverflowException)((cast(ulong) decimal("-1")));
    assertThrown!(ConvException)((cast(ulong) decimal("INF")));
    assertThrown!(ConvException)((cast(ulong) decimal("NaN")));

    static struct CustomHook
    {
        enum Rounding roundingMode = Rounding.HalfUp;
        enum uint precision = 19;
    }

    assert((
        cast(real) decimal!(CustomHook)("12345678910111.213")
    ).approxEqual(12345678910111.213));

    assert((
        cast(real) decimal!(HighPrecision)("12345678910111213141516.1718192021")
    ).approxEqual(12345678910111213141516.1718192021));
}

// to string
@system
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

// test hook setting enums
@safe pure
unittest
{
    static assert(Decimal!(void).precision == 16);
    static assert(Decimal!(void).roundingMode == Rounding.HalfUp);
    static assert(Decimal!(void).maxExponent == 999);
    static assert(Decimal!(void).minExponent == -999);

    static struct A
    {
        enum maxExponent = 10;
    }
    static assert(Decimal!(A).precision == 16);
    static assert(Decimal!(A).roundingMode == Rounding.HalfUp);
    static assert(Decimal!(A).maxExponent == 10);
    static assert(Decimal!(A).minExponent == -999);

    static struct B
    {
        enum precision = 10;
        enum Rounding roundingMode = Rounding.Down;
        enum maxExponent = 10;
        enum minExponent = -10;
    }
    static assert(Decimal!(B).precision == 10);
    static assert(Decimal!(B).roundingMode == Rounding.Down);
    static assert(Decimal!(B).maxExponent == 10);
    static assert(Decimal!(B).minExponent == -10);
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
        Test(12_345, 12345, false, false),
        Test(123_449, 12344, true, true),
        Test(1_234_499_999, 12_344, true, true),
        Test(123_451, 12_345, true, true),
        Test(123_450_000_001, 12_345, true, true),
        Test(1_234_649_999, 12_346, true, true),
        Test(123_465, 12_346, true, true),
        Test(1_234_650_001, 12_346, true, true),
        Test(1_234_500, 12_345, false, true)
    ];
    auto upValues = [
        Test(12_345, 12_345, false, false),
        Test(1_234_499, 12_345, true, true),
        Test(123_449_999_999, 12_345, true, true),
        Test(123_450_000_001, 12_346, true, true),
        Test(123_451, 12_346, true, true),
        Test(1_234_649_999, 12_347, true, true),
        Test(123_465, 12_347, true, true),
        Test(123_454, 12_346, true, true),
        Test(1_234_500, 12_345, false, true)
    ];
    auto halfUpValues = [
        Test(12_345, 12_345, false, false),
        Test(123_449, 12_345, true, true),
        Test(1_234_499, 12_345, true, true),
        Test(12_344_999, 12_345, true, true),
        Test(123_451, 12_345, true, true),
        Test(1_234_501, 12_345, true, true),
        Test(123_464_999, 12_346, true, true),
        Test(123_465, 12_347, true, true),
        Test(1_234_650_001, 12_347, true, true),
        Test(123_456, 12_346, true, true),
        Test(1_234_500, 12_345, false, true)
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

    static struct HigherHook
    {
        enum uint precision = 16;
        enum Rounding roundingMode = Rounding.HalfUp;
    }

    static struct HigherHookDown
    {
        enum uint precision = 16;
        enum Rounding roundingMode = Rounding.Down;
    }

    static struct HigherHookUp
    {
        enum uint precision = 16;
        enum Rounding roundingMode = Rounding.Up;
    }

    auto d2 = decimal!(HigherHook)("10000000000000005");
    assert(d2.rounded);
    assert(d2.toString() == "10000000000000010");

    auto d3 = decimal!(HigherHookDown)("10000000000000005");
    assert(d3.rounded);
    assert(d3.toString() == "10000000000000000");

    auto d4 = decimal!(HigherHookUp)("10000000000000001");
    assert(d4.rounded);
    assert(d4.toString() == "10000000000000010");
}

// mixing of different precisions
@system
unittest
{
    static struct CustomHook
    {
        enum Rounding roundingMode = Rounding.HalfUp;
        enum uint precision = 19;
    }

    auto d1 = decimal!(HighPrecision)("10000000000000000000");
    auto d2 = decimal!(HighPrecision)("120000000000.0000");
    auto d3 = decimal!(NoOp)("10000.00");
    auto d4 = decimal!(CustomHook)("120000000000.0000");
    auto d5 = d1 - d4;
    auto d6 = d4 - d1;
    auto d7 = d1 - d3;
    auto d8 = d1 * d4;
    auto d9 = d1 * d3;
    auto d10 = d4 * d1;
    auto d11 = d1 / d4;
    auto d12 = d4 / d1;
    auto d13 = d1 / d3;

    assert(d1.opCmp(d2) == 1);
    assert(d1.opCmp(d3) == 1);
    assert(d3.opCmp(d4) == -1);
    assert(d5 == decimal!(HighPrecision)("9999999880000000000.0000"));
    assert(d6 == decimal!(CustomHook)("-9999999880000000000.0000"));
    assert(d7 == decimal!(HighPrecision)("9999999999999990000.00"));
    assert(d8 == decimal!(HighPrecision)("1200000000000000000000000000000.0000"));
    assert(d9 == decimal!(HighPrecision)("100000000000000000000000.00"));
    assert(d10 == decimal!(CustomHook)("1200000000000000000000000000000"));
    assert(d11 == decimal!(HighPrecision)("83333333.33333333333333333333333333333333333333333333333333333333"));
    assert(d12 == decimal!(CustomHook)("0.000000012"));
    assert(d13 == decimal!(HighPrecision)("1000000000000000"));
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
@system
unittest
{
    auto d1 = decimal(5.5);
    assert(d1.toString == "5.5");

    auto d2 = decimal("500.555");
}

/**
 * Controls what happens when the number of significant digits exceeds `Hook.precision`
 */
enum Rounding
{
    /**
     * Round toward 0, a.k.a truncate. The discarded digits are ignored.
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
 * overflows, and underflows.
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
 * Same as abort, but offers 64 significant digits
 *
 * Note: As noted in the module overview, using 64 significant digits is
 * slower than `16` or `19`.
 */
struct HighPrecision
{
    ///
    enum Rounding roundingMode = Rounding.HalfUp;
    ///
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
    enum uint precision = 16;

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

/// Returns: If this decimal represents a positive or negative NaN
bool isNaN(D)(const D d) if (isInstanceOf!(Decimal, D))
{
    return d.isNan;
}

///
@system unittest
{
    assert( isNaN(decimal("NaN")));
    assert( isNaN(decimal("-NaN")));
    assert(!isNaN(decimal("Inf")));
    assert(!isNaN(decimal("1.001")));
}

/// Returns: If this decimal represents positive or negative infinity
bool isInfinity(D)(const D d) if (isInstanceOf!(Decimal, D))
{
    return d.isInf;
}

///
@system unittest
{
    assert( isInfinity(decimal("Inf")));
    assert( isInfinity(decimal("-Inf")));
    assert(!isInfinity(decimal("NaN")));
    assert(!isInfinity(decimal("1.001")));
}

/// Returns: The given decimal with a positive sign
auto abs(D)(const D d) if (isInstanceOf!(Decimal, D))
{
    if (d.sign == 1)
        return -d;
    return d;
}

///
unittest
{
    assert(abs(decimal("1.00")) == decimal("1.00"));
    assert(abs(decimal("-1.00")) == decimal("1.00"));
    assert(abs(decimal("-0.0002")) == decimal("0.0002"));
}

private:

/*
 * Get the number of digits in the decimal representation of a number
 */
auto numberOfDigits(T)(T x)
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
    BigInt num = BigInt(10_000_000_000_000_000_000UL);

    if (len == 3)
    {
        digits = 39;
        version(D_InlineAsm_X86)
        {
            num *= 10000000000000000000UL;
            num *= 10UL;
        }
        else
        {
            enum BigInt lentwo = BigInt("100000000000000000000");
            num *= lentwo;
        }
    }
    else if (len == 4)
    {
        digits = 58;
        version(D_InlineAsm_X86)
        {
            num *= 10000000000000000000UL;
            num *= 10000000000000000000UL;
            num *= 10UL;
        }
        else
        {
            enum BigInt lenthree = BigInt("1000000000000000000000000000000000000000");
            num *= lenthree;
        }
    }
    else if (len > 4)
    {
        digits = 78;
        version(D_InlineAsm_X86)
        {
            num *= 10000000000000000000UL;
            num *= 10000000000000000000UL;
            num *= 10000000000000000000UL;
            num *= 100UL;
        }
        else
        {
            enum BigInt lenfour = BigInt("100000000000000000000000000000000000000000000000000000000000");
            num *= lenfour;
        }
    }

    for (;; num *= 10, digits++)
    {
        if (x < num)
            return digits;
    }
}

@system pure
unittest
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
    assert(numberOfDigits(BigInt("1".byCodeUnit.chain('0'.repeat(99)))) == 100);
}

/*
 * Detect whether $(D X) is an enum type, or manifest constant.
 */
template isEnum(X...) if (X.length == 1)
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
