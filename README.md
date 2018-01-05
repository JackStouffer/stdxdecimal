# Decimal Type for Phobos

This code is a work in progress for a new type `Decimal` that follows the
"General Decimal Arithmetic Specification" http://speleotrove.com/decimal/decarith.html

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

    auto d4 = d1 + d2;
    assert(d4.toString() == "1.230123");

    auto d5 = d3 - d1;
    assert(d5.toString() == "12298.87");

    auto d6 = decimal!(HighPrecision)("1.000000000000000000000000000000000000000000000000001");
    auto d7 = decimal!(HighPrecision)("1E-51");
    auto d8 = d6 + d7;
    assert(d8.toString() == "1.000000000000000000000000000000000000000000000000002");
}
```

## Current Features

Feature | Implemented
------------ | -------------
Construction from strings/string-like ranges | ✓
Construction from number types | ✓
To decimal string | ✓
To scientific string | ❌
To engineering string | ❌
All rounding types | ❌
Overflow/Underflow Behavior | ❌
Subnormal Behavior | ❌
Clamping Behavior | ❌
Equals | ✓
toHash | ❌
Compare | ✓
Addition | ✓
Subtraction | ✓
Multiply | ✓
Divide | ✓
Divide-Integer | ❌
Modulo | ❌
DivMod | ❌
opOpAssign `+`,`-`,`*`,`/`,`^^` | ❌
Unary `+`,`-`,`++`,`--` | ✓
opCast `int`,`real`,`bool` | ❌
abs | ✓
ln | ❌
log10 | ❌
exp | ❌
sqrt | ❌
power | ❌
reduce | ❌

## Current Performance

Run on a 15", 2015 Macbook Pro, (rounded to the nearest ms; test values purposely avoid rounding, which is the slowest part by far)

Test | `BigInt` | `Decimal` (P = 9) | `Decimal` (P = 64) | Python `Decimal` | Python `Decimal` (64 Digits)
------------ | ------------- | ------------- | ------------- | ------------- | ------------- |
Addition (n = 5M) | 594 ms | 3,383 ms | 6,414 ms | 799 ms | 741 ms
Subtraction (n = 5M) | 494 ms | 3,092 ms | 6,028 ms | 800 ms | 830 ms
Multiplication (n = 5M) | 156 ms | 448 ms | 1,797 ms | 695 ms | 1541 ms
Division (n = 1M) | 207 ms | 5,261 ms | 18,283 ms | 215 ms | 416 ms
Sorting 1M Uniformly Random Numbers | 592 ms | 5,074 ms| 6,700 ms | 1,536 ms | 1,228 ms

### Run It Yourself

D: `ldc2 -O -release bench.d source/stdxdecimal/package.d && ./bench`

Python:

```python
import timeit

timeit.timeit("c = a + b", setup="from decimal import Decimal; a = Decimal(10000.12); b = Decimal(5000000); c = None", number=5000000)
timeit.timeit("c = a + b", setup="from decimal import Decimal; a = Decimal(1000000000000000000000000000000000000000000000000000000000000000); b = Decimal(5000000000000000000000000000000000000000000000000000000000000000); c = None", number=5000000)
timeit.timeit("c = a - b", setup="from decimal import Decimal; a = Decimal(10000.12); b = Decimal(5000000); c = None", number=5000000)
timeit.timeit("c = a - b", setup="from decimal import Decimal; a = Decimal('10000000000000000000000000000000000000000000000000000000000000.12'); b = Decimal('5000000000000000000000000000000000000000000000000000000000000000'); c = None", number=5000000)
timeit.timeit("c = a * b", setup="from decimal import Decimal; a = Decimal(10000.12); b = Decimal(5000000); c = None", number=5000000)
timeit.timeit("c = a * b", setup="from decimal import Decimal; a = Decimal('10000000000000000000000000000000000000000000000000000000000000.12'); b = Decimal('5000000000000000000000000000000000000000000000000000000000000000'); c = None", number=5000000)
timeit.timeit("c = a / b", setup="from decimal import Decimal; a = Decimal(10000.12); b = Decimal(5000000); c = None", number=1000000)
timeit.timeit("c = a / b", setup="from decimal import Decimal; a = Decimal('10000000000000000000000000000000000000000000000000000000000000.12'); b = Decimal('5000000000000000000000000000000000000000000000000000000000000000'); c = None", number=1000000)
timeit.timeit("c = sorted(a)", setup="from decimal import Decimal;import random; a = [Decimal(random.randint(-10000000, 10000000) * random.random()) for x in range(1000000)]", number=1)
timeit.timeit("c = sorted(a)", setup="from decimal import Decimal;import random; a = [Decimal(random.randint(-100000000000000000000000000000000000000000000000000, 100000000000000000000000000000000000000000000000000) * random.random()) for x in range(1000000)]", number=1)
```
