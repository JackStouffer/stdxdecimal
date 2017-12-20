This module defines an exact decimal type, `Decimal`, to a specific number of digits.
This is designed to be a drop in replacement for built-in floating point numbers,
allowing all the same possible operations.

Floating point numbers (`float`, `double`, `real`) are inherently inaccurate because
they $(HTTPS en.wikipedia.org/wiki/Floating-point_arithmetic#Accuracy_problems, cannot represent)
all possible numbers with a decimal part. `Decimal` on the other hand, is able to
represent all possible numbers with a decimal part (limited by memory size and `Hook`).

Adapted from the specification of the
$(HTTP http://speleotrove.com/decimal/decarith.html, General Decimal Arithmetic).

## Basic Example:

```d
import stdxdecimal;

void main()
{
    auto d1 = decimal("1.23E-10");
    d1 -= decimal("2.00E-10");
    assert(d1.toString() == "-0.000000000077");
}
```

## Custom Behavior

The behavior of `Decimal` is controlled by the template parameter `Hook`,
which can be a user defined type or one of the `Hook`s provided by this
module.

The following behaviors are controlled by `Hook`:

* The number of significant digits to store.
* The rounding method.
* The min and max exponents.
* What to do when exceptional conditions arise.

The following predefined `Hook`s are available:

<table>
    <tr>
        <td></td>
        <td>
            <code>precision</code> is set to 9, rounding is <code>HalfUp</code>, and the program will <code>assert(0)</code> on divsion by zero, overflow, underflow, and invalid operations.
        </td>
    </tr>
    <tr>
        <td></td>
        <td><code>precision</code> is set to 9, rounding is <code>HalfUp</code>, and the program will throw an exception on divsion by zero, overflow, underflow, and invalid operations.
        </td>
    </tr>
    <tr>
        <td></td>
        <td><code>precision</code> is set to 64, rounding is <code>HalfUp</code>, and the program will <code>assert(0)</code> on divsion by zero, overflow, underflow, and invalid operations.
        </td>
    </tr>
    <tr>
        <td></td>
        <td><code>precision</code> is set to 9, rounding is <code>HalfUp</code>, and nothing will happen on exceptional conditions.
        </td>
    </tr>
</table>

### Precision and Rounding

`Decimal` accurately stores as many as `Hook.precision` significant digits.
Once the number of digits `> Hook.precision`, then the number is rounded.
Rounding is performed according to the rules laid out in $(LREF RoundingMode).

By default, the precision is 9, and the rounding mode is `RoundingMode.HalfUp`.

`Hook.precision` must be `<= uint.max - 1` and `> 1`.

### Important Note About Precision

Increasing the number of possible significant digits can result in orders
of magnitude slower behavior, as described below. Only ask for as many digits
as you really need.

<table>
<tr>
    <td>9 and below (default)</td>
    <td>Baseline</td>
</tr>
<tr>
    <td>10-19</td>
    <td>2x slower than baseline</td>
</tr>
<tr>
    <td>20-1000</td>
    <td>20x slower than baseline</td>
</tr>
<tr>
    <td>1000 and above</td>
    <td>200x slower than baseline</td>
</tr>
</table>

## Exceptional Conditions

Certain operations will cause a `Decimal` to enter into an invalid state,
e.g. dividing by zero. When this happens, Decimal does two things

1. Sets a public `bool` variable to `true`.
2. Calls a specific function in `Hook`, if it exists, with the operation's result as the only parameter.

The following table lists all of the conditions

<table>
    <thead>
        <tr>
            <th>Name</th>
            <th>Flag</th>
            <th>Method</th>
            <th>Description</th>
        </tr>
   </thead>
   <tbody>
        <tr>
           <td>Clamped</td>
           <td>`clamped`</td>
           <td>`onClamped`</td>
           <td>Occurs when the exponent has been altered to fit in-between `Hook.maxExponent` and `Hook.minExponent`.</td>
        </tr>
        <tr>
           <td>Inexact</td>
           <td>`inexact`</td>
           <td>`onInexact`</td>
           <td>Occurs when the result of an operation is not perfectly accurate. Mostly occurs when rounding removed non-zero digits.</td>
        </tr>
        <tr>
           <td>Invalid Operation</td>
           <td>`invalidOperation`</td>
           <td>`onInvalidOperation`</td>
           <td>Flagged when an operation makes no sense, e.g. multiplying `0` and `Infinity` or add -Infinity to Infinity.</td>
        </tr>
        <tr>
           <td>Division by Zero</td>
           <td>`divisionByZero`</td>
           <td>`onDivisionByZero`</td>
           <td>Specific invalid operation. Occurs whenever the dividend of a division or modulo is equal to zero.</td>
        </tr>
        <tr>
           <td>Rounded</td>
           <td>`rounded`</td>
           <td>`onRounded`</td>
           <td>Occurs when the `Decimal`'s result had more than `Hook.precision` significant digits and was reduced.</td>
        </tr>
        <tr>
           <td>Subnormal</td>
           <td>`subnormal`</td>
           <td>`onSubnormal`</td>
           <td>Flagged when the exponent is less than `Hook.maxExponent` but the digits of the `Decimal` are not inexact.</td>
        </tr>
        <tr>
           <td>Overflow</td>
           <td>`overflow`</td>
           <td>`onOverflow`</td>
           <td>Not to be confused with integer overflow, this is flagged when the exponent of the result of an operation would have been above `Hook.maxExponent` and the result is inexact. Inexact and Rounded are always set with this flag.</td>
        </tr>
        <tr>
           <td>Underflow</td>
           <td>`underflow`</td>
           <td>`onUnderflow`</td>
           <td>Not to be confused with integer underflow, this is flagged when the exponent of the result of an operation would have been below `Hook.minExponent`. Inexact, Rounded, and Subnormal are always set with this flag.</td>
        </tr>
   </tbody>
</table>

Each function documentation lists the specific states that will led to one of these flags.

## Differences From The Specification

* There's no concept of a Signaling NaN in the module.
* `compare`, implemented as `opCmp`, does not propagate `NaN` due to D's `opCmp` semantics.


<section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal"></span>struct <code class="code">Decimal</code>(Hook = Abort);

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    A exact decimal type, accurate to <code class="code">Hook.precision</code> digits. Designed to be a
 drop in replacement for floating points.

  </p>
</div>
<div class="ddoc_description">
  <h4>Discussion</h4>
  <p class="para">
    Behavior is defined by <code class="code">Hook</code>. See the module overview for more information.
  </p>
</div>

</section>
<ul class="ddoc_members">
  <li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.hook" id="Decimal.hook"><code class="code">hook</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.hook"></span>Hook <code class="code">hook</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    <code class="code"><code class="code">hook</code></code> is a member variable if it has state, or an alias for <code class="code">Hook</code>
 otherwise.
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.clamped" id="Decimal.clamped"><code class="code">clamped</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.clamped"></span>bool <code class="code">clamped</code>;
<br>
<span class="ddoc_anchor" id="Decimal.divisionByZero"></span>bool <code class="code">divisionByZero</code>;
<br>
<span class="ddoc_anchor" id="Decimal.inexact"></span>bool <code class="code">inexact</code>;
<br>
<span class="ddoc_anchor" id="Decimal.invalidOperation"></span>bool <code class="code">invalidOperation</code>;
<br>
<span class="ddoc_anchor" id="Decimal.overflow"></span>bool <code class="code">overflow</code>;
<br>
<span class="ddoc_anchor" id="Decimal.rounded"></span>bool <code class="code">rounded</code>;
<br>
<span class="ddoc_anchor" id="Decimal.subnormal"></span>bool <code class="code">subnormal</code>;
<br>
<span class="ddoc_anchor" id="Decimal.underflow"></span>bool <code class="code">underflow</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Public flags
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.this" id="Decimal.this"><code class="code">this</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.this"></span>pure this(T)(const T <code class="code">num</code>) if (isNumeric!T);

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Constructs an exact decimal type from a built in number

  </p>
</div>
<div class="ddoc_params">
  <h4>Parameters</h4>
  <table cellspacing="0" cellpadding="5" border="0" class="graybox">
    <tbody>
      <tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">T <code class="code">num</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      the number to convert to exact decimal
    </p>
  </div>
</td>
</tr>

    </tbody>
  </table>
</div>
<div class="ddoc_section">
  <p class="para">
    <span class="ddoc_section_h">Note:</span>
Using <code class="code">float</code> types for construction is less accurate than using a string
     representation due to floating point inaccuracy. If possible, it's always
     better to use string construction.
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.this" id="Decimal.this"><code class="code">this</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.this.2"></span>this(S)(S <code class="code">str</code>) if (isForwardRange!S &amp;&amp; isSomeChar!(ElementEncodingType!S) &amp;&amp; !isInfinite!S &amp;&amp; !isSomeString!S);
<br>
pure this(S)(S <code class="code">str</code>) if (isSomeString!S);

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Converts a string representing a number to an exact decimal.

  </p>
</div>
<div class="ddoc_description">
  <h4>Discussion</h4>
  <p class="para">
    If the string does not represent a number, then the result is <code class="code">NaN</code>
 and <code class="code">invalidOperation</code> is <code class="code">true</code>.
<br><br>
 Implements spec <code class="code">to-number</code>.


  </p>
</div>
<div class="ddoc_params">
  <h4>Parameters</h4>
  <table cellspacing="0" cellpadding="5" border="0" class="graybox">
    <tbody>
      <tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">S <code class="code">str</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The string to convert from
    </p>
  </div>
</td>
</tr>

    </tbody>
  </table>
</div>
<div class="ddoc_section">
  <p class="para">
    <span class="ddoc_section_h">String Spec:</span>

<section class="code_listing">
  <div class="code_sample">
    <div class="dlang">
      <ol class="code_lines">
        <li><code class="code">sign           ::=  + | -
digit          ::=  0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
                    8 | 9
indicator      ::=  e | E
digits         ::=  digit [digit]...
decimal-part   ::=  digits . [digits] | [.] digits
exponent-part  ::=  indicator [sign] digits
infinity       ::=  Infinity | Inf
nan            ::=  NaN [digits]
numeric-value  ::=  decimal-part [exponent-part] | infinity
numeric-string ::=  [sign] numeric-value | [sign] nan
</code></li>
      </ol>
    </div>
  </div>
</section>


  </p>
</div>
<div class="ddoc_section">
  <p class="para">
    <span class="ddoc_section_h">Exceptional Conditions:</span>
invalidOperation is flagged when <code class="code"><code class="code">str</code></code> is not a valid string
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.opBinary" id="Decimal.opBinary"><code class="code">opBinary</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.opBinary"></span>const auto <code class="code">opBinary</code>(string op, T)(T <code class="code">rhs</code>) if (op == "+" || op == "-" || op == "*" || op == "/");
<br>
<span class="ddoc_anchor" id="Decimal.opOpAssign"></span>ref Decimal!Hook <code class="code">opOpAssign</code>(string op, T)(auto ref const T <code class="code">rhs</code>) if (op == "+" || op == "-" || op == "*" || op == "/");

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Performs a binary operation between two decimals, or a decimal and
 a built in number.

  </p>
</div>
<div class="ddoc_description">
  <h4>Discussion</h4>
  <p class="para">
    The result has the hook of the left hand side. On non-assignment
 operations invalid operations do not effect the left hand side of
 the operation.
<br><br>
 When the right hand side is a built-in numeric type, the default
 hook <code class="code">Abort</code> is used for its decimal representation.


  </p>
</div>
<div class="ddoc_params">
  <h4>Parameters</h4>
  <table cellspacing="0" cellpadding="5" border="0" class="graybox">
    <tbody>
      <tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">T <code class="code">rhs</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      the right-hand side of the operation
    </p>
  </div>
</td>
</tr>

    </tbody>
  </table>
</div>
<div class="ddoc_section">
  <p class="para">
    <span class="ddoc_section_h">Exceptional Conditions:</span>
<code class="code">invalidOperation</code> is flagged under the following conditions
     <ul>         <li>Adding Infinity and -Infinity, and vice-versa</li>
         <li>Multiplying +/-Infinity by +/-zero</li>
         <li>Dividing anything but zero by zero</li>
         <li>Dividing +/-Infinity by +/-Infinity</li>
     </ul>
     <code class="code">divisionByZero</code> is flagged when dividing anything but zero by zero
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.opCmp" id="Decimal.opCmp"><code class="code">opCmp</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.opCmp"></span>const int <code class="code">opCmp</code>(T)(T <code class="code">d</code>) if (isNumeric!T || is(Unqual!T == Decimal));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    <code class="code">-Infinity</code> is less than all numbers, <code class="code">-NaN</code> is greater than <code class="code">-Infinity</code> but
 less than all other numbers, <code class="code">NaN</code> is greater than <code class="code">-NaN</code> but less than all other
 numbers and <code class="code">Infinity</code> is greater than all numbers. <code class="code">-NaN</code> and <code class="code">NaN</code> are equal to
 themselves.

  </p>
</div>
<div class="ddoc_params">
  <h4>Parameters</h4>
  <table cellspacing="0" cellpadding="5" border="0" class="graybox">
    <tbody>
      <tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">T <code class="code">d</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      the decimal or built-in number to compare to
    </p>
  </div>
</td>
</tr>

    </tbody>
  </table>
</div>
<div class="ddoc_returns">
  <h4>Return Value</h4>
  <p class="para">
    Barring special values, <code class="code">0</code> if subtracting the two numbers yields
     <code class="code">0</code>, <code class="code">-1</code> if the result is less than <code class="code">0</code>, and <code class="code">1</code> if the result is
     greater than zero
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.opEquals" id="Decimal.opEquals"><code class="code">opEquals</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.opEquals"></span>const bool <code class="code">opEquals</code>(T)(T <code class="code">d</code>) if (isNumeric!T || is(Unqual!T == Decimal));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_returns">
  <h4>Return Value</h4>
  <p class="para">
    <code class="code">true</code> if <code class="code">opCmp</code> would return <code class="code">0</code>
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.resetFlags" id="Decimal.resetFlags"><code class="code">resetFlags</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.resetFlags"></span>pure nothrow @nogc @safe void <code class="code">resetFlags</code>();

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Convenience function to reset all exceptional condition flags to <code class="code">false</code> at once
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.dup" id="Decimal.dup"><code class="code">dup</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.dup"></span>const Decimal!Hook <code class="code">dup</code>()();

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_returns">
  <h4>Return Value</h4>
  <p class="para">
    A mutable copy of this <code class="code">Decimal</code>. Also copies current flags.
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.idup" id="Decimal.idup"><code class="code">idup</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.idup"></span>const immutable(Decimal!Hook) <code class="code">idup</code>()();

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_returns">
  <h4>Return Value</h4>
  <p class="para">
    An immutable copy of this <code class="code">Decimal</code>. Also copies current flags.
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.isNaN" id="Decimal.isNaN"><code class="code">isNaN</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.isNaN"></span>const pure nothrow @nogc @property @safe bool <code class="code">isNaN</code>();

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_returns">
  <h4>Return Value</h4>
  <p class="para">
    If this decimal represents a positive or negative NaN
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.isInfinity" id="Decimal.isInfinity"><code class="code">isInfinity</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.isInfinity"></span>const pure nothrow @nogc @property @safe bool <code class="code">isInfinity</code>();

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_returns">
  <h4>Return Value</h4>
  <p class="para">
    If this decimal represents positive or negative infinity
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.nan" id="Decimal.nan"><code class="code">nan</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.nan"></span>@property Decimal!Hook <code class="code">nan</code>()();

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_returns">
  <h4>Return Value</h4>
  <p class="para">
    A decimal representing a positive NaN
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.infinity" id="Decimal.infinity"><code class="code">infinity</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.infinity"></span>@property Decimal!Hook <code class="code">infinity</code>()();

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_returns">
  <h4>Return Value</h4>
  <p class="para">
    A decimal representing positive Infinity
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.toString" id="Decimal.toString"><code class="code">toString</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.toString"></span>alias <code class="code">toString</code> = toDecimalString;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Decimal.toDecimalString" id="Decimal.toDecimalString"><code class="code">toDecimalString</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Decimal.toDecimalString"></span>const auto <code class="code">toDecimalString</code>();
<br>
const void <code class="code">toDecimalString</code>(Writer)(auto ref Writer <code class="code">w</code>) if (isOutputRange!(Writer, char));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_returns">
  <h4>Return Value</h4>
  <p class="para">
    Returns the decimal string representation of this decimal.
  </p>
</div>

</section>

</div>

</li>
</ul>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#decimal" id="decimal"><code class="code">decimal</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="decimal"></span>auto <code class="code">decimal</code>(Hook = Abort, R)(R <code class="code">r</code>) if (isForwardRange!R &amp;&amp; isSomeChar!(ElementEncodingType!R) &amp;&amp; !isInfinite!R || isNumeric!R);

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Factory function
  </p>
</div>
<div class="ddoc_examples">
  <h4>Examples</h4>
  <p class="para">
    
<section class="code_listing">
  <div class="code_sample">
    <div class="dlang">
      <ol class="code_lines">
        <li><code class="code"><span class="keyword">auto</span> d1 = <span class="psymbol">decimal</span>(5.5);
<span class="keyword">assert</span>(d1.toString == <span class="string_literal">"5.5"</span>);

<span class="keyword">auto</span> d2 = <span class="psymbol">decimal</span>(<span class="string_literal">"500.555"</span>);
</code></li>
      </ol>
    </div>
  </div>
</section>

  </p>
</div>
</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Rounding" id="Rounding"><code class="code">Rounding</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Rounding"></span>enum <code class="code">Rounding</code>: int;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Controls what happens when the number of significant digits exceeds <code class="code">Hook.precision</code>
  </p>
</div>

</section>
<ul class="ddoc_members">
  <li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Rounding.Down" id="Rounding.Down"><code class="code">Down</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Rounding.Down"></span><code class="code">Down</code>
          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Round toward 0, a.k.a truncate. The discarded digits are ignored.
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Rounding.HalfUp" id="Rounding.HalfUp"><code class="code">HalfUp</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Rounding.HalfUp"></span><code class="code">HalfUp</code>
          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    If the discarded digits represent greater than or equal to half (0.5)
 of the value of a one in the next left position then the result coefficient
 should be incremented by 1 (rounded up). Otherwise the discarded digits are ignored.
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Rounding.HalfEven" id="Rounding.HalfEven"><code class="code">HalfEven</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Rounding.HalfEven"></span><code class="code">HalfEven</code>
          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    If the discarded digits represent greater than half (0.5) the value of a
 one in the next left position then the result coefficient should be
 incremented by 1 (rounded up). If they represent less than half, then the
 result coefficient is not adjusted (that is, the discarded digits are ignored).

  </p>
</div>
<div class="ddoc_description">
  <h4>Discussion</h4>
  <p class="para">
    Otherwise (they represent exactly half) the result coefficient is unaltered
 if its rightmost digit is even, or incremented by 1 (rounded up) if its
 rightmost digit is odd (to make an even digit).
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Rounding.Ceiling" id="Rounding.Ceiling"><code class="code">Ceiling</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Rounding.Ceiling"></span><code class="code">Ceiling</code>
          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    If all of the discarded digits are zero or if the sign is 1 the result is
 unchanged. Otherwise, the result coefficient should be incremented by 1
 (rounded up).
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Rounding.Floor" id="Rounding.Floor"><code class="code">Floor</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Rounding.Floor"></span><code class="code">Floor</code>
          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    If all of the discarded digits are zero or if the sign is 0 the result is
 unchanged. Otherwise, the sign is 1 and the result coefficient should be
 incremented by 1.
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Rounding.HalfDown" id="Rounding.HalfDown"><code class="code">HalfDown</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Rounding.HalfDown"></span><code class="code">HalfDown</code>
          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    If the discarded digits represent greater than half (0.5) of the value of
 a one in the next left position then the result coefficient should be
 incremented by 1 (rounded up). Otherwise (the discarded digits are 0.5 or
 less) the discarded digits are ignored.
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Rounding.Up" id="Rounding.Up"><code class="code">Up</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Rounding.Up"></span><code class="code">Up</code>
          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    (Round away from 0.) If all of the discarded digits are zero the result is
 unchanged. Otherwise, the result coefficient should be incremented by 1 (rounded up).
  </p>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Rounding.ZeroFiveUp" id="Rounding.ZeroFiveUp"><code class="code">ZeroFiveUp</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Rounding.ZeroFiveUp"></span><code class="code">ZeroFiveUp</code>
          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    (Round zero or five away from 0.) The same as round-up, except that rounding
 up only occurs if the digit to be rounded up is 0 or 5, and after overflow
 the result is the same as for round-down.
  </p>
</div>

</section>

</div>

</li>
</ul>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Abort" id="Abort"><code class="code">Abort</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Abort"></span>struct <code class="code">Abort</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Will halt program on division by zero, invalid operations,
 overflows, and underflows.

  </p>
</div>
<div class="ddoc_description">
  <h4>Discussion</h4>
  <p class="para">
    Has 9 significant digits, rounds half up
  </p>
</div>

</section>
<ul class="ddoc_members">
  <li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Abort.roundingMode" id="Abort.roundingMode"><code class="code">roundingMode</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Abort.roundingMode"></span>enum Rounding <code class="code">roundingMode</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Abort.precision" id="Abort.precision"><code class="code">precision</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Abort.precision"></span>enum uint <code class="code">precision</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    A <code class="code">precision</code> of 9 allows all possible the results of +,-,*, and /
 to fit into a <code class="code">ulong</code> with no issues.
  </p>
</div>
</section>
</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Abort.onDivisionByZero" id="Abort.onDivisionByZero"><code class="code">onDivisionByZero</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Abort.onDivisionByZero"></span>void <code class="code">onDivisionByZero</code>(T)(T <code class="code">d</code>) if (isInstanceOf!(Decimal, T));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Abort.onInvalidOperation" id="Abort.onInvalidOperation"><code class="code">onInvalidOperation</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Abort.onInvalidOperation"></span>void <code class="code">onInvalidOperation</code>(T)(T <code class="code">d</code>) if (isInstanceOf!(Decimal, T));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Abort.onOverflow" id="Abort.onOverflow"><code class="code">onOverflow</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Abort.onOverflow"></span>void <code class="code">onOverflow</code>(T)(T <code class="code">d</code>) if (isInstanceOf!(Decimal, T));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Abort.onUnderflow" id="Abort.onUnderflow"><code class="code">onUnderflow</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Abort.onUnderflow"></span>void <code class="code">onUnderflow</code>(T)(T <code class="code">d</code>) if (isInstanceOf!(Decimal, T));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li>
</ul>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#HighPrecision" id="HighPrecision"><code class="code">HighPrecision</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="HighPrecision"></span>struct <code class="code">HighPrecision</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Same as abort, but offers 64 significant digits

  </p>
</div>
<div class="ddoc_section">
  <p class="para">
    <span class="ddoc_section_h">Note:</span>
As noted in the module overview, using 64 significant digits is much
 slower than <code class="code">9</code> or <code class="code">19</code>.
  </p>
</div>

</section>
<ul class="ddoc_members">
  <li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#HighPrecision.roundingMode" id="HighPrecision.roundingMode"><code class="code">roundingMode</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="HighPrecision.roundingMode"></span>enum Rounding <code class="code">roundingMode</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#HighPrecision.precision" id="HighPrecision.precision"><code class="code">precision</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="HighPrecision.precision"></span>enum uint <code class="code">precision</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#HighPrecision.onDivisionByZero" id="HighPrecision.onDivisionByZero"><code class="code">onDivisionByZero</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="HighPrecision.onDivisionByZero"></span>void <code class="code">onDivisionByZero</code>(T)(T <code class="code">d</code>) if (isInstanceOf!(Decimal, T));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#HighPrecision.onInvalidOperation" id="HighPrecision.onInvalidOperation"><code class="code">onInvalidOperation</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="HighPrecision.onInvalidOperation"></span>void <code class="code">onInvalidOperation</code>(T)(T <code class="code">d</code>) if (isInstanceOf!(Decimal, T));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#HighPrecision.onOverflow" id="HighPrecision.onOverflow"><code class="code">onOverflow</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="HighPrecision.onOverflow"></span>void <code class="code">onOverflow</code>(T)(T <code class="code">d</code>) if (isInstanceOf!(Decimal, T));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#HighPrecision.onUnderflow" id="HighPrecision.onUnderflow"><code class="code">onUnderflow</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="HighPrecision.onUnderflow"></span>void <code class="code">onUnderflow</code>(T)(T <code class="code">d</code>) if (isInstanceOf!(Decimal, T));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li>
</ul>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Throw" id="Throw"><code class="code">Throw</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Throw"></span>struct <code class="code">Throw</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Will throw exceptions on division by zero, invalid operations,
 overflows, and underflows

  </p>
</div>
<div class="ddoc_description">
  <h4>Discussion</h4>
  <p class="para">
    Has 9 significant digits, rounds half up
  </p>
</div>

</section>
<ul class="ddoc_members">
  <li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Throw.roundingMode" id="Throw.roundingMode"><code class="code">roundingMode</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Throw.roundingMode"></span>enum Rounding <code class="code">roundingMode</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Throw.precision" id="Throw.precision"><code class="code">precision</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Throw.precision"></span>enum uint <code class="code">precision</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Throw.onDivisionByZero" id="Throw.onDivisionByZero"><code class="code">onDivisionByZero</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Throw.onDivisionByZero"></span>void <code class="code">onDivisionByZero</code>(T)(T <code class="code">d</code>) if (isInstanceOf!(Decimal, T));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Throw.onInvalidOperation" id="Throw.onInvalidOperation"><code class="code">onInvalidOperation</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Throw.onInvalidOperation"></span>void <code class="code">onInvalidOperation</code>(T)(T <code class="code">d</code>) if (isInstanceOf!(Decimal, T));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Throw.onOverflow" id="Throw.onOverflow"><code class="code">onOverflow</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Throw.onOverflow"></span>void <code class="code">onOverflow</code>(T)(T <code class="code">d</code>) if (isInstanceOf!(Decimal, T));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Throw.onUnderflow" id="Throw.onUnderflow"><code class="code">onUnderflow</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Throw.onUnderflow"></span>void <code class="code">onUnderflow</code>(T)(T <code class="code">d</code>) if (isInstanceOf!(Decimal, T));

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li>
</ul>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#NoOp" id="NoOp"><code class="code">NoOp</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="NoOp"></span>struct <code class="code">NoOp</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Does nothing on invalid operations except the proper flags

  </p>
</div>
<div class="ddoc_description">
  <h4>Discussion</h4>
  <p class="para">
    Has 9 significant digits, rounds half up
  </p>
</div>

</section>
<ul class="ddoc_members">
  <li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#NoOp.roundingMode" id="NoOp.roundingMode"><code class="code">roundingMode</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="NoOp.roundingMode"></span>enum Rounding <code class="code">roundingMode</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#NoOp.precision" id="NoOp.precision"><code class="code">precision</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="NoOp.precision"></span>enum uint <code class="code">precision</code>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  

</div>

</li>
</ul>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#DivisionByZero" id="DivisionByZero"><code class="code">DivisionByZero</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="DivisionByZero"></span>class <code class="code">DivisionByZero</code>: <span class="ddoc_psuper_symbol">object.Exception</span>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Thrown when using  and division by zero occurs
  </p>
</div>

</section>
<ul class="ddoc_members">
  <li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#DivisionByZero.this" id="DivisionByZero.this"><code class="code">this</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="DivisionByZero.this"></span>pure nothrow @nogc @safe this(string <code class="code">msg</code>, string <code class="code">file</code> = __FILE__, size_t <code class="code">line</code> = __LINE__, Throwable <code class="code">next</code> = null);

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_params">
  <h4>Parameters</h4>
  <table cellspacing="0" cellpadding="5" border="0" class="graybox">
    <tbody>
      <tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">msg</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The message for the exception.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">file</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">file</code> where the exception occurred.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">size_t <code class="code">line</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">line</code> number where the exception occurred.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">Throwable <code class="code">next</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The previous exception in the chain of exceptions, if any.
    </p>
  </div>
</td>
</tr>

    </tbody>
  </table>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#DivisionByZero.this" id="DivisionByZero.this"><code class="code">this</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="DivisionByZero.this.2"></span>pure nothrow @nogc @safe this(string <code class="code">msg</code>, Throwable <code class="code">next</code>, string <code class="code">file</code> = __FILE__, size_t <code class="code">line</code> = __LINE__);

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_params">
  <h4>Parameters</h4>
  <table cellspacing="0" cellpadding="5" border="0" class="graybox">
    <tbody>
      <tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">msg</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The message for the exception.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">Throwable <code class="code">next</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The previous exception in the chain of exceptions.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">file</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">file</code> where the exception occurred.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">size_t <code class="code">line</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">line</code> number where the exception occurred.
    </p>
  </div>
</td>
</tr>

    </tbody>
  </table>
</div>

</section>

</div>

</li>
</ul>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#InvalidOperation" id="InvalidOperation"><code class="code">InvalidOperation</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="InvalidOperation"></span>class <code class="code">InvalidOperation</code>: <span class="ddoc_psuper_symbol">object.Exception</span>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Thrown when using  and an invalid operation occurs
  </p>
</div>

</section>
<ul class="ddoc_members">
  <li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#InvalidOperation.this" id="InvalidOperation.this"><code class="code">this</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="InvalidOperation.this"></span>pure nothrow @nogc @safe this(string <code class="code">msg</code>, string <code class="code">file</code> = __FILE__, size_t <code class="code">line</code> = __LINE__, Throwable <code class="code">next</code> = null);

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_params">
  <h4>Parameters</h4>
  <table cellspacing="0" cellpadding="5" border="0" class="graybox">
    <tbody>
      <tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">msg</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The message for the exception.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">file</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">file</code> where the exception occurred.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">size_t <code class="code">line</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">line</code> number where the exception occurred.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">Throwable <code class="code">next</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The previous exception in the chain of exceptions, if any.
    </p>
  </div>
</td>
</tr>

    </tbody>
  </table>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#InvalidOperation.this" id="InvalidOperation.this"><code class="code">this</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="InvalidOperation.this.2"></span>pure nothrow @nogc @safe this(string <code class="code">msg</code>, Throwable <code class="code">next</code>, string <code class="code">file</code> = __FILE__, size_t <code class="code">line</code> = __LINE__);

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_params">
  <h4>Parameters</h4>
  <table cellspacing="0" cellpadding="5" border="0" class="graybox">
    <tbody>
      <tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">msg</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The message for the exception.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">Throwable <code class="code">next</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The previous exception in the chain of exceptions.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">file</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">file</code> where the exception occurred.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">size_t <code class="code">line</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">line</code> number where the exception occurred.
    </p>
  </div>
</td>
</tr>

    </tbody>
  </table>
</div>

</section>

</div>

</li>
</ul>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Overflow" id="Overflow"><code class="code">Overflow</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Overflow"></span>class <code class="code">Overflow</code>: <span class="ddoc_psuper_symbol">object.Exception</span>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Thrown when using  and overflow occurs
  </p>
</div>

</section>
<ul class="ddoc_members">
  <li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Overflow.this" id="Overflow.this"><code class="code">this</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Overflow.this"></span>pure nothrow @nogc @safe this(string <code class="code">msg</code>, string <code class="code">file</code> = __FILE__, size_t <code class="code">line</code> = __LINE__, Throwable <code class="code">next</code> = null);

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_params">
  <h4>Parameters</h4>
  <table cellspacing="0" cellpadding="5" border="0" class="graybox">
    <tbody>
      <tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">msg</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The message for the exception.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">file</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">file</code> where the exception occurred.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">size_t <code class="code">line</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">line</code> number where the exception occurred.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">Throwable <code class="code">next</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The previous exception in the chain of exceptions, if any.
    </p>
  </div>
</td>
</tr>

    </tbody>
  </table>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Overflow.this" id="Overflow.this"><code class="code">this</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Overflow.this.2"></span>pure nothrow @nogc @safe this(string <code class="code">msg</code>, Throwable <code class="code">next</code>, string <code class="code">file</code> = __FILE__, size_t <code class="code">line</code> = __LINE__);

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_params">
  <h4>Parameters</h4>
  <table cellspacing="0" cellpadding="5" border="0" class="graybox">
    <tbody>
      <tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">msg</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The message for the exception.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">Throwable <code class="code">next</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The previous exception in the chain of exceptions.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">file</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">file</code> where the exception occurred.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">size_t <code class="code">line</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">line</code> number where the exception occurred.
    </p>
  </div>
</td>
</tr>

    </tbody>
  </table>
</div>

</section>

</div>

</li>
</ul>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Underflow" id="Underflow"><code class="code">Underflow</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Underflow"></span>class <code class="code">Underflow</code>: <span class="ddoc_psuper_symbol">object.Exception</span>;

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_summary">
  <p class="para">
    Thrown when using  and underflow occurs
  </p>
</div>

</section>
<ul class="ddoc_members">
  <li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Underflow.this" id="Underflow.this"><code class="code">this</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Underflow.this"></span>pure nothrow @nogc @safe this(string <code class="code">msg</code>, string <code class="code">file</code> = __FILE__, size_t <code class="code">line</code> = __LINE__, Throwable <code class="code">next</code> = null);

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_params">
  <h4>Parameters</h4>
  <table cellspacing="0" cellpadding="5" border="0" class="graybox">
    <tbody>
      <tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">msg</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The message for the exception.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">file</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">file</code> where the exception occurred.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">size_t <code class="code">line</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">line</code> number where the exception occurred.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">Throwable <code class="code">next</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The previous exception in the chain of exceptions, if any.
    </p>
  </div>
</td>
</tr>

    </tbody>
  </table>
</div>

</section>

</div>

</li><li class="ddoc_member">
  <div class="ddoc_member_header">
  <div class="ddoc_header_anchor">
  <a href="#Underflow.this" id="Underflow.this"><code class="code">this</code></a>
</div>
</div><div class="ddoc_decl">
  <section class="section">
    <div class="declaration">
      <h4>Declaration</h4>
      <div class="dlang">
        <p class="para">
          <code class="code">
            <span class="ddoc_anchor" id="Underflow.this.2"></span>pure nothrow @nogc @safe this(string <code class="code">msg</code>, Throwable <code class="code">next</code>, string <code class="code">file</code> = __FILE__, size_t <code class="code">line</code> = __LINE__);

          </code>
        </p>
      </div>
    </div>
  </section>
</div>
<div class="ddoc_decl">
  <section class="section ddoc_sections">
  <div class="ddoc_params">
  <h4>Parameters</h4>
  <table cellspacing="0" cellpadding="5" border="0" class="graybox">
    <tbody>
      <tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">msg</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The message for the exception.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">Throwable <code class="code">next</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The previous exception in the chain of exceptions.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">string <code class="code">file</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">file</code> where the exception occurred.
    </p>
  </div>
</td>
</tr>
<tr class="ddoc_param_row">
  <td scope="ddoc_param_id">
  <code class="code">
    <em class="term">size_t <code class="code">line</code></em>
  </code>
</td>
<td>
  <div class="ddoc_param_desc">
    <p class="para">
      The <code class="code">line</code> number where the exception occurred.
    </p>
  </div>
</td>
</tr>

    </tbody>
  </table>
</div>

</section>

</div>

</li>
</ul>

</div>

</li>
</ul>
  </div>
</section>
</section>