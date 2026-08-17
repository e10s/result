import yares;
import std.conv : ConvException, to;
import std.format : format;
import std.stdio : stderr, writefln, writeln;
import std.sumtype : match;

// Parse text into a positive integer, returning a Result that captures either
// the parsed value or a user-friendly error message.
auto parsePositiveInt(string text)
{
    alias R = Result!(int, string);

    try
    {
        auto value = to!int(text);
        if (value <= 0)
        {
            return R.error("Value must be a positive integer");
        }
        return R.success(value);
    }
    catch (ConvException e)
    {
        return R.error("Invalid input: " ~ e.msg);
    }
}

// Perform division and return a Result that reports division-by-zero errors.
auto divide(int numerator, int denominator)
{
    alias R = Result!(double, string);

    if (denominator == 0)
    {
        return R.error("Division by zero");
    }
    return R.success(cast(double) numerator / denominator);
}

// Convert a lazy expression into a Result value by catching any thrown exception.
auto convertExceptionToResult(T)(lazy T expr)
{
    alias R = Result!(T, Exception);

    try
    {
        return R.success(expr);
    }
    catch (Exception e)
    {
        return R.error(e);
    }
}

// A simple demo showing success and failure handling in a procedural style.
void showBasicFlow()
{
    // Result!(int, string), success
    immutable parseResult = parsePositiveInt("42");

    if (isError(parseResult))
    {
        stderr.writeln("Error: ", unwrapError(parseResult));
        return;
    }

    // Result!(double, string), success
    immutable divideResult = divide(unwrap(parseResult), 7);

    if (isError(divideResult))
    {
        stderr.writeln("Error: ", unwrapError(divideResult));
        return;
    }

    immutable formattedString = format!"%.2f"(unwrap(divideResult));
    writeln("Success: ", formattedString);
}

// A composition example that demonstrates chaining and explicit branching.
void showCompositionExample()
{
    //    Result!(int, string), failure
    // -> Result!(double, string), failure
    // -> Result!(string, string), failure
    // -> SumType!(string, ErrorValue!string), containing ErrorValue!string
    parsePositiveInt("0").andThen!(value => divide(value, 3))
        .map!(d => format!"%.2f"(d))
        .payload // Explicit conversion to SumType
        .match!((string okValue) => writeln("Success: ", okValue),
                (ErrorValue!string errObj) => stderr.writeln("Failure: ", errObj.error));
}

// A demo that converts a thrown exception into a Result and handles it.
void showExceptionInterop()
{
    //    Result!(int, Exception), failure
    // -> Result!(double, Exception), failure
    immutable result = convertExceptionToResult(to!int("not an int")).map!(value => value * 2.0);

    assert(is(typeof(result) == immutable(Result!(double, Exception))));

    // Implicit conversion to SumType
    result.match!((double okValue) => writefln("Converted value: %.2f", okValue),
            (const ErrorValue!Exception errObj) => stderr.writeln("Caught exception: ",
                errObj.error.msg));
}

void main()
{
    writeln("=== yares demo ===");
    writeln();

    showBasicFlow(); // Success: ...
    showCompositionExample(); // Failure: ...
    showExceptionInterop(); // Caught exception: ...
}
