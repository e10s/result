/**
 * This module provides `Result!(T, E)`, which imitates Rust's `Result<T, E>` type
 * and C++'s `expected<T, E>` type for returning, carrying and composing errors.
 *
 * `Result` represents the outcome of potentially unsuccessful computation
 * and contains either `T` for success or `E` for failure.
 * Each one is used to signify both the status and the value.
 */
module result;

///
unittest
{
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
        // -> SumType!(string, Err!string), containing Err!string
        parsePositiveInt("0").andThen!(value => divide(value, 3))
            .map!(d => format!"%.2f"(d))
            .payload // Explicit conversion to SumType
            .match!((string okValue) => writeln("Success: ", okValue),
                    (Err!string errObj) => stderr.writeln("Failure: ", errObj.error));
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
                (const Err!Exception errObj) => stderr.writeln("Caught exception: ",
                    errObj.error.msg));
    }

    showBasicFlow(); // Success: ...
    showCompositionExample(); // Failure: ...
    showExceptionInterop(); // Caught exception: ...
}

import std.functional : not;
import std.functional : unaryFun;
import std.typecons : Nullable;
import std.traits : CommonType, Unqual, isAssignable;

/// Wrapper struct representing an error result with a value of type `E`.
/// Serves as the error variant in a [Result] type.
struct Err(E) if (!is(E : void))
{
    ///
    E error;
    ///
    bool opEquals(scope const Err!E rhs) const
    {
        return error == rhs.error;
    }
    /// Ditto
    bool opEquals(scope const ref Err!E rhs) const
    {
        return error == rhs.error;
    }
    /// Ditto
    bool opEquals(scope const E rhs) const
    {
        return error == rhs;
    }
    /// Ditto
    bool opEquals(scope const ref E rhs) const
    {
        return error == rhs;
    }
    ///
    size_t toHash() const
    {
        return hashOf(error);
    }
}

///
unittest
{
    assert(Err!int(314) == Err!int(314));
    assert(Err!int(314).error == 314);
    assert(Err!int(314) == 314);
    assert(Err!string("Good day.") == "Good day.");

    class K
    {
    }

    assert(Err!K(new K) != Err!K(new K));
}

unittest
{
    auto err1 = Err!int(314);
    auto err2 = Err!int(314);
    auto err3 = Err!int(315);

    assert(err1 == err2);
    assert(err2 != err3);
    assert(err1.toHash() == err2.toHash());
    assert(err1.toHash() != err3.toHash());

    class K
    {
    }

    auto err4 = Err!K(new K);
    auto err5 = Err!K(new K);

    assert(err4 != err5);
    assert(err4.toHash() != err5.toHash());
}

/// Exception thrown when attempting to unwrap a [Result] with an invalid state.
/// Raised by [tryUnwrap] and [tryUnwrapError].
class UnwrapException : Exception
{
    ///
    pure @safe @nogc nothrow this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// A type that represents either a successful value `T` or an error `E`.
///
/// This struct wraps a `std.sumtype.SumType` or a `std.typecons.Nullable`, for non-`void` and `void` `T`, respectively,
/// to provide `Result` type similar to Rust's `Result` or C++'s `expected`.
/// It is designed to work together with additional helper functions to handle success and error cases.
///
/// The struct provides transparent access to more primitive operations by using `alias` to its internal
/// `SumType` or `Nullable` `payload`.
///
/// Params:
///     T = The type of the successful value, or `void` for just representing the successful state
///     E = The type of the error value
/// See_Also:
///     [std.sumtype](https://dlang.org/phobos/std_sumtype.html)
///     [std.typecons.Nullable](https://dlang.org/phobos/std_typecons.html#Nullable)
struct Result(T, E) if (!is(T : Err!X, X) && !is(E : void))
{
    static if (is(T : void))
    {
        ///
        alias PayloadType = Nullable!(Err!E);

        /// Creates a [Result]`!(T, E)` with the successful state.
        ///
        /// Returns: A new [Result]`!(T, E)` containing the successful state
        static Result!(T, E) success()
        {
            return Result!(T, E)();
        }

        version (D_Ddoc)
        {
            ///
            unittest
            {
                auto r = Result!(void, string).success();
                assert(is(typeof(r) == Result!(void, string)));
            }
        }
    }
    else
    {
        import std.sumtype : SumType;

        ///
        alias PayloadType = SumType!(T, Err!E);

        /// The constructor for `T`.
        this()(auto ref inout(T) value) inout
        {
            payload = value;
        }

        /// Assigns a `T` value into a [Result].
        void opAssign()(T value) if (isAssignable!T)
        {
            payload = value;
        }

        /// Creates a [Result]`!(T, E)` with a successful `T` _value.
        ///
        /// Params:
        ///     value = The success _value to wrap
        ///
        /// Returns: A new [Result]`!(T, E)` containing the `T` _value
        static auto success(inout(T) value)
        {
            static if (is(inout(T) == T))
            {
                alias R = Result!(T, E);
            }
            else
            {
                alias R = inout(Result!(T, E));
            }
            return R(value);
        }

        version (D_Ddoc)
        {
            ///
            unittest
            {
                auto r = Result!(int, string).success(100);
                assert(is(typeof(r) == Result!(int, string)));

                auto immutableR = Result!(int, string).success(immutable(int)(200));
                auto constR = Result!(int, string).success(const(int)(300));

                // The obtained Results are automatically qualified according to the arguments
                assert(is(typeof(immutableR) == immutable(Result!(int, string))));
                assert(is(typeof(constR) == const(Result!(int, string))));
            }
        }
    }

    PayloadType payload;
    /// The payload to switch states and contain values.
    alias payload this;

    /// The constructor for `Err!E`.
    this()(auto ref inout(Err!E) wrappedError) inout
    {
        payload = wrappedError;
    }

    /// Assigns an `Err!E` wrapping an `E` value into a [Result].
    void opAssign()(Err!E wrappedError) if (isAssignable!E)
    {
        payload = wrappedError;
    }

    /// Creates a [Result]`!(T, E)` with an _error `E` value.
    ///
    /// Params:
    ///     error = The _error value to wrap
    ///
    /// Returns: A new [Result]`!(T, E)` containing the `E` value
    static auto error(inout(E) error)
    {
        static if (is(inout(E) == E))
        {
            alias R = Result!(T, E);
            alias ErrE = Err!E;
        }
        else
        {
            alias R = inout(Result!(T, E));
            alias ErrE = inout(Err!E);
        }
        return R(ErrE(error));
    }

    version (D_Ddoc)
    {
        ///
        unittest
        {
            auto r1 = Result!(int, string).error("BAD");
            assert(is(typeof(r1) == Result!(int, string)));
            auto r2 = Result!(void, string).error("BAD");
            assert(is(typeof(r2) == Result!(void, string)));

            auto immutableR = Result!(int, string).error(cast(immutable) "Immutable BAD");
            auto constR = Result!(void, string).error(cast(const) "Const BAD");

            // The obtained Results are automatically qualified according to the arguments
            assert(is(typeof(immutableR) == immutable(Result!(int, string))));
            assert(is(typeof(constR) == const(Result!(void, string))));
        }
    }
}

/* Tests for non-void T begin */
// Factory method
@safe @nogc nothrow unittest
{
    alias R = Result!(int, string);
    import std.sumtype : get;

    auto resultOk = R.success(123);
    assert(resultOk.get!int == 123);

    const cResultOk = R.success(123);
    assert(cResultOk.get!(const(int)) == 123);

    immutable iResultOk = R.success(123);
    assert(iResultOk.get!(immutable(int)) == 123);

    auto resultErr = R.error("123");
    assert(resultErr.get!(Err!string) == Err!string("123"));

    const cResultErr = R.error("123");
    assert(cResultErr.get!(const(Err!string)) == Err!string("123"));

    immutable iResultErr = R.error("123");
    assert(iResultErr.get!(immutable(Err!string)) == Err!string("123"));
}

// Ditto
@safe nothrow unittest
{
    struct S
    {
    }

    alias R = Result!(Exception, S*);

    import std.sumtype : has;

    auto resultOk = R.success(new Exception(""));
    assert(resultOk.has!Exception);

    const cResultOk = R.success(new Exception(""));
    assert(cResultOk.has!(const(Exception)));

    immutable iResultOk = R.success(new Exception(""));
    assert(iResultOk.has!(immutable(Exception)));

    auto resultErr = R.error(new S);
    assert(resultErr.has!(Err!(S*)));

    const cResultErr = R.error(new S);
    assert(cResultErr.has!(const(Err!(S*))));

    immutable iResultErr = R.error(new S);
    assert(iResultErr.has!(immutable(Err!(S*))));
}

// Ditto
@safe nothrow unittest
{
    struct S
    {
    }

    alias T = const(Exception);
    alias E = immutable(S*);
    alias R = Result!(T, E);

    import std.sumtype : get, has;

    auto resultOk = R.success(new Exception(""));
    assert(resultOk.has!T);

    auto cResultOk = R.success(new const(Exception)(""));
    assert(cResultOk.has!(const(T)));

    auto iResultOk = R.success(new immutable(Exception)(""));
    assert(iResultOk.has!(immutable(T)));

    auto resultErr = R.error(new S);
    assert(resultErr.has!(Err!E));

    auto cResultErr = R.error(new const(S));
    assert(cResultErr.has!(Err!E));

    auto iResultErr = R.error(new immutable(S));
    assert(iResultErr.has!(Err!E));
}

// Assignment
@trusted @nogc nothrow unittest
{
    alias R = Result!(int, string);

    import std.sumtype : get;

    auto result1 = R.error("333");
    auto result2 = R.error("3");

    result2 = result1;
    assert(result2.get!(Err!string) == Err!string("333"));

    const result3 = R.success(100);
    result2 = result3;
    assert(result2.get!int == 100);

    immutable result4 = R.error("1000");
    result2 = result4;
    assert(result2.get!(Err!string) == Err!string("1000"));
}

// Ditto
@trusted unittest
{
    struct S
    {
    }

    alias R = Result!(Exception, S*);

    import std.sumtype : get;

    auto s1 = new S;
    auto s2 = new S;
    auto result1 = R.error(s1);
    auto result2 = R.error(s2);

    result2 = result1;
    assert(result2.get!(Err!(S*)) == Err!(S*)(s1));

    auto k1 = new Exception("!!!");
    auto result3 = R.success(k1);

    result2 = result3;
    assert(result2.get!Exception == k1);
}

// Ditto
@trusted @nogc nothrow unittest
{
    alias R = Result!(int, string);
    import std.sumtype : get;

    auto result = R.success(123);

    result = 456;
    assert(result.get!int == 456);

    result = Err!string("error");
    assert(result.get!(Err!string) == Err!string("error"));
}

// Ctor
@safe @nogc nothrow unittest
{
    alias R = Result!(int, string);

    import std.sumtype : get;

    auto result1 = R(123);
    assert(result1.get!int == 123);

    auto result2 = R(Err!string("error"));
    assert(result2.get!(Err!string) == Err!string("error"));

    const cResult1 = const(R)(456);
    assert(cResult1.get!(const(int)) == 456);

    const cResult2 = const(R)(Err!string("error"));
    assert(cResult2.get!(const(Err!string)) == Err!string("error"));

    immutable iResult1 = immutable(R)(456);
    assert(iResult1.get!(immutable(int)) == 456);

    immutable iResult2 = immutable(R)(Err!string("error"));
    assert(iResult2.get!(immutable(Err!string)) == Err!string("error"));
}

// Ditto
@safe @nogc nothrow unittest
{
    alias R = Result!(int, string);

    import std.sumtype : get;

    int v = 123;
    auto e = Err!string("error");

    auto result1 = R(v);
    assert(result1.get!int == 123);

    auto result2 = R(e);
    assert(result2.get!(Err!string) == Err!string("error"));

    const cResult1 = const(R)(v);
    assert(cResult1.get!(const(int)) == 123);

    const cResult2 = const(R)(e);
    assert(cResult2.get!(const(Err!string)) == Err!string("error"));

    immutable iResult1 = immutable(R)(v);
    assert(iResult1.get!(immutable(int)) == 123);

    immutable iResult2 = immutable(R)(e);
    assert(iResult2.get!(immutable(Err!string)) == Err!string("error"));
}

// Ditto
@safe nothrow unittest
{
    struct S
    {
    }

    alias R = Result!(Exception, S*);

    import std.sumtype : get;

    auto s = new S;

    auto result1 = R(new Exception("test"));
    assert(result1.get!Exception.msg == "test");

    auto result2 = R(Err!(S*)(s));
    assert(result2.get!(Err!(S*)).error == s);

    const cResult1 = const(R)(new Exception("test"));
    assert(cResult1.get!(const(Exception)).msg == "test");

    const cResult2 = const(R)(Err!(S*)(s));
    assert(cResult2.get!(const(Err!(S*))).error == s);
}
/* Tests for non-void T end */

/* Tests for void T begin */
// Factory method
@safe @nogc nothrow unittest
{
    alias R = Result!(void, string);

    auto resultOk = R.success();
    assert(resultOk.isNull);

    const cResultOk = R.success();
    assert(cResultOk.isNull);

    immutable iResultOk = R.success();
    assert(iResultOk.isNull);

    auto resultErr = R.error("123");
    assert(resultErr.get == "123");

    const cResultErr = R.error("123");
    assert(cResultErr.get == "123");

    immutable iResultErr = R.error("123");
    assert(iResultErr.get == "123");
}
// Ditto
@safe nothrow unittest
{
    struct S
    {
    }

    alias R = Result!(void, S*);
    alias ErrE = Err!(S*);

    auto resultOk = R.success();
    assert(resultOk.isNull);

    const cResultOk = R.success();
    assert(cResultOk.isNull);

    immutable iResultOk = R.success();
    assert(iResultOk.isNull);

    auto resultErr = R.error(new S);
    assert(is(typeof(resultErr.get()) == ErrE));

    const cResultErr = R.error(new S);
    assert(is(typeof(cResultErr.get()) == const(ErrE)));

    immutable iResultErr = R.error(new S);
    assert(is(typeof(iResultErr.get()) == immutable(ErrE)));
}

// Ditto
@safe nothrow unittest
{
    struct S
    {
    }

    alias T = const(void);
    alias E = immutable(S*);
    alias R = Result!(T, E);

    auto resultErr = R.error(new S);
    assert(is(typeof(resultErr.get()) == Err!E));

    auto cResultErr = R.error(new const(S));
    assert(is(typeof(cResultErr.get()) == Err!E));

    auto iResultErr = R.error(new immutable(S));
    assert(is(typeof(iResultErr.get()) == Err!E));
}

// Assignment
@trusted @nogc nothrow unittest
{
    alias R = Result!(void, string);

    auto result1 = R.error("333");
    auto result2 = R.error("3");

    result2 = result1;
    assert(result2.get == "333");

    const result3 = R.success();
    result2 = result3;
    assert(result2.isNull);

    immutable result4 = R.error("1000");
    result2 = result4;
    assert(result2.get == "1000");
}

// Ditto
@trusted unittest
{
    struct S
    {
    }

    alias R = Result!(void, S*);

    auto s1 = new S;
    auto s2 = new S;
    auto result1 = R.error(s1);
    auto result2 = R.error(s2);

    result2 = result1;
    assert(result2.get == s1);

    auto result3 = R.success();

    result2 = result3;
    assert(result2.isNull);
}

// Ditto
@trusted @nogc nothrow unittest
{
    alias R = Result!(void, string);

    auto result = R.success();

    result = Err!string("error");
    assert(result.get == "error");
}

// Ctor
@safe @nogc nothrow unittest
{
    alias R = Result!(void, string);

    auto result1 = R(Err!string("error"));
    assert(result1.get == "error");

    const cResult1 = const(R)(Err!string("error"));
    assert(cResult1.get == "error");
}

// Ditto
@safe @nogc nothrow unittest
{
    alias R = Result!(void, string);
    auto e = Err!string("error");

    auto result1 = R(e);
    assert(result1.get == "error");

    const cResult1 = const(R)(e);
    assert(cResult1.get == "error");
}

// Ditto
@safe nothrow unittest
{
    struct S
    {
    }

    alias R = Result!(void, S*);

    auto s = new S;

    auto result1 = R(Err!(S*)(s));
    assert(result1.get == s);

    const cResult1 = const(R)(Err!(S*)(s));
    assert(cResult1.get == s);
}
/* Tests for void T end */

/* Convenience templates begin */
private alias SuccessValueTypeOf(R : Result!(T, E), T, E) = T;

unittest
{
    alias R = Result!(int, string);
    assert(is(SuccessValueTypeOf!R == int));
    assert(is(SuccessValueTypeOf!(const(R)) == int));
    assert(is(SuccessValueTypeOf!(immutable(R)) == int));
    assert(is(SuccessValueTypeOf!(inout(R)) == int));
}

unittest
{
    alias R = Result!(const(void), string);

    assert(is(SuccessValueTypeOf!R == const(void)));
    assert(is(SuccessValueTypeOf!(const(R)) == const(void)));
    assert(is(SuccessValueTypeOf!(immutable(R)) == const(void)));
    assert(is(SuccessValueTypeOf!(inout(R)) == const(void)));
}

private alias ErrorValueTypeOf(R : Result!(T, E), T, E) = E;

unittest
{
    alias R = Result!(int, string);
    assert(is(ErrorValueTypeOf!R == string));
    assert(is(ErrorValueTypeOf!(const(R)) == string));
    assert(is(ErrorValueTypeOf!(immutable(R)) == string));
    assert(is(ErrorValueTypeOf!(inout(R)) == string));
}

/* Convenience templates end */

/* For UDA begin */
// Represents which function of a certain language the function corresponds to.
struct CorrespondingTo
{
    string language;
    string functionName;
}
/* For UDA end */

/// Checks if a [Result] contains a successful state.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `bool`
///     `.success(*)`|`true`
///     `.error(*)`|`false`
/// )
///
/// Params:
///     r = The [Result] to check
///
/// Returns: `true` if `r` contains a successful state, `false` otherwise
@CorrespondingTo("rust", "is_ok")
@CorrespondingTo("c++", "has_value")
bool isSuccess(T, E)(scope auto ref inout(Result!(T, E)) r)
{
    static if (is(T : void))
    {
        return r.payload.isNull;
    }
    else
    {
        import std.sumtype : has;

        return r.payload.has!(inout(T));
    }
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(int, string);

    auto resultOk = R.success(-3);
    assert(isSuccess(resultOk));

    auto resultErr = R.error("Some error message");
    assert(!isSuccess(resultErr));
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(void, string);

    auto resultOk = R.success();
    assert(isSuccess(resultOk));

    auto resultErr = R.error("Some error message");
    assert(!isSuccess(resultErr));
}

@safe @nogc nothrow unittest
{
    alias R = Result!(int, string);

    const cResultOk = R.success(123);
    assert(isSuccess(cResultOk));

    immutable iResultOk = R.success(123);
    assert(isSuccess(iResultOk));

    const cResultErr = R.error("123");
    assert(!isSuccess(cResultErr));

    immutable iResultErr = R.error("123");
    assert(!isSuccess(iResultErr));
}

@safe @nogc nothrow unittest
{
    alias R = Result!(immutable(void), string);

    const cResultOk = R.success();
    assert(isSuccess(cResultOk));

    immutable iResultOk = R.success();
    assert(isSuccess(iResultOk));

    const cResultErr = R.error("123");
    assert(!isSuccess(cResultErr));

    immutable iResultErr = R.error("123");
    assert(!isSuccess(iResultErr));
}

/// Checks if a [Result] contains a `T` value satisfying a predicate.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `bool`
///     `.success(t)`|`pred(t)`
///     `.error(*)`|`false`
/// )
///
/// Params:
///     r = The [Result] to check
///     pred = The predicate to apply to the `T` value
///
/// Returns: `true` if `r` has a `T` value and it satisfies `pred`, `false` otherwise
@CorrespondingTo("rust", "is_ok_and")
bool isSuccessAnd(alias pred = "a", T, E)(scope auto ref inout(Result!(T, E)) r)
        if (!is(T : void) && !is(typeof(unaryFun!pred(inout(T).init)) : void))
{
    return isSuccess(r) && !!unaryFun!pred(unwrap(r));
}

///
@safe nothrow unittest
{
    alias R = Result!(uint, string);

    auto resultOk1 = R.success(2);
    assert(isSuccessAnd!(a => a > 1)(resultOk1) == true);

    auto resultOk2 = R.success(0);
    assert(isSuccessAnd!"a>1"(resultOk2) == false);

    auto resultErr = R.error("hey");
    assert(isSuccessAnd!"a>1"(resultErr) == false);
}

@safe nothrow unittest
{
    size_t isOdd(int n)
    {
        return n & 1;
    }

    alias R = Result!(int, string);

    auto resultOk = R.success(123);
    assert(isSuccessAnd!isOdd(resultOk));

    const cResultOk = R.success(123);
    assert(isSuccessAnd!isOdd(cResultOk));

    immutable iResultOk = R.success(123);
    assert(isSuccessAnd!isOdd(iResultOk));

    auto resultErr = R.error("123");
    assert(!isSuccessAnd!isOdd(resultErr));

    const cResultErr = R.error("123");
    assert(!isSuccessAnd!isOdd(cResultErr));

    immutable iResultErr = R.error("123");
    assert(!isSuccessAnd!isOdd(iResultErr));
}

/// Checks if a [Result] contains an error.
/// Equivalent to `!`[isSuccess]`(r)`.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `bool`
///     `.success(*)`|`false`
///     `.error(*)`|`true`
/// )
@CorrespondingTo("rust", "is_err")
alias isError = not!isSuccess;

///
@safe @nogc nothrow unittest
{
    alias R = Result!(int, string);

    auto resultOk = R.success(-3);
    assert(!isError(resultOk));

    auto resultErr = R.error("Some error message");
    assert(isError(resultErr));
}

@safe @nogc nothrow unittest
{
    alias R = Result!(int, string);

    const cResultErr = R.error("123");
    assert(isError(cResultErr));

    immutable iResultErr = R.error("123");
    assert(isError(iResultErr));

    auto resultOk = R.success(123);
    assert(!isError(resultOk));

    const cResultOk = R.success(123);
    assert(!isError(cResultOk));

    immutable iResultOk = R.success(123);
    assert(!isError(iResultOk));
}

/// Checks if a [Result] contains an error satisfying a predicate.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `bool`
///     `.success(*)`|`false`
///     `.error(e)`|`pred(e)`
/// )
///
/// Params:
///     r = The [Result] to check
///     pred = The predicate to apply to the `E` value
///
/// Returns: `true` if `r` has an error and it satisfies `pred`, `false` otherwise
@CorrespondingTo("rust", "is_err_and")
bool isErrorAnd(alias pred = "a", T, E)(scope auto ref inout(Result!(T, E)) r)
        if (!is(typeof(unaryFun!pred(inout(E).init)) : void))
{
    return isError(r) && !!unaryFun!pred(unwrapError(r));
}

///
@safe nothrow unittest
{
    alias R = Result!(uint, string);

    auto resultErr1 = R.error("!!!");
    assert(isErrorAnd!(e => e == "!!!")(resultErr1) == true);

    auto resultErr2 = R.error("?");
    assert(isErrorAnd!`a=="!!!"`(resultErr2) == false);

    auto resultOk = R.success(123);
    assert(isErrorAnd!`a=="!!!"`(resultOk) == false);
}

@safe nothrow unittest
{
    import std.string : isNumeric;

    alias R = Result!(int, string);

    auto resultOk = R.success(123);
    assert(!isErrorAnd!isNumeric(resultOk));

    const cResultOk = R.success(123);
    assert(!isErrorAnd!isNumeric(cResultOk));

    immutable iResultOk = R.success(123);
    assert(!isErrorAnd!isNumeric(iResultOk));

    auto resultErr = R.error("123");
    assert(isErrorAnd!isNumeric(resultErr));

    const cResultErr = R.error("123");
    assert(isErrorAnd!isNumeric(cResultErr));

    immutable iResultErr = R.error("123");
    assert(isErrorAnd!isNumeric(iResultErr));

    auto resultErr2 = R.error("Good morning, 007.");
    assert(!isErrorAnd!isNumeric(resultErr2));
}

/// Extracts the `T` value from a [Result] as a `Nullable!T`.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `Nullable!T`
///     `.success(t)`|`t`
///     `.error(*)`|null state
/// )
///
/// Params:
///     r = The [Result] to extract from
///
/// Returns: A `Nullable!T` containing the `T` value, or in the null state if an `E`
@CorrespondingTo("rust", "ok")
inout(Nullable!T) nullableSuccess(T, E)(scope auto ref inout(Result!(T, E)) r) if (!is(T : void))
{
    alias N = typeof(return);
    return isError(r) ? N.init : N(unwrap(r));
}

///
@safe nothrow unittest
{
    alias R = Result!(uint, string);

    import std.typecons : Nullable;

    auto resultOk = R.success(2);
    assert(nullableSuccess(resultOk) == Nullable!uint(2));

    auto resultErr = R.error("Nothing here");
    assert(nullableSuccess(resultErr).isNull);
}

@safe nothrow unittest
{
    alias R = Result!(uint, string);

    const cResultOk = R.success(2);
    assert(nullableSuccess(cResultOk) == Nullable!uint(2));

    immutable iResultOk = R.success(2);
    assert(nullableSuccess(iResultOk) == Nullable!uint(2));

    const cResultErr = R.error("Nothing here");
    assert(nullableSuccess(cResultErr).isNull);

    immutable iResultErr = R.error("Nothing here");
    assert(nullableSuccess(iResultErr).isNull);
}

/// Extracts the error value from a [Result] as a `Nullable!E`.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `Nullable!E`
///     `.success(*)`|null state
///     `.error(e)`|`e`
/// )
///
/// Params:
///     r = The [Result] to extract from
///
/// Returns: A `Nullable!E` containing the `E` value, in the null state if a `T`
@CorrespondingTo("rust", "err")
inout(Nullable!E) nullableError(T, E)(scope auto ref inout(Result!(T, E)) r)
{
    alias N = typeof(return);
    return isSuccess(r) ? N.init : N(unwrapError(r));
}

///
@safe nothrow unittest
{
    alias R = Result!(uint, string);

    import std.typecons : Nullable;

    auto resultOk = R.success(2);
    assert(nullableError(resultOk).isNull);

    auto resultErr = R.error("Nothing here");
    assert(nullableError(resultErr) == Nullable!string("Nothing here"));
}

///
@safe nothrow unittest
{
    alias R = Result!(void, string);

    import std.typecons : Nullable;

    auto resultOk = R.success();
    assert(nullableError(resultOk).isNull);

    auto resultErr = R.error("Nothing here");
    assert(nullableError(resultErr) == Nullable!string("Nothing here"));
}

@safe nothrow unittest
{
    alias R = Result!(uint, string);

    const cResultOk = R.success(2);
    assert(nullableError(cResultOk).isNull);

    immutable iResultOk = R.success(2);
    assert(nullableError(iResultOk).isNull);

    const cResultErr = R.error("Nothing here");
    assert(nullableError(cResultErr) == Nullable!string("Nothing here"));

    immutable iResultErr = R.error("Nothing here");
    assert(nullableError(iResultErr) == Nullable!string("Nothing here"));
}

@safe nothrow unittest
{
    alias R = Result!(immutable(void), string);

    const cResultOk = R.success();
    assert(nullableError(cResultOk).isNull);

    immutable iResultOk = R.success();
    assert(nullableError(iResultOk).isNull);

    const cResultErr = R.error("Nothing here");
    assert(nullableError(cResultErr) == Nullable!string("Nothing here"));

    immutable iResultErr = R.error("Nothing here");
    assert(nullableError(iResultErr) == Nullable!string("Nothing here"));
}

/// Chains two [Result]s, returning the second if the first has a successful state.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input 1: `Result!(T, E)`|Input 2: `Result!(U, E)`|Output: `Result!(U, E)`
///     `.success(*)`|Any `r2`|`r2`
///     `.error(e)`|Any (ignored)|`.error(e)`
/// )
///
/// Params:
///     r1 = The first [Result] to check
///     r2 = The [Result] to return if `r1` has a successful state
///
/// Returns: `r2` if `r1` has a successful state, otherwise a new [Result]`!(U, E)` with `r1`'s error value
@CorrespondingTo("rust", "and")
inout(Result!(U, E)) and(T, U, E)(scope auto ref inout(Result!(T, E)) r1,
        scope auto ref inout(Result!(U, E)) r2)
{
    return isSuccess(r1) ? r2 : Result!(U, E).error(unwrapError(r1));
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(uint, string);
    alias S = Result!(string, string);

    auto x1 = R.success(2);
    auto y1 = S.error("late error");
    assert(and(x1, y1) == S.error("late error"));

    auto x2 = R.error("early error");
    auto y2 = S.success("foo");
    assert(and(x2, y2) == S.error("early error"));

    auto x3 = R.error("not a 2");
    auto y3 = S.error("late error");
    assert(and(x3, y3) == S.error("not a 2"));

    auto x4 = R.success(2);
    auto y4 = S.success("different result type");
    assert(and(x4, y4) == S.success("different result type"));
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(void, string);
    alias S = Result!(string, string);

    auto x1 = R.success();
    auto y1 = S.error("late error");
    assert(and(x1, y1) == S.error("late error"));

    auto x2 = R.error("early error");
    auto y2 = S.success("foo");
    assert(and(x2, y2) == S.error("early error"));

    auto x3 = R.error("not a 2");
    auto y3 = S.error("late error");
    assert(and(x3, y3) == S.error("not a 2"));

    auto x4 = R.success();
    auto y4 = S.success("different result type");
    assert(and(x4, y4) == S.success("different result type"));
}

@safe @nogc nothrow unittest
{
    alias R = Result!(uint, string);
    alias S = Result!(const(void), string);

    immutable x1 = R.success(2);
    auto y1 = S.error("late error");
    assert(and(x1, y1) == S.error("late error"));

    auto x2 = R.error("early error");
    const y2 = S.success();
    assert(and(x2, y2) == S.error("early error"));

    const x3 = R.error("not a 2");
    immutable y3 = S.error("late error");
    assert(and(x3, y3) == S.error("not a 2"));

    immutable x4 = R.success(2);
    immutable y4 = S.success();
    assert(and(x4, y4) == S.success());
}

/// Applies a function to the `T` value of a [Result], chaining [Result]s.
///
/// If `r` has a `T` value, calls `fun` with the value and returns the resulting [Result].
/// If `r` has an `E`, returns a new [Result] with the same `E` value.
/// `fun` must return [Result] with the same type `E` for an error.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `Result!(U, E)`
///     `.success(t)`|`fun(t)`
///     `.error(e)`|`.error(e)`
/// )
//
/// Params:
///     r = The [Result] to operate on
///     fun = The function to apply to the `T` value
///
/// Returns: The [Result] returned by `fun` if `r` contains a `T`, otherwise a new [Result] with the original `E` value
@CorrespondingTo("rust", "and_then")
@CorrespondingTo("c++", "and_then")
auto andThen(alias fun, T, E)(scope auto ref inout(Result!(T, E)) r)
        if (!is(T : void) && is(E == ErrorValueTypeOf!(typeof(unaryFun!fun(inout(T).init)))))
{
    alias U = SuccessValueTypeOf!(typeof(unaryFun!fun(inout(T).init)));
    return isSuccess(r) ? unaryFun!fun(unwrap(r)) : Result!(U, E).error(unwrapError(r));
}

///
@safe nothrow unittest
{
    alias R = Result!(uint, string);
    alias S = Result!(string, string);

    auto checkedBinOp(string op, X, Y)(X x, Y y)
    {
        import std.checkedint : opChecked;
        import std.typecons : nullable, Nullable;

        bool overflow;
        auto r = opChecked!op(x, y, overflow);
        return overflow ? Nullable!(typeof(r)).init : nullable(r);
    }

    auto sqThenToString(uint x)
    {
        import std.conv : to;
        import std.typecons : apply;

        return checkedBinOp!"*"(x, x).apply!(to!string)
            .apply!(S.success)
            .get(S.error("overflowed"));
    }

    assert(andThen!sqThenToString(R.success(2)) == S.success("4"));
    assert(andThen!sqThenToString(R.success(1_000_000)) == S.error("overflowed"));
    assert(andThen!sqThenToString(R.error("not a number")) == S.error("not a number"));
}

@safe nothrow unittest
{
    alias R = Result!(float, string);
    alias S = Result!(int, string);

    S toInt(float x)
    {
        try
        {
            import std.conv : to;

            return S.success(to!int(x));
        }
        catch (Exception e)
        {
            return S.error(typeid(e).toString());
        }
    }

    auto resultOk1 = R.success(2.3);
    assert(andThen!toInt(resultOk1) == S.success(2));

    auto resultOk2 = R.success(float.nan);
    assert(andThen!toInt(resultOk2) == S.error("std.conv.ConvException"));

    auto resultErr = R.error("bad value");
    assert(andThen!toInt(resultErr) == S.error("bad value"));
}

/// Chains two [Result]s, returning the first if the first has a successful state.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input 1: `Result!(T, E)`|Input 2: `Result!(T, F)`|Output: `Result!(T, F)`
///     `.success(t)`|Any (ignored)|`.success(t)`
///     `.error(*)`|Any `r2`|`r2`
/// )
//
/// Params:
///     r1 = The first [Result] to check
///     r2 = The [Result] to return if `r1` has an `E` value
///
/// Returns: `r2` if `r1` has an error value, otherwise a new [Result]`!(T, F)` with `r1`'s `T` value
@CorrespondingTo("rust", "or")
auto or(T, E, F)(scope auto ref inout(Result!(T, E)) r1, scope auto ref inout(Result!(T, F)) r2)
{
    static if (is(T : void))
    {
        return isError(r1) ? r2 : Result!(T, F).success();
    }
    else
    {
        return isError(r1) ? r2 : Result!(T, F).success(unwrap(r1));
    }
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(uint, string);
    alias S = Result!(uint, dstring);

    auto x1 = R.success(2);
    auto y1 = S.error("late error");
    assert(or(x1, y1) == S.success(2));

    auto x2 = R.error("early error");
    auto y2 = S.success(2);
    assert(or(x2, y2) == S.success(2));

    auto x3 = R.error("not a 2");
    auto y3 = S.error("late error");
    assert(or(x3, y3) == S.error("late error"));

    auto x4 = R.success(2);
    auto y4 = S.success(100);
    assert(or(x4, y4) == S.success(2));
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(void, string);
    alias S = Result!(void, dstring);

    auto x1 = R.success();
    auto y1 = S.error("late error");
    assert(or(x1, y1) == S.success());

    auto x2 = R.error("early error");
    auto y2 = S.success();
    assert(or(x2, y2) == S.success());

    auto x3 = R.error("not a 2");
    auto y3 = S.error("late error");
    assert(or(x3, y3) == S.error("late error"));

    auto x4 = R.success();
    auto y4 = S.success();
    assert(or(x4, y4) == S.success());
}

@safe @nogc nothrow unittest
{
    alias R = Result!(const(void), string);
    alias S = Result!(const(void), dstring);

    auto x1 = R.success();
    const y1 = S.error("late error");
    assert(or(x1, y1) == S.success());

    immutable x2 = R.error("early error");
    const y2 = S.success();
    assert(or(x2, y2) == S.success());

    immutable x3 = R.error("not a 2");
    immutable y3 = S.error("late error");
    assert(or(x3, y3) == S.error("late error"));

    const x4 = R.success();
    const y4 = S.success();
    assert(or(x4, y4) == S.success());
}

@safe @nogc nothrow unittest
{
    alias R = Result!(uint, string);
    alias S = Result!(uint, dstring);

    auto x1 = R.success(2);
    const y1 = S.error("late error");
    assert(or(x1, y1) == S.success(2));

    immutable x2 = R.error("early error");
    const y2 = S.success(2);
    assert(or(x2, y2) == S.success(2));

    immutable x3 = R.error("not a 2");
    immutable y3 = S.error("late error");
    assert(or(x3, y3) == S.error("late error"));

    const x4 = R.success(2);
    const y4 = S.success(100);
    assert(or(x4, y4) == S.success(2));
}

/// Applies a function to the `E` value of a [Result], chaining [Result]s.
///
/// If `r` has an `E` value, calls `fun` with the value and returns the resulting [Result].
/// If `r` has a successful state, returns a new [Result] with the same `T` value.
/// `fun` must return [Result] with the same type`T` for a successful state.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `Result!(T, F)`
///     `.success(t)`|`.success(t)`
///     `.error(e)`|`fun(e)`
/// )
//
/// Params:
///     r = The [Result] to operate on
///     fun = The function to apply to the `E` value
///
/// Returns: The [Result] returned by `fun` if `r` contains an `E`, otherwise a new [Result] with the original `T` value
@CorrespondingTo("rust", "or_else")
@CorrespondingTo("c++", "or_else")
auto orElse(alias fun, T, E)(scope auto ref inout(Result!(T, E)) r)
        if (is(T == SuccessValueTypeOf!(typeof(unaryFun!fun(inout(E).init)))))
{
    alias F = ErrorValueTypeOf!(typeof(unaryFun!fun(inout(E).init)));
    static if (is(T : void))
    {
        return isError(r) ? unaryFun!fun(unwrapError(r)) : Result!(T, F).success();
    }
    else
    {
        return isError(r) ? unaryFun!fun(unwrapError(r)) : Result!(T, F).success(unwrap(r));
    }
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(uint, uint);

    R sq(uint x)
    {
        return R.success(x * x);
    }

    R err(uint x)
    {
        return R.error(x);
    }

    assert(orElse!sq(orElse!sq(R.success(2))) == R.success(2));
    assert(orElse!sq(orElse!err(R.success(2))) == R.success(2));
    assert(orElse!err(orElse!sq(R.error(3))) == R.success(9));
    assert(orElse!err(orElse!err(R.error(3))) == R.error(3));
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(void, uint);

    R forge(uint x)
    {
        return R.success();
    }

    R err(uint x)
    {
        return R.error(x);
    }

    assert(orElse!forge(orElse!forge(R.success())) == R.success());
    assert(orElse!forge(orElse!err(R.success())) == R.success());
    assert(orElse!err(orElse!forge(R.error(3))) == R.success());
    assert(orElse!err(orElse!err(R.error(3))) == R.error(3));
}

@safe @nogc nothrow unittest
{
    alias R = Result!(bool, string);
    alias S = Result!(bool, size_t);

    S isEmpty(string x)
    {
        if (x.length > 0)
        {
            return S.error(x.length);
        }

        return S.success(true);
    }

    auto resultOk = R.success(false);
    assert(orElse!isEmpty(resultOk) == S.success(false));

    auto resultErr1 = R.error("");
    assert(orElse!isEmpty(resultErr1) == S.success(true));

    auto resultErr2 = R.error("too long string");
    assert(orElse!isEmpty(resultErr2) == S.error(15));
}

/// Extracts the `T` value from a [Result].
///
/// The [Result] must contain a successful state. Use [isSuccess] to check.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `T`
///     `.success(t)`|`t`
///     `.error(*)`|Undefined
/// )
///
/// Params:
///     r = The [Result] to unwrap
///
/// Returns: The contained `T` value, or nothing if `T` is `void`
@CorrespondingTo("rust", "unwrap")
@CorrespondingTo("rust", "unwrap_unchecked")
auto ref inout(T) unwrap(T, E)(scope return auto ref inout(Result!(T, E)) r)
in (isSuccess(r), "Result does not have a successful state.")
{
    static if (is(T : void))
    {
        return;
    }
    else
    {
        import std.sumtype : get;

        return r.payload.get!(inout(T));
    }
}

///
unittest
{
    alias R = Result!(uint, string);

    auto resultOk = R.success(2);
    assert(unwrap(resultOk) == 2);

    import std.exception : assertThrown;
    import core.exception : AssertError;

    auto resultErr = R.error("emergency failure");
    assertThrown!AssertError(unwrap(resultErr));
}

///
unittest
{
    alias R = Result!(void, string);

    import std.exception : assertNotThrown, assertThrown;
    import core.exception : AssertError;

    auto resultOk = R.success();
    assertNotThrown!AssertError(unwrap(resultOk));

    auto resultErr = R.error("emergency failure");
    assertThrown!AssertError(unwrap(resultErr));
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;
    import core.exception : AssertError;

    auto resultOk1 = Result!(immutable(void), string).success();
    assertNotThrown!AssertError(unwrap(resultOk1));

    alias R = Result!(void, uint);

    auto resultOk2 = R.success();
    assertNotThrown!AssertError(unwrap(resultOk2));

    auto resultErr = R.error(123);
    assertThrown!AssertError(unwrap(resultErr));
}

/// Extracts the `E` value from a [Result].
///
/// The [Result] must contain an `E` value. Use [isError] to check.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `E`
///     `.success(*)`|Undefined
///     `.error(e)`|`e`
/// )
///
/// Params:
///     r = The [Result] to unwrap
///
/// Returns: The contained `E` value
@CorrespondingTo("rust", "unwrap_err")
@CorrespondingTo("rust", "unwrap_err_unchecked")
@CorrespondingTo("c++", "error")
auto ref inout(E) unwrapError(T, E)(scope return auto ref inout(Result!(T, E)) r)
in (isError(r), "Result does not have an error state.")
{
    static if (is(T : void))
    {
        return r.payload.get().error;
    }
    else
    {
        import std.sumtype : get;

        return r.payload.get!(inout(Err!E)).error;
    }
}

///
unittest
{
    import std.exception : assertThrown;
    import core.exception : AssertError;

    alias R = Result!(uint, string);

    auto resultOk = R.success(2);
    assertThrown!AssertError(unwrapError(resultOk));

    auto resultErr = R.error("emergency failure");
    assert(unwrapError(resultErr) == "emergency failure");
}

///
unittest
{
    import std.exception : assertThrown;
    import core.exception : AssertError;

    alias R = Result!(void, string);

    auto resultOk = R.success();
    assertThrown!AssertError(unwrapError(resultOk));

    auto resultErr = R.error("emergency failure");
    assert(unwrapError(resultErr) == "emergency failure");
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;
    import core.exception : AssertError;

    auto resultErr1 = Result!(int, string).error("123");
    assert(assertNotThrown!AssertError(unwrapError(resultErr1)) == "123");

    alias R = Result!(string, uint);

    auto resultErr2 = R.error(123);
    assert(assertNotThrown!AssertError(unwrapError(resultErr2)) == 123);

    auto resultOk = R.success("123");
    assertThrown!AssertError(unwrapError(resultOk));
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;
    import core.exception : AssertError;

    auto resultErr1 = Result!(void, string).error("123");
    assert(assertNotThrown!AssertError(unwrapError(resultErr1)) == "123");

    alias R = Result!(const(void), uint);

    auto resultErr2 = R.error(123);
    assert(assertNotThrown!AssertError(unwrapError(resultErr2)) == 123);

    auto resultOk = R.success();
    assertThrown!AssertError(unwrapError(resultOk));
}

/// Tries to extract the `T` value from a [Result], with a custom error message.
///
/// If the [Result] has an `E`, an [UnwrapException] is thrown with `msg`.
/// If `msg` is not provided, the default message is used.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `T`
///     `.success(t)`|`t`
///     `.error(*)`|`UnwrapException` is thrown
/// )
///
/// Params:
///     r = The [Result] to unwrap
///     msg = The message to include in the exception if [Result] contains an `E` value
///
/// Returns: The contained `T` value, or nothing if `T` is `void`
///
/// Throws: [UnwrapException] with message `msg` if `r` contains an `E`
@CorrespondingTo("rust", "expect")
@CorrespondingTo("c++", "value")
auto ref inout(T) tryUnwrap(T, E)(scope return auto ref inout(Result!(T, E)) r, lazy string msg = null)
{
    import std.exception : enforce;

    if (msg is null)
    {
        enforce!UnwrapException(isSuccess(r), "Result does not have a successful state.");
    }
    else
    {
        enforce!UnwrapException(isSuccess(r), msg);
    }
    return unwrap(r);
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    alias R = Result!(uint, string);

    auto resultOk = R.success(2);
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk, "Testing expect")) == 2);

    auto resultErr = R.error("emergency failure");
    assertThrown!UnwrapException(tryUnwrap(resultErr, "Testing expect"));
    assert(collectExceptionMsg(tryUnwrap(resultErr, "Testing expect")) == "Testing expect");
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    alias R = Result!(void, string);

    auto resultOk = R.success();
    assertNotThrown!UnwrapException(tryUnwrap(resultOk, "Testing expect"));

    auto resultErr = R.error("emergency failure");
    assertThrown!UnwrapException(tryUnwrap(resultErr, "Testing expect"));
    assert(collectExceptionMsg(tryUnwrap(resultErr, "Testing expect")) == "Testing expect");
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    auto resultOk1 = Result!(int, string).success(123);
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk1, "foo")) == 123);
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk1)) == 123);

    alias R = Result!(string, uint);

    auto resultOk2 = R.success("123");
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk2, "foo")) == "123");
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk2)) == "123");

    auto resultErr = R.error(123);
    assertThrown!UnwrapException(tryUnwrap(resultErr, "foo"));
    assert(collectExceptionMsg(tryUnwrap(resultErr, "foo")) == "foo");
    assertThrown!UnwrapException(tryUnwrap(resultErr));
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    auto resultOk1 = Result!(void, string).success();
    assertNotThrown!UnwrapException(tryUnwrap(resultOk1, "foo"));
    assertNotThrown!UnwrapException(tryUnwrap(resultOk1));

    alias R = Result!(const(void), uint);

    auto resultOk2 = R.success();
    assertNotThrown!UnwrapException(tryUnwrap(resultOk2, "foo"));
    assertNotThrown!UnwrapException(tryUnwrap(resultOk2));

    auto resultErr = R.error(123);
    assertThrown!UnwrapException(tryUnwrap(resultErr, "foo"));
    assert(collectExceptionMsg(tryUnwrap(resultErr, "foo")) == "foo");
    assertThrown!UnwrapException(tryUnwrap(resultErr));
}

/// Tries to extract the `E` value from a [Result], with a custom error message.
///
/// If the [Result] has a successful state, an [UnwrapException] is thrown with `msg`.
/// If `msg` is not provided, the default message is used.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `E`
///     `.success(*)`|`UnwrapException` is thrown
///     `.error(e)`|`e`
/// )
////// Params:
///     r = The [Result] to unwrap
///     msg = The message to include in the exception if [Result] has a successful state
///
/// Returns: The contained `E` value
///
/// Throws: [UnwrapException] with message `msg` if the `r` has a successful state
@CorrespondingTo("rust", "expect_err")
auto ref inout(E) tryUnwrapError(T, E)(scope return auto ref inout(Result!(T, E)) r,
        lazy string msg = null)
{
    import std.exception : enforce;

    if (msg is null)
    {
        enforce!UnwrapException(isError(r), "Result does not have an error state.");
    }
    else
    {
        enforce!UnwrapException(isError(r), msg);
    }
    return unwrapError(r);
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    alias R = Result!(uint, string);

    auto resultOk = R.success(2);
    assertThrown!UnwrapException(tryUnwrapError(resultOk, "Testing tryUnwrapError"));
    assert(collectExceptionMsg(tryUnwrapError(resultOk,
            "Testing tryUnwrapError")) == "Testing tryUnwrapError");

    auto resultErr = R.error("emergency failure");
    assert(assertNotThrown!UnwrapException(tryUnwrapError(resultErr,
            "Testing tryUnwrapError")) == "emergency failure");
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    alias R = Result!(void, string);

    auto resultOk = R.success();
    assertThrown!UnwrapException(tryUnwrapError(resultOk, "Testing tryUnwrapError"));
    assert(collectExceptionMsg(tryUnwrapError(resultOk,
            "Testing tryUnwrapError")) == "Testing tryUnwrapError");

    auto resultErr = R.error("emergency failure");
    assert(assertNotThrown!UnwrapException(tryUnwrapError(resultErr,
            "Testing tryUnwrapError")) == "emergency failure");
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    auto resultErr1 = Result!(immutable(void), string).error("123");
    assert(assertNotThrown!UnwrapException(tryUnwrapError(resultErr1, "bar")) == "123");
    assert(assertNotThrown!UnwrapException(tryUnwrapError(resultErr1)) == "123");

    alias R = Result!(const(void), uint);

    auto resultErr2 = R.error(123);
    assert(assertNotThrown!UnwrapException(tryUnwrapError(resultErr2, "bar")) == 123);
    assert(assertNotThrown!UnwrapException(tryUnwrapError(resultErr2)) == 123);

    auto resultOk = R.success();
    assertThrown!UnwrapException(tryUnwrapError(resultOk, "bar"));
    assert(collectExceptionMsg(tryUnwrapError(resultOk, "bar")) == "bar");
    assertThrown!UnwrapException(tryUnwrapError(resultOk));
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    auto resultErr1 = Result!(int, string).error("123");
    assert(assertNotThrown!UnwrapException(tryUnwrapError(resultErr1, "bar")) == "123");
    assert(assertNotThrown!UnwrapException(tryUnwrapError(resultErr1)) == "123");

    alias R = Result!(string, uint);

    auto resultErr2 = R.error(123);
    assert(assertNotThrown!UnwrapException(tryUnwrapError(resultErr2, "bar")) == 123);
    assert(assertNotThrown!UnwrapException(tryUnwrapError(resultErr2)) == 123);

    auto resultOk = R.success("123");
    assertThrown!UnwrapException(tryUnwrapError(resultOk, "bar"));
    assert(collectExceptionMsg(tryUnwrapError(resultOk, "bar")) == "bar");
    assertThrown!UnwrapException(tryUnwrapError(resultOk));
}

/// Extracts the `T` value from a [Result], with a default value for an error.
///
/// If the [Result] has a `T`, returns the value.
/// If the [Result] has an `E`, returns the default value.
/// The `T` value and the default value must be able to be implicitly converted to some common type.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `auto`
///     `.success(t)`|`t`
///     `.error(*)`|Default value
/// )
///
/// Params:
///     r = The [Result] to unwrap
///     defaultValue = The fallback value to be used if an error
///
/// Returns: The contained `T` value, or `defaultValue` if `r` has an `E`
@CorrespondingTo("rust", "unwrap_or")
@CorrespondingTo("rust", "unwrap_or_default")
@CorrespondingTo("c++", "value_or")
auto unwrapOr(T, U, E)(scope auto ref inout(Result!(T, E)) r, U defaultValue = inout(T).init)
        if (!is(T : void))
{
    return isSuccess(r) ? unwrap(r) : defaultValue;
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(uint, string);

    immutable defaultValue = 2;

    auto resultOk = R.success(9);
    assert(unwrapOr(resultOk, defaultValue) == 9);

    auto resultErr = R.error("error");
    assert(unwrapOr(resultErr, defaultValue) == defaultValue);
}

/// Using default parameter
@safe nothrow unittest
{
    auto parse(string s)
    {
        alias R = Result!(int, string);

        try
        {
            import std.conv : to;

            return R.success(to!int(s));
        }
        catch (Exception _)
        {
            return R.error(s);
        }
    }

    immutable goodYearFromInput = "1909";
    immutable badYearFromInput = "190blarg";

    assert(unwrapOr(parse(goodYearFromInput)) == 1909);
    assert(unwrapOr(parse(badYearFromInput)) == 0);
}

@safe @nogc nothrow unittest
{
    auto resultOk1 = Result!(int, string).success(123);
    assert(unwrapOr(resultOk1, 456) == 123);
    assert(unwrapOr(resultOk1) == 123);

    alias R = Result!(string, uint);

    const resultOk2 = R.success("123");
    assert(unwrapOr(resultOk2, "456") == "123");
    assert(unwrapOr(resultOk2) == "123");

    auto resultErr = R.error(123);
    assert(unwrapOr(resultErr, "456") == "456");
    assert(unwrapOr(resultErr) == "");
}

/// Extracts the `T` value from a [Result], computing a fallback from the `E` value.
///
/// If the [Result] has a `T`, returns the value.
/// If the [Result] has an `E`, calls `fun` with the value and returns the result.
/// The return value of `fun` and the `T` value must be able to be implicitly converted to some common type.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `auto`
///     `.success(t)`|`t`
///     `.error(e)`|`fun(e)`
/// )
///
/// Params:
///     r = The [Result] to unwrap
///     fun = The function to apply to the `E` value
///
/// Returns: The contained `T` value or the result of calling `fun` with the `E` value
@CorrespondingTo("rust", "unwrap_or_else")
auto unwrapOrElse(alias fun, T, E)(scope auto ref inout(Result!(T, E)) r)
        if (!is(CommonType!(inout(T), typeof(unaryFun!fun(inout(E).init))) : void))
{
    return isSuccess(r) ? unwrap(r) : unaryFun!fun(unwrapError(r));
}

///
@safe nothrow unittest
{
    alias count = x => x.length;

    alias R = Result!(size_t, string);

    auto resultOk = R.success(2);
    assert(unwrapOrElse!count(resultOk) == 2);

    auto resultErr = R.error("foo");
    assert(unwrapOrElse!count(resultErr) == 3);
    assert(unwrapOrElse!`a.length`(resultErr) == 3);
}

@safe unittest
{
    import std.conv : to;

    auto f999(string s)
    {
        return immutable(ulong)(999);
    }

    auto fFoo(uint n)
    {
        return "Foo is " ~ to!string(n);
    }

    auto resultOk1 = Result!(int, string).success(123);
    assert(unwrapOrElse!"999"(resultOk1) == 123);
    assert(unwrapOrElse!f999(resultOk1) == 123);

    alias R = Result!(string, uint);

    immutable resultOk2 = R.success("123");
    assert(unwrapOrElse!(to!string)(resultOk2) == "123");
    assert(unwrapOrElse!fFoo(resultOk2) == "123");

    auto resultErr = R.error(123);
    assert(unwrapOrElse!(to!string)(resultErr) == "123");
    assert(unwrapOrElse!"to!string(a+2)"(resultErr) == "125");
    assert(unwrapOrElse!"`foo`"(resultErr) == "foo");
    assert(unwrapOrElse!fFoo(resultErr) == "Foo is 123");
}

/// Extracts the `E` value from a [Result], with a default value for a successful state.
///
/// If the [Result] has a `T`, returns the default value.
/// If the [Result] has an `E`, returns the value.
/// The `E` value and the default value must be able to be implicitly converted to some common type.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `auto`
///     `.success(*)`|Default value
///     `.error(e)`|`e`
/// )
///
/// Params:
///     r = The [Result] to unwrap
///     defaultValue = The fallback value to be used if an error
///
/// Returns: The contained `E` value, or `defaultValue` if `r` has a `T`
@CorrespondingTo("c++", "error_or")
auto unwrapErrorOr(T, E, F)(scope auto ref inout(Result!(T, E)) r, F defaultValue = inout(E).init)
{
    return isError(r) ? unwrapError(r) : defaultValue;
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(uint, string);

    immutable defaultValue = "Being right is wrong.";

    auto resultOk = R.success(9);
    assert(unwrapErrorOr(resultOk, defaultValue) == defaultValue);
    assert(unwrapErrorOr(resultOk) == "");

    auto resultErr = R.error("error");
    assert(unwrapErrorOr(resultErr, defaultValue) == "error");
    assert(unwrapErrorOr(resultErr) == "error");
}

@safe @nogc nothrow unittest
{
    auto resultOk1 = Result!(int, string).success(123);
    assert(unwrapErrorOr(resultOk1, "bad") == "bad");
    assert(unwrapErrorOr(resultOk1) == "");

    alias R = Result!(string, uint);

    const resultOk2 = R.success("123");
    assert(unwrapErrorOr(resultOk2, 1) == 1);
    assert(unwrapErrorOr(resultOk2) == 0);

    auto resultErr1 = R.error(123);
    assert(unwrapErrorOr(resultErr1, 1) == 123);
    assert(unwrapErrorOr(resultErr1) == 123);

    const resultErr2 = R.error(123);
    assert(unwrapErrorOr(resultErr2, 1) == 123);
    assert(unwrapErrorOr(resultErr2) == 123);
}

/// Transforms the `T` value of a [Result] using a function, keeping the `E` value unchanged.
///
/// If the [Result] has a `T`, applies `fun` to the value and returns a new [Result] with the transformed value.
/// If the [Result] has an `E`, returns a new [Result] with the same `E` value.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `Result!(U, E)`
///     `.success(t)`|`.success(fun(t))`
///     `.error(e)`|`.error(e)`
/// )
///
/// Params:
///     r = The [Result] to transform
///     fun = The function to apply to the `T` value
///
/// Returns: A new [Result] with the transformed value from `T`, or with the original `E` value
@CorrespondingTo("rust", "map")
@CorrespondingTo("c++", "transform")
auto map(alias fun = "a", T, E)(scope auto ref inout(Result!(T, E)) r)
        if ((!is(T : void) && is(typeof(unaryFun!fun(inout(T).init)))) || (is(T
            : void) && is(typeof(fun()))))
{
    static if (is(T : void))
    {
        alias U = Unqual!(typeof(fun()));
    }
    else
    {
        alias U = Unqual!(typeof(unaryFun!fun(inout(T).init)));
    }
    alias S = Result!(U, E);
    if (isSuccess(r))
    {
        static if (is(T : void) && is(U : void))
        {
            fun();
            return S.success();
        }
        else static if (!is(T : void) && is(U : void))
        {
            unaryFun!fun(unwrap(r));
            return S.success();
        }
        else static if (is(T : void) && !is(U : void))
        {
            return S.success(fun());
        }
        else
        {
            return S.success(unaryFun!fun(unwrap(r)));
        }
    }
    else
    {
        return S.error(unwrapError(r));
    }

}

///
@safe nothrow unittest
{
    auto parse(string s)
    {
        alias R = Result!(int, string);

        try
        {
            import std.conv : to;

            return R.success(to!int(s));
        }
        catch (Exception _)
        {
            return R.error(s);
        }
    }

    immutable line = "1\n2\n3\n4\n";
    int[] arr;

    import std.string : lineSplitter;

    foreach (num; lineSplitter(line))
    {
        import std.sumtype : match;

        immutable r = map!`a*2`(parse(num));
        if (isSuccess(r))
        {
            arr ~= unwrap(r);
        }
    }

    assert(arr == [2, 4, 6, 8]);
}

@safe unittest
{
    import std.conv : to;

    alias R = Result!(int, string);
    alias S = Result!(dstring, string);

    auto resultOk = R.success(-22);
    assert(map!(to!dstring)(resultOk) == S.success("-22"));
    assert(map(resultOk) == R.success(-22));

    const cResultOk = R.success(-22);
    assert(map!(to!dstring)(cResultOk) == S.success("-22"));
    assert(map(cResultOk) == R.success(-22));

    immutable iResultOk = R.success(-22);
    assert(map!(to!dstring)(iResultOk) == S.success("-22"));
    assert(map(iResultOk) == R.success(-22));

    auto resultErr = R.error("bad");
    assert(map!(to!dstring)(resultErr) == S.error("bad"));
    assert(map(resultErr) == R.error("bad"));

    const cResultErr = R.error("bad");
    assert(map!(to!dstring)(cResultErr) == S.error("bad"));
    assert(map(cResultErr) == R.error("bad"));

    immutable iResultErr = R.error("bad");
    assert(map!(to!dstring)(iResultErr) == S.error("bad"));
    assert(map(iResultErr) == R.error("bad"));
}

@safe unittest
{
    alias R = Result!(void, string);
    void f()
    {
        return;
    }

    auto resultOk = R.success();
    assert(map!f(resultOk) == R.success());

    const cResultOk = R.success();
    assert(map!f(cResultOk) == R.success());

    immutable iResultOk = R.success();
    assert(map!f(iResultOk) == R.success());

    auto resultErr = R.error("bad");
    assert(map!f(resultErr) == R.error("bad"));

    const cResultErr = R.error("bad");
    assert(map!f(cResultErr) == R.error("bad"));

    immutable iResultErr = R.error("bad");
    assert(map!f(iResultErr) == R.error("bad"));
}

@safe unittest
{
    alias R = Result!(void, string);
    alias S = Result!(int, string);
    int f()
    {
        return 11;
    }

    auto resultOk = R.success();
    assert(map!f(resultOk) == S.success(11));

    const cResultOk = R.success();
    assert(map!f(cResultOk) == S.success(11));

    immutable iResultOk = R.success();
    assert(map!f(iResultOk) == S.success(11));

    auto resultErr = R.error("bad");
    assert(map!f(resultErr) == S.error("bad"));

    const cResultErr = R.error("bad");
    assert(map!f(cResultErr) == S.error("bad"));

    immutable iResultErr = R.error("bad");
    assert(map!f(iResultErr) == S.error("bad"));
}

@safe unittest
{
    alias R = Result!(int, string);
    alias S = Result!(void, string);
    void f(int _)
    {
        return;
    }

    auto resultOk = R.success(-22);
    assert(map!f(resultOk) == S.success());

    const cResultOk = R.success(-22);
    assert(map!f(cResultOk) == S.success());

    immutable iResultOk = R.success(-22);
    assert(map!f(iResultOk) == S.success());

    auto resultErr = R.error("bad");
    assert(map!f(resultErr) == S.error("bad"));

    const cResultErr = R.error("bad");
    assert(map!f(cResultErr) == S.error("bad"));

    immutable iResultErr = R.error("bad");
    assert(map!f(iResultErr) == S.error("bad"));
}

/// Transforms the `E` value of a [Result] using a function, keeping the `T` value unchanged.
///
/// If the [Result] has an `E`, applies `fun` to the value and returns a new [Result] with the transformed error value.
/// If the [Result] has a `T`, returns a new [Result] with the same `T` value.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `Result!(T, F)`
///     `.success(t)`|`.success(t)`
///     `.error(e)`|`.error(fun(e))`
/// )
///
/// Params:
///     r = The [Result] to transform
///     fun = The function to apply to the `E` value
///
/// Returns: A new [Result] with the transformed error value from `E`, or with the original `T` value
@CorrespondingTo("rust", "map_err")
@CorrespondingTo("c++", "transform_error")
auto mapError(alias fun = "a", T, E)(scope auto ref inout(Result!(T, E)) r)
        if (!is(typeof(unaryFun!fun(inout(E).init)) : void))
{
    alias F = Unqual!(typeof(unaryFun!fun(inout(E).init)));
    alias S = Result!(T, F);
    static if (is(T : void))
    {
        return isError(r) ? S.error(unaryFun!fun(unwrapError(r))) : S.success();
    }
    else
    {
        return isError(r) ? S.error(unaryFun!fun(unwrapError(r))) : S.success(unwrap(r));
    }
}

///
@safe unittest
{
    auto stringify(uint x)
    {
        import std.format : format;

        return format!"error code: %s"(x);
    }

    alias R = Result!(uint, uint);
    alias S = Result!(uint, string);

    auto resultOk = R.success(2);
    assert(mapError!stringify(resultOk) == S.success(2));

    auto resultErr = R.error(13);
    assert(mapError!stringify(resultErr) == S.error("error code: 13"));
}

///
@safe unittest
{
    auto stringify(uint x)
    {
        import std.format : format;

        return format!"error code: %s"(x);
    }

    alias R = Result!(void, uint);
    alias S = Result!(void, string);

    auto resultOk = R.success();
    assert(mapError!stringify(resultOk) == S.success());

    auto resultErr = R.error(13);
    assert(mapError!stringify(resultErr) == S.error("error code: 13"));
}

@safe unittest
{
    import std.conv : to;

    alias R = Result!(int, string);
    alias S = Result!(int, size_t);

    auto resultOk = R.success(-22);
    assert(mapError!(a => a.length)(resultOk) == S.success(-22));
    assert(mapError(resultOk) == R.success(-22));

    const cResultOk = R.success(-22);
    assert(mapError!(a => a.length)(cResultOk) == S.success(-22));
    assert(mapError(cResultOk) == R.success(-22));

    immutable iResultOk = R.success(-22);
    assert(mapError!(a => a.length)(iResultOk) == S.success(-22));
    assert(mapError(iResultOk) == R.success(-22));

    auto resultErr = R.error("bad");
    assert(mapError!(a => a.length)(resultErr) == S.error(3));
    assert(mapError(resultErr) == R.error("bad"));

    const cResultErr = R.error("bad");
    assert(mapError!(a => a.length)(cResultErr) == S.error(3));
    assert(mapError(cResultErr) == R.error("bad"));

    immutable iResultErr = R.error("bad");
    assert(mapError!(a => a.length)(iResultErr) == S.error(3));
    assert(mapError(iResultErr) == R.error("bad"));
}

@safe unittest
{
    import std.conv : to;

    alias R = Result!(void, string);
    alias S = Result!(void, size_t);

    auto resultOk = R.success();
    assert(mapError!(a => a.length)(resultOk) == S.success());
    assert(mapError(resultOk) == R.success());

    const cResultOk = R.success();
    assert(mapError!(a => a.length)(cResultOk) == S.success());
    assert(mapError(cResultOk) == R.success());

    immutable iResultOk = R.success();
    assert(mapError!(a => a.length)(iResultOk) == S.success());
    assert(mapError(iResultOk) == R.success());

    auto resultErr = R.error("bad");
    assert(mapError!(a => a.length)(resultErr) == S.error(3));
    assert(mapError(resultErr) == R.error("bad"));

    const cResultErr = R.error("bad");
    assert(mapError!(a => a.length)(cResultErr) == S.error(3));
    assert(mapError(cResultErr) == R.error("bad"));

    immutable iResultErr = R.error("bad");
    assert(mapError!(a => a.length)(iResultErr) == S.error(3));
    assert(mapError(iResultErr) == R.error("bad"));
}

@safe unittest
{
    alias R = Result!(int*, int);

    auto resultOk = R.success(null);
    assert(mapError!" a + 4"(resultOk) == R.success(null));
    assert(mapError!(a => a + 4)(resultOk) == R.success(null));
    assert(mapError(resultOk) == R.success(null));

    const cResultOk = R.success(null);
    assert(mapError!(a => a + 4)(cResultOk) == R.success(null));
    assert(mapError(cResultOk) == R.success(null));

    immutable iResultOk = R.success(null);
    assert(mapError!(a => a + 4)(iResultOk) == R.success(null));
    assert(mapError(iResultOk) == R.success(null));

    auto resultErr = R.error(9);
    assert(mapError!(a => a + 4)(resultErr) == R.error(13));
    assert(mapError(resultErr) == R.error(9));

    const cResultErr = R.error(9);
    assert(mapError!(a => a + 4)(cResultErr) == R.error(13));
    assert(mapError(cResultErr) == R.error(9));

    immutable iResultErr = R.error(9);
    assert(mapError!(a => a + 4)(iResultErr) == R.error(13));
    assert(mapError(iResultErr) == R.error(9));
}

@safe unittest
{
    alias R = Result!(const(void), int);

    auto resultOk = R.success();
    assert(mapError!" a + 4"(resultOk) == R.success());
    assert(mapError!(a => a + 4)(resultOk) == R.success());
    assert(mapError(resultOk) == R.success());

    const cResultOk = R.success();
    assert(mapError!(a => a + 4)(cResultOk) == R.success());
    assert(mapError(cResultOk) == R.success());

    immutable iResultOk = R.success();
    assert(mapError!(a => a + 4)(iResultOk) == R.success());
    assert(mapError(iResultOk) == R.success());

    auto resultErr = R.error(9);
    assert(mapError!(a => a + 4)(resultErr) == R.error(13));
    assert(mapError(resultErr) == R.error(9));

    const cResultErr = R.error(9);
    assert(mapError!(a => a + 4)(cResultErr) == R.error(13));
    assert(mapError(cResultErr) == R.error(9));

    immutable iResultErr = R.error(9);
    assert(mapError!(a => a + 4)(iResultErr) == R.error(13));
    assert(mapError(iResultErr) == R.error(9));
}

/// Applies a function to the `T` value, or returns a default value for an error.
///
/// If the [Result] has a `T`, applies `fun` to the value and returns the result.
/// If the [Result] has an `E`, returns the default value.
/// The return value of `fun` and the default value must be able to be implicitly converted to some common type.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `auto`
///     `.success(t)`|`fun(t)`
///     `.error(*)`|Default value
/// )
///
/// Params:
///     r = The [Result] to transform
///     fun = The function to apply to the `T` value,
///     defaultValue = The fallback value to be used if an error
///
/// Returns: The result of applying `fun` to the `T` value, or `defaultValue`
@CorrespondingTo("rust", "map_or")
@CorrespondingTo("rust", "map_or_default")
auto mapOr(alias fun, T, U, E)(scope auto ref inout(Result!(T, E)) r,
        U defaultValue = typeof(unaryFun!fun(inout(T).init)).init) if (!is(T : void))
{
    return isSuccess(r) ? unaryFun!fun(unwrap(r)) : defaultValue;
}

///
@safe nothrow unittest
{
    alias R = Result!(string, string);

    auto resultOk = R.success("foo");
    assert(mapOr!"a.length"(resultOk, 42) == 3);

    auto resultErr = R.error("bar");
    assert(mapOr!"a.length"(resultErr, 42) == 42);
}

/// Using default parameter
@safe nothrow unittest
{
    alias R = Result!(string, string);

    auto resultOk = R.success("foo");
    assert(mapOr!"a.length"(resultOk) == 3);

    auto resultErr = R.error("bar");
    assert(mapOr!"a.length"(resultErr) == 0);
}

@safe nothrow unittest
{
    bool isOdd(int x)
    {
        return x % 2 == 1;
    }

    alias R = Result!(int, string);

    auto resultOk = R.success(33);
    assert(mapOr!isOdd(resultOk, -1) == 1);
    assert(mapOr!"a%5"(resultOk) == 3);

    const cResultOk = R.success(33);
    assert(mapOr!isOdd(cResultOk, -1) == 1);
    assert(mapOr!"a%5"(cResultOk) == 3);

    immutable iResultOk = R.success(33);
    assert(mapOr!isOdd(iResultOk, -1) == 1);
    assert(mapOr!"a%5"(iResultOk) == 3);

    auto resultErr = R.error("33");
    assert(mapOr!isOdd(resultErr, -1) == -1);
    assert(mapOr!"a%5"(resultErr) == 0);

    const cResultErr = R.error("33");
    assert(mapOr!isOdd(cResultErr, -1) == -1);
    assert(mapOr!"a%5"(cResultErr) == 0);

    immutable iResultErr = R.error("33");
    assert(mapOr!isOdd(iResultErr, -1) == -1);
    assert(mapOr!"a%5"(iResultErr) == 0);
}

/// Applies fallback and transform functions to `E` and `T` values respectively.
///
/// If the [Result] has a `T`, applies `fun` to the value and returns the result.
/// If the [Result] has an `E`, applies `defaultFun` to the value and returns the result.
/// The return values of `defaultFun` and `fun` must be able to be implicitly converted to some common type.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `auto`
///     `.success(t)`|`fun(t)`
///     `.error(e)`|`defaultFun(e)`
/// )
///
/// Params:
///     r = The [Result] to transform
///     defaultFun = The function to apply to the `E` value
///     fun = The function to apply to the `T` value
///
/// Returns: The result of applying the appropriate function based on `T` or `E`
@CorrespondingTo("rust", "map_or_else")
auto mapOrElse(alias defaultFun, alias fun, T, E)(scope auto ref inout(Result!(T, E)) r)
        if (!is(T : void) && !is(CommonType!(typeof(unaryFun!defaultFun(inout(E)
            .init)), typeof(unaryFun!fun(inout(T).init))) : void))
{
    return isSuccess(r) ? unaryFun!fun(unwrap(r)) : unaryFun!defaultFun(unwrapError(r));
}

///
@safe nothrow unittest
{
    alias R = Result!(string, string);
    immutable k = 21;

    auto resultOk = R.success("foo");
    assert(mapOrElse!(_ => k * 2, "a.length")(resultOk) == 3);

    auto resultErr = R.error("bar");
    assert(mapOrElse!(_ => k * 2, "a.length")(resultErr) == 42);
}

@safe nothrow unittest
{
    bool isPos(int x)
    {
        return x > 0;
    }

    size_t getLength(string x)
    {
        return x.length;
    }

    alias R = Result!(int, string);

    auto resultOk = R.success(33);
    assert(mapOrElse!(getLength, isPos)(resultOk) == 1);

    const cResultOk = R.success(33);
    assert(mapOrElse!(getLength, isPos)(cResultOk) == 1);

    immutable iResultOk = R.success(33);
    assert(mapOrElse!(getLength, isPos)(iResultOk) == 1);

    auto resultErr = R.error("33");
    assert(mapOrElse!(getLength, isPos)(resultErr) == 2);

    const cResultErr = R.error("33");
    assert(mapOrElse!(getLength, isPos)(cResultErr) == 2);

    immutable iResultErr = R.error("33");
    assert(mapOrElse!(getLength, isPos)(iResultErr) == 2);
}

/// Invokes a function with the `T` value of a [Result] without changing the result.
///
/// If the [Result] contains a `T` value, `fun` is called with the value.
/// The original [Result] is returned unchanged, which is useful for peeking the value during chaining.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `Result!(T, E)`
///     Any `r`|`r`
/// )
///
/// Params:
///     r = The [Result] to inspect
///     fun = The function to apply to the `T` value
///
/// Returns: The original [Result]
@CorrespondingTo("rust", "inspect")
auto ref inout(Result!(T, E)) inspect(alias fun, T, E)(scope auto ref inout(Result!(T, E)) r)
        if ((!is(T : void) && is(typeof(unaryFun!fun(inout(T).init)))) || (is(T
            : void) && is(typeof(fun()))))
{
    if (isSuccess(r))
    {
        static if (is(T : void))
        {
            fun();
        }
        else
        {
            unaryFun!fun(unwrap(r));
        }
    }
    return r;
}

///
@safe unittest
{
    auto parse(string s)
    {
        alias R = Result!(ubyte, string);

        try
        {
            import std.conv : to;

            return R.success(to!ubyte(s));
        }
        catch (Exception _)
        {
            return R.error(s);
        }
    }

    import std.array : appender;
    import std.conv : writeText;

    auto writer = appender!string();
    immutable x = parse("4").inspect!(x => writer.writeText("original: ", x))
        .map!"a^^3"
        .tryUnwrap("failed to parse number");
    assert(x == 64);
    assert(writer[] == "original: 4");
}

///
@safe unittest
{
    auto isParsable(string s)
    {
        alias R = Result!(void, string);

        try
        {
            import std.conv : to;

            to!ubyte(s);
            return R.success();
        }
        catch (Exception _)
        {
            return R.error(s);
        }
    }

    import std.array : appender;
    import std.conv : writeText;

    auto writer = appender!string();
    assert(isParsable("4").inspect!(() => writer.writeText("success")).isSuccess());
    assert(writer[] == "success");
}

@safe unittest
{
    alias R = Result!(int, string);

    import std.array : appender;
    import std.conv : writeText;

    auto writer1 = appender!string();
    auto okResult = R.success(42).inspect!(x => writer1.writeText("value: ", x));
    assert(okResult == R.success(42));
    assert(writer1[] == "value: 42");

    auto writer2 = appender!string();
    auto errResult = R.error("bad").inspect!(x => writer2.writeText("value: ", x));
    assert(errResult == R.error("bad"));
    assert(writer2.length == 0);
}

@safe unittest
{
    alias R = Result!(void, string);

    import std.array : appender;
    import std.conv : writeText;

    auto writer1 = appender!string();
    assert(R.success().inspect!(() => writer1.writeText("ok")).isSuccess());
    assert(writer1[] == "ok");

    auto writer2 = appender!string();
    auto errResult = R.error("bad").inspect!(() => writer2.writeText("no"));
    assert(errResult == R.error("bad"));
    assert(writer2.length == 0);
}

/// Invokes a function with the `E` value of a [Result] without changing the result.
///
/// If the [Result] contains an `E` value, `fun` is called with the value.
/// The original [Result] is returned unchanged, which is useful for peeking the value during chaining.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `Result!(T, E)`
///     Any `r`|`r`
/// )
///
/// Params:
///     r = The [Result] to inspect
///     fun = The function to apply to the `E` value
///
/// Returns: The original [Result]
@CorrespondingTo("rust", "inspect_err")
auto ref inout(Result!(T, E)) inspectError(alias fun, T, E)(scope auto ref inout(Result!(T, E)) r)
        if (is(typeof(unaryFun!fun(inout(E).init))))
{
    if (isError(r))
    {
        unaryFun!fun(unwrapError(r));
    }
    return r;
}

///
@safe nothrow unittest
{
    auto readToString(string path)
    {
        alias R = Result!(string, string);
        try
        {
            import std.file : readText;

            return R.success(readText(path));
        }
        catch (Exception e)
        {
            return R.error(e.msg);
        }
    }

    import std.array : appender;
    import std.conv : writeText;

    auto writer = appender!string();
    auto r = inspectError!(e => writer.writeText("failed to read file: ", e))(
            readToString("address.txt"));

    assert(isSuccess(r) || writer[].length > 0);
}

@safe unittest
{
    alias R = Result!(int, string);

    import std.array : appender;
    import std.conv : writeText;

    auto writer1 = appender!string();
    auto okResult = R.success(42).inspectError!(e => writer1.writeText("error: ", e));
    assert(okResult == R.success(42));
    assert(writer1.length == 0);

    auto writer2 = appender!string();
    auto errResult = R.error("fail").inspectError!(e => writer2.writeText("error: ", e));
    assert(errResult == R.error("fail"));
    assert(writer2[] == "error: fail");
}

@safe unittest
{
    alias R = Result!(void, string);

    import std.array : appender;
    import std.conv : writeText;

    auto writer1 = appender!string();
    assert(R.success().inspectError!(e => writer1.writeText("error: ", e)).isSuccess());
    assert(writer1.length == 0);

    auto writer2 = appender!string();
    auto errResult = R.error("fail").inspectError!(e => writer2.writeText("error: ", e));
    assert(errResult == R.error("fail"));
    assert(writer2[] == "error: fail");
}

/// Converts a [Result] that can hold a nullable `T` value into a nullable [Result].
///
/// If the [Result] has a `Nullable!T`, returns a nullable [Result]`!(T, E)` containing
/// the same `T` value when it is non-null, or the null state otherwise.
/// If the [Result] has an `E`, returns a nullable [Result] containing the value.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(Nullable!T, E)`|Output: `Nullable!(Result!(T, E))`
///     `.success(n)`, n is non-null|`Result!(T, E).success(n.get)`
///     `.success(n)`, n is null|null state
///     `.error(e)`|`Result!(T, E).error(e)`
/// )
///
/// Params:
///     r = The [Result] containing either a `Nullable!T` or an `E`.
///
/// Returns: A `Nullable!Result!(T, E)` with the `T` value obtained from the `Nullable!T` or the `E` value
@CorrespondingTo("rust", "transpose")
inout(Nullable!(Result!(T, E))) transpose(T, E)(scope auto ref inout(Result!(Nullable!T, E)) r)
        if (!is(T : void))
{
    alias R = Result!(T, E);
    alias N = inout(Nullable!R);
    if (isError(r))
    {
        return N(R.error(unwrapError(r)));
    }
    inout t = unwrap(r);
    return t.isNull ? N.init : N(R.success(t.get));
}

///
@safe @nogc nothrow unittest
{
    struct SomeErr
    {
    }

    import std.typecons : Nullable, nullable;

    alias R = Result!(Nullable!int, SomeErr);
    alias S = Result!(int, SomeErr);

    auto x = R.success(nullable(5));
    auto y = nullable(S.success(5));
    assert(transpose(x) == y);
}

unittest
{
    alias M = Nullable!Exception;
    alias R = Result!(M, int);
    alias S = Result!(Exception, int);
    alias N = Nullable!S;
    import std.typecons : nullable;

    auto resultOk = R.success(nullable(new Exception("foo")));
    auto nullableOk = nullable(S.success(new Exception("foo")));
    assert(transpose(resultOk).get.unwrap.msg == nullableOk.get.unwrap.msg);

    const cResultOk = R.success(nullable(new Exception("foo")));
    const cNullableOk = nullable(S.success(new Exception("foo")));
    assert(transpose(cResultOk).get.unwrap.msg == cNullableOk.get.unwrap.msg);

    immutable iResultOk = R.success(nullable(new Exception("foo")));
    immutable iNullableOk = nullable(S.success(new Exception("foo")));
    assert(transpose(iResultOk).get.unwrap.msg == iNullableOk.get.unwrap.msg);

    auto resultOkNull = R.success(M.init);
    assert(transpose(resultOkNull).isNull);

    const cResultOkNull = R.success(M.init);
    assert(transpose(cResultOkNull).isNull);

    immutable iResultOkNull = R.success(M.init);
    assert(transpose(iResultOkNull).isNull);

    auto resultErr = R.error(-999);
    auto nullableErr = nullable(S.error(-999));
    assert(transpose(resultErr) == nullableErr);

    const cResultErr = R.error(-999);
    const cNullableErr = nullable(S.error(-999));
    assert(transpose(cResultErr) == cNullableErr);

    immutable iResultErr = R.error(-999);
    immutable iNullableErr = nullable(S.error(-999));
    assert(transpose(iResultErr) == iNullableErr);
}

/// Flattens a nested [Result] by one level.
///
/// Converts [Result]`!(Result!(T, E), E)` into [Result]`!(T, E)`.
/// If the outer [Result] has an inner [Result]`!(T, E)`, returns it.
/// If the outer [Result] has an `E`, returns a new [Result]`!(T, E)` with the value.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(Result!(T, E), E)`|Output: `Result!(T, E)`
///     `.success(inner)`|`inner`
///     `.error(e)`|`.error(e)`
/// )
///
/// Params:
///     r = The nested [Result] to flatten
///
/// Returns: A flattened [Result] with the inner [Result] or the `E` value
@CorrespondingTo("rust", "flatten")
inout(Result!(T, E)) flatten(T, E)(scope auto ref inout(Result!(Result!(T, E), E)) r)
{
    return isSuccess(r) ? unwrap(r) : Result!(T, E).error(unwrapError(r));
}

///
@safe @nogc nothrow unittest
{
    alias R1 = Result!(string, uint);
    alias R2 = Result!(R1, uint);

    auto result1 = R2.success(R1.success("hello"));
    assert(flatten(result1) == R1.success("hello"));

    auto result2 = R2.success(R1.error(6));
    assert(flatten(result2) == R1.error(6));

    auto result3 = R2.error(6);
    assert(flatten(result3) == R1.error(6));
}

///
@safe @nogc nothrow unittest
{
    alias R1 = Result!(string, uint);
    alias R2 = Result!(R1, uint);
    alias R3 = Result!(R2, uint);

    auto result = R3.success(R2.success(R1.success("hello")));
    assert(flatten(result) == R2.success(R1.success("hello")));
    assert(flatten(flatten(result)) == R1.success("hello"));
}

@safe @nogc nothrow unittest
{
    alias R1 = Result!(int, string);
    alias R2 = Result!(R1, string);

    auto outerOk = R2.success(R1.error("inner failure"));
    assert(flatten(outerOk) == R1.error("inner failure"));

    auto outerErr = R2.error("outer failure");
    assert(flatten(outerErr) == R1.error("outer failure"));
}
