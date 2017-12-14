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
Equals | ✓
Compare | ✓
Addition | ✓
Subtraction | ✓
Multiply | ✓
Divide | ✓
opOpAssign +,-,*,/,^^ | ❌
Unary Plus/Minus/Increment/Decrement | ❌
Cast Int/Float/Bool | ❌
abs | ❌
ln | ❌
log10 | ❌
exp | ❌
sqrt | ❌
power | ❌
reduce | ❌

## Current Performance

Run on a 15", 2015 Macbook Pro

Test | `real` | `BigInt` | `Decimal` (Precision 9) | `Decimal` (Precision 64) | Python `Decimal` | Python `Decimal` (64 Digits)
------------ | ------------- | ------------- | ------------- | ------------- |
Addition (Sum 5M Runs) | 18 ms, 719 μs, and 9 hnsecs | 722 ms, 669 μs, and 9 hnsecs | 317 ms, 736 μs, and 8 hnsecs | 4 secs, 265 ms, and 9 hnsecs | 799 ms | 741 ms
Subtraction (Sum 5M Runs) | 24 ms and 477 μs | 737 ms, 56 μs, and 7 hnsecs | 310 ms, 811 μs, and 7 hnsecs | 4 secs, 275 ms, 391 μs, and 8 hnsecs | 800 ms | 830 ms
Multiplication (sum of 5M runs) | 18 ms, 397 μs, and 1 hnsec | 1 sec, 363 ms, and 219 μs | 477 ms, 119 μs, and 6 hnsecs | 7 secs, 39 ms, 998 μs, and 3 hnsecs | 695 ms | 1 sec 541 ms
Division (sum of 1M runs) | 4 ms, 278 μs, and 6 hnsecs | 262 ms, 27 μs, and 6 hnsecs | 55 ms, 44 μs, and 9 hnsecs | 16 secs, 556 ms, 133 μs, and 4 hnsecs | 215 ms | 416 ms
Sorting 1M Uniformly Random Numbers | 177 ms, 537 μs, and 9 hnsecs | 846 ms, 834 μs, and 4 hnsecs | 604 ms, 684 μs, and 4 hnsecs | 8 secs, 116 ms, 285 μs, and 4 hnsecs | 1 sec 536 ms | 1 sec 228 ms

### Run It Yourself

D: `dmd -O -release -inline bench.d source/stdxdecimal/package.d && ./bench`

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
