# Decimal Type for Phobos

This code is a work in progress for a new type `Decimal` that follows the
"General Decimal Arithmetic Specification" http://speleotrove.com/decimal/decarith.html

## Current Features

Feature | Implemented
------------ | -------------
Construction from strings/string-like ranges | ✓
Construction from number types | ✓
To decimal string | ✓
To scientific string | ❌
To engineering string | ❌
All rounding types | ❌
Equals | ❌
Compare | ❌
Addition/Subtraction | ❌
Multiply | ❌
Divide | ❌
abs | ❌
ln | ❌
log10 | ❌
exp | ❌
sqrt | ❌
power | ❌
reduce | ❌

## Example

```d
import stdxdecimal;

void main()
{
    auto d1 = decimal("1.23");
    auto d2 = decimal("1.23E-4");
    auto d3 = decimal("1.23E4");

    assert(d1.toString() == "1.23");
    assert(d2.toString() == "0.000123");
    assert(d3.toString() == "12300");
}
```