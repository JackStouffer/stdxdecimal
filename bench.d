import std.stdio;
import std.algorithm;
import std.random;
import std.math;
import std.conv;
import std.datetime;
import stdxdecimal;
import std.bigint;

void main()
{
    auto t1 = real(1000000.0);
    auto t2 = real(5000000.0);
    auto t3 = BigInt(1000000);
    auto t4 = BigInt(5000000);
    auto t5 = decimal(1000000);
    auto t6 = decimal(5000000);
    auto t7 = decimal!(HighPrecision)(1000000);
    auto t8 = decimal!(HighPrecision)(5000000);

    real rres;
    BigInt bres;
    Decimal!(Abort) dres;
    Decimal!(HighPrecision) hres;

    writeln("Addition (sum of 5M runs)");
    auto result1 = to!Duration(benchmark!(() => rres = t1 + t2)(5_000_000)[0]);
    auto result2 = to!Duration(benchmark!(() => bres = t3 + t4)(5_000_000)[0]);
    auto result3 = to!Duration(benchmark!(() => dres = t5 + t6)(5_000_000)[0]);
    auto result4 = to!Duration(benchmark!(() => hres = t7 + t8)(5_000_000)[0]);

    writeln("Baseline:", "\t", result1);
    writeln("BigInt:", "\t\t", result2);
    writeln("Decimal:", "\t", result3);
    writeln("HighPrecision:", "\t", result4, "\n");

    writeln("Subtraction (sum of 5M runs)");
    result1 = to!Duration(benchmark!(() => rres = t1 - t2)(5_000_000)[0]);
    result2 = to!Duration(benchmark!(() => bres = t3 - t4)(5_000_000)[0]);
    result3 = to!Duration(benchmark!(() => dres = t5 - t6)(5_000_000)[0]);
    result4 = to!Duration(benchmark!(() => hres = t7 - t8)(5_000_000)[0]);

    writeln("Baseline:", "\t", result1);
    writeln("BigInt:", "\t\t", result2);
    writeln("Decimal:", "\t", result3);
    writeln("HighPrecision:", "\t", result4, "\n");

    real[] arr1;
    BigInt[] arr2;
    Decimal!(Abort)[] arr3;
    Decimal!(HighPrecision)[] arr4;

    foreach (_; 0 .. 1_000_000)
    {
        arr1 ~= uniform(-10_000, 10_000);
    }
    foreach (_; 0 .. 1_000_000)
    {
        arr2 ~= BigInt(uniform(-10_000, 10_000));
    }
    foreach (_; 0 .. 1_000_000)
    {
        arr3 ~= decimal(uniform(-10_000.0, 10_000.0));
    }
    foreach (_; 0 .. 1_000_000)
    {
        arr4 ~= decimal!(HighPrecision)(uniform(-10_000.0, 10_000.0));
    }

    writeln("Sorting");
    result1 = to!Duration(benchmark!(() => sort(arr1))(1)[0]);
    result2 = to!Duration(benchmark!(() => sort(arr2))(1)[0]);
    result3 = to!Duration(benchmark!(() => sort(arr3))(1)[0]);
    result4 = to!Duration(benchmark!(() => sort(arr4))(1)[0]);

    writeln("Baseline:", "\t", result1);
    writeln("BigInt:", "\t\t", result2);
    writeln("Decimal:", "\t", result3);
    writeln("HighPrecision:", "\t", result4);
}