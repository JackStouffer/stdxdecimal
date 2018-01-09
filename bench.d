import std.stdio;
import std.algorithm;
import std.range;
import std.random;
import std.math;
import std.conv;
import std.datetime;
import stdxdecimal;
import std.bigint;

struct HigherHook
{
    enum uint precision = 19;
    enum Rounding roundingMode = Rounding.HalfUp;
}

void main()
{
    auto t1 = BigInt(1000000);
    auto t2 = BigInt(5000000);
    auto t3 = decimal(10000.12);
    auto t4 = decimal(50);
    auto t5 = decimal!(HighPrecision)(10000000.12);
    auto t6 = decimal!(HighPrecision)(5000000000000);

    real rres;
    BigInt bres;
    Decimal!(Abort) dres;
    Decimal!(HighPrecision) hres;

    writeln("Addition (sum of 5M runs)");
    auto result1 = to!Duration(benchmark!(() => bres = t1 + t2)(5_000_000)[0]);
    auto result2 = to!Duration(benchmark!(() => dres = t3 + t4)(5_000_000)[0]);
    auto result3 = to!Duration(benchmark!(() => hres = t5 + t6)(5_000_000)[0]);

    writeln("BigInt:", "\t\t", result1);
    writeln("Decimal(16):", "\t", result2);
    writeln("Decimal(64):", "\t", result3, "\n");

    writeln("Subtraction (sum of 5M runs)");
    result1 = to!Duration(benchmark!(() => bres = t1 - t2)(5_000_000)[0]);
    result2 = to!Duration(benchmark!(() => dres = t3 - t4)(5_000_000)[0]);
    result3 = to!Duration(benchmark!(() => hres = t5 - t6)(5_000_000)[0]);

    writeln("BigInt:", "\t\t", result1);
    writeln("Decimal(16):", "\t", result2);
    writeln("Decimal(64):", "\t", result3, "\n");

    writeln("Multiplication (sum of 1M runs)");
    result1 = to!Duration(benchmark!(() => bres = t1 * t2)(1_000_000)[0]);
    result2 = to!Duration(benchmark!(() => dres = t3 * t4)(1_000_000)[0]);
    result3 = to!Duration(benchmark!(() => hres = t5 * t6)(1_000_000)[0]);

    writeln("BigInt:", "\t\t", result1);
    writeln("Decimal(16):", "\t", result2);
    writeln("Decimal(64):", "\t", result3, "\n");

    writeln("Division (sum of 1M runs)");
    result1 = to!Duration(benchmark!(() => bres = t1 / t2)(1_000_000)[0]);
    result2 = to!Duration(benchmark!(() => dres = t3 / t4)(1_000_000)[0]);
    result3 = to!Duration(benchmark!(() => hres = t5 / t6)(1_000_000)[0]);

    writeln("BigInt:", "\t\t", result1);
    writeln("Decimal(16):", "\t", result2);
    writeln("Decimal(64):", "\t", result3, "\n");
}