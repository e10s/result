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
                return R.err("Value must be a positive integer");
            }
            return R.ok(value);
        }
        catch (ConvException e)
        {
            return R.err("Invalid input: " ~ e.msg);
        }
    }

    // Perform division and return a Result that reports division-by-zero errors.
    auto divide(int numerator, int denominator)
    {
        alias R = Result!(double, string);

        if (denominator == 0)
        {
            return R.err("Division by zero");
        }
        return R.ok(cast(double) numerator / denominator);
    }

    // Convert a lazy expression into a Result value by catching any thrown exception.
    auto convertExceptionToResult(T)(lazy T expr)
    {
        alias R = Result!(T, Exception);

        try
        {
            return R.ok(expr);
        }
        catch (Exception e)
        {
            return R.err(e);
        }
    }

    // A simple demo showing success and failure handling in a procedural style.
    void showBasicFlow()
    {
        // Result!(int, string), success
        immutable parseResult = parsePositiveInt("42");

        if (isErr(parseResult))
        {
            stderr.writeln("Error: ", unwrapErr(parseResult));
            return;
        }

        // Result!(double, string), success
        immutable divideResult = divide(unwrap(parseResult), 7);

        if (isErr(divideResult))
        {
            stderr.writeln("Error: ", unwrapErr(divideResult));
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
import std.traits : CommonType, Unqual;

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
/// Raised by [tryUnwrap] and [tryUnwrapErr].
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
struct Result(T, E) if (!is(T : Err!(E), E) && !is(E : void))
{
    static if (is(T : void))
    {
        /// The payload to switch states and contain values.
        Nullable!E payload;

        // The constructor accepts `E` values.
        private this(inout(E) error) inout
        {
            payload = error;
        }
        // Ditto
        private this(ref inout(E) error) inout
        {
            payload = error;
        }

        /// Creates a [Result]`!(T, E)` with the successful state.
        ///
        /// Returns: A new [Result]`!(T, E)` containing the successful state
        static Result!(T, E) ok()
        {
            return Result!(T, E)();
        }

        version (D_Ddoc)
        {
            ///
            unittest
            {
                auto r = Result!(void, string).ok();
                assert(is(typeof(r) == Result!(void, string)));
            }
        }
    }
    else
    {
        import std.sumtype : SumType;

        /// The payload to switch states and contain values.
        SumType!(T, Err!E) payload;

        // The constructor accepts `T` and `Err!E` values.
        private this(SumTypePayload)(auto ref inout(SumTypePayload) value) inout
                if (is(SumTypePayload == T) || is(SumTypePayload == Err!E))
        {
            payload = value;
        }

        /// Creates a [Result]`!(T, E)` with a successful `T` _value.
        ///
        /// Params:
        ///     value = The success _value to wrap
        ///
        /// Returns: A new [Result]`!(T, E)` containing the `T` _value
        static auto ok(inout(T) value)
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
                auto r = Result!(int, string).ok(100);
                assert(is(typeof(r) == Result!(int, string)));

                auto immutableR = Result!(int, string).ok(immutable(int)(200));
                auto constR = Result!(int, string).ok(const(int)(300));

                // The obtained Results are automatically qualified according to the arguments
                assert(is(typeof(immutableR) == immutable(Result!(int, string))));
                assert(is(typeof(constR) == const(Result!(int, string))));
            }
        }
    }

    alias payload this;

    /// Creates a [Result]`!(T, E)` with an _error `E` value.
    ///
    /// Params:
    ///     error = The _error value to wrap
    ///
    /// Returns: A new [Result]`!(T, E)` containing the `E` value
    static auto err(inout(E) error)
    {
        static if (is(inout(E) == E))
        {
            alias R = Result!(T, E);
        }
        else
        {
            alias R = inout(Result!(T, E));
        }

        static if (is(T : void))
        {
            return R(error);
        }
        else
        {
            static if (is(inout(E) == E))
            {
                alias ErrE = Err!E;
            }
            else
            {
                alias ErrE = inout(Err!E);
            }
            return R(ErrE(error));
        }
    }

    version (D_Ddoc)
    {
        ///
        unittest
        {
            auto r1 = Result!(int, string).err("BAD");
            assert(is(typeof(r1) == Result!(int, string)));
            auto r2 = Result!(void, string).err("BAD");
            assert(is(typeof(r2) == Result!(void, string)));

            auto immutableR = Result!(int, string).err(cast(immutable) "Immutable BAD");
            auto constR = Result!(void, string).err(cast(const) "Const BAD");

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

    auto resultOk = R.ok(123);
    assert(resultOk.get!int == 123);

    const cResultOk = R.ok(123);
    assert(cResultOk.get!(const(int)) == 123);

    immutable iResultOk = R.ok(123);
    assert(iResultOk.get!(immutable(int)) == 123);

    auto resultErr = R.err("123");
    assert(resultErr.get!(Err!string) == Err!string("123"));

    const cResultErr = R.err("123");
    assert(cResultErr.get!(const(Err!string)) == Err!string("123"));

    immutable iResultErr = R.err("123");
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

    auto resultOk = R.ok(new Exception(""));
    assert(resultOk.has!Exception);

    const cResultOk = R.ok(new Exception(""));
    assert(cResultOk.has!(const(Exception)));

    immutable iResultOk = R.ok(new Exception(""));
    assert(iResultOk.has!(immutable(Exception)));

    auto resultErr = R.err(new S);
    assert(resultErr.has!(Err!(S*)));

    const cResultErr = R.err(new S);
    assert(cResultErr.has!(const(Err!(S*))));

    immutable iResultErr = R.err(new S);
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

    auto resultOk = R.ok(new Exception(""));
    assert(resultOk.has!T);

    auto cResultOk = R.ok(new const(Exception)(""));
    assert(cResultOk.has!(const(T)));

    auto iResultOk = R.ok(new immutable(Exception)(""));
    assert(iResultOk.has!(immutable(T)));

    auto resultErr = R.err(new S);
    assert(resultErr.has!(Err!E));

    auto cResultErr = R.err(new const(S));
    assert(cResultErr.has!(Err!E));

    auto iResultErr = R.err(new immutable(S));
    assert(iResultErr.has!(Err!E));
}

// Assignment
@trusted @nogc nothrow unittest
{
    alias R = Result!(int, string);

    import std.sumtype : get;

    auto result1 = R.err("333");
    auto result2 = R.err("3");

    result2 = result1;
    assert(result2.get!(Err!string) == Err!string("333"));

    const result3 = R.ok(100);
    result2 = result3;
    assert(result2.get!int == 100);

    immutable result4 = R.err("1000");
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
    auto result1 = R.err(s1);
    auto result2 = R.err(s2);

    result2 = result1;
    assert(result2.get!(Err!(S*)) == Err!(S*)(s1));

    auto k1 = new Exception("!!!");
    auto result3 = R.ok(k1);

    result2 = result3;
    assert(result2.get!Exception == k1);
}
/* Tests for non-void T end */

/* Tests for void T begin */
// Factory method
@safe @nogc nothrow unittest
{
    alias R = Result!(void, string);

    auto resultOk = R.ok();
    assert(resultOk.isNull);

    const cResultOk = R.ok();
    assert(cResultOk.isNull);

    immutable iResultOk = R.ok();
    assert(iResultOk.isNull);

    auto resultErr = R.err("123");
    assert(resultErr.get == "123");

    const cResultErr = R.err("123");
    assert(cResultErr.get == "123");

    immutable iResultErr = R.err("123");
    assert(iResultErr.get == "123");
}
// Ditto
@safe nothrow unittest
{
    struct S
    {
    }

    alias R = Result!(void, S*);

    auto resultOk = R.ok();
    assert(resultOk.isNull);

    const cResultOk = R.ok();
    assert(cResultOk.isNull);

    immutable iResultOk = R.ok();
    assert(iResultOk.isNull);

    auto resultErr = R.err(new S);
    assert(is(typeof(resultErr.get()) == S*));

    const cResultErr = R.err(new S);
    assert(is(typeof(cResultErr.get()) == const(S*)));

    immutable iResultErr = R.err(new S);
    assert(is(typeof(iResultErr.get()) == immutable(S*)));
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

    auto resultErr = R.err(new S);
    assert(is(typeof(resultErr.get()) == E));

    auto cResultErr = R.err(new const(S));
    assert(is(typeof(cResultErr.get()) == E));

    auto iResultErr = R.err(new immutable(S));
    assert(is(typeof(iResultErr.get()) == E));
}

// Assignment
@trusted @nogc nothrow unittest
{
    alias R = Result!(void, string);

    auto result1 = R.err("333");
    auto result2 = R.err("3");

    result2 = result1;
    assert(result2.get == "333");

    const result3 = R.ok();
    result2 = result3;
    assert(result2.isNull);

    immutable result4 = R.err("1000");
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
    auto result1 = R.err(s1);
    auto result2 = R.err(s2);

    result2 = result1;
    assert(result2.get == s1);

    auto result3 = R.ok();

    result2 = result3;
    assert(result2.isNull);
}
/* Tests for void T end */

/* Convenience templates begin */
private enum bool isResult(R) = is(R : Result!(T, E), T, E);

unittest
{
    alias R = Result!(int, string);
    assert(isResult!R);
    assert(isResult!(const(R)));
    assert(isResult!(immutable(R)));
    assert(isResult!(shared(R)));
    assert(isResult!(inout(R)));
}

private enum bool isResultVoidT(R) = is(R : Result!(T, E), T:
            void, E);
unittest
{
    alias R = Result!(int, string);
    assert(!isResultVoidT!R);
    assert(!isResultVoidT!(const(R)));
    assert(!isResultVoidT!(immutable(R)));
    assert(!isResultVoidT!(shared(R)));
    assert(!isResultVoidT!(inout(R)));

    assert(isResultVoidT!(Result!(void, string)));
    assert(isResultVoidT!(Result!(const(void), string)));
    assert(isResultVoidT!(Result!(immutable(void), string)));
    assert(isResultVoidT!(Result!(shared(void), string)));
    assert(isResultVoidT!(Result!(inout(void), string)));
}

private alias OkValueTypeOf(R : Result!(T, E), T, E) = T;

unittest
{
    alias R = Result!(int, string);
    assert(is(OkValueTypeOf!R == int));
    assert(is(OkValueTypeOf!(const(R)) == int));
    assert(is(OkValueTypeOf!(immutable(R)) == int));
    assert(is(OkValueTypeOf!(inout(R)) == int));
}

unittest
{
    alias R = Result!(const(void), string);

    assert(is(OkValueTypeOf!R == const(void)));
    assert(is(OkValueTypeOf!(const(R)) == const(void)));
    assert(is(OkValueTypeOf!(immutable(R)) == const(void)));
    assert(is(OkValueTypeOf!(inout(R)) == const(void)));
}

private template ErrTypeOf(R) if (isResult!R && !isResultVoidT!R)
{
    alias ErrTypeOf = typeof(R.payload).Types[1];
}

unittest
{
    alias R = Result!(int, string);
    assert(is(ErrTypeOf!R == Err!string));
    assert(is(ErrTypeOf!(const(R)) == Err!string));
    assert(is(ErrTypeOf!(immutable(R)) == Err!string));
    assert(is(ErrTypeOf!(inout(R)) == Err!string));
}

private template QualifiedErrTypeOf(R) if (isResult!R && !isResultVoidT!R)
{
    import std.traits : CopyTypeQualifiers;

    alias QualifiedErrTypeOf = CopyTypeQualifiers!(R, ErrTypeOf!R);
}

unittest
{
    alias R = Result!(int, string);
    assert(is(QualifiedErrTypeOf!R == Err!string));
    assert(is(QualifiedErrTypeOf!(const(R)) == const(Err!string)));
    assert(is(QualifiedErrTypeOf!(immutable(R)) == immutable(Err!string)));
    assert(is(QualifiedErrTypeOf!(inout(R)) == inout(Err!string)));
}

private alias ErrValueTypeOf(R : Result!(T, E), T, E) = E;

unittest
{
    alias R = Result!(int, string);
    assert(is(ErrValueTypeOf!R == string));
    assert(is(ErrValueTypeOf!(const(R)) == string));
    assert(is(ErrValueTypeOf!(immutable(R)) == string));
    assert(is(ErrValueTypeOf!(inout(R)) == string));
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
///     `.ok(*)`|`true`
///     `.err(*)`|`false`
/// )
///
/// Params:
///     r = The [Result] to check
///
/// Returns: `true` if `r` contains a successful state, `false` otherwise
@CorrespondingTo("rust", "is_ok")
@CorrespondingTo("c++", "has_value")
bool isOk(T, E)(scope auto ref inout(Result!(T, E)) r)
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

    auto resultOk = R.ok(-3);
    assert(isOk(resultOk));

    auto resultErr = R.err("Some error message");
    assert(!isOk(resultErr));
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(void, string);

    auto resultOk = R.ok();
    assert(isOk(resultOk));

    auto resultErr = R.err("Some error message");
    assert(!isOk(resultErr));
}

@safe @nogc nothrow unittest
{
    alias R = Result!(int, string);

    const cResultOk = R.ok(123);
    assert(isOk(cResultOk));

    immutable iResultOk = R.ok(123);
    assert(isOk(iResultOk));

    const cResultErr = R.err("123");
    assert(!isOk(cResultErr));

    immutable iResultErr = R.err("123");
    assert(!isOk(iResultErr));
}

@safe @nogc nothrow unittest
{
    alias R = Result!(immutable(void), string);

    const cResultOk = R.ok();
    assert(isOk(cResultOk));

    immutable iResultOk = R.ok();
    assert(isOk(iResultOk));

    const cResultErr = R.err("123");
    assert(!isOk(cResultErr));

    immutable iResultErr = R.err("123");
    assert(!isOk(iResultErr));
}

/// Checks if a [Result] contains a `T` value satisfying a predicate.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `bool`
///     `.ok(t)`|`pred(t)`
///     `.err(*)`|`false`
/// )
///
/// Params:
///     r = The [Result] to check
///     pred = The predicate to apply to the `T` value
///
/// Returns: `true` if `r` has a `T` value and it satisfies `pred`, `false` otherwise
@CorrespondingTo("rust", "is_ok_and")
bool isOkAnd(alias pred = "a", T, E)(scope auto ref inout(Result!(T, E)) r)
        if (!is(T : void) && !is(typeof(unaryFun!pred(inout(T).init)) : void))
{
    return isOk(r) && !!unaryFun!pred(unwrap(r));
}

///
@safe nothrow unittest
{
    alias R = Result!(uint, string);

    auto resultOk1 = R.ok(2);
    assert(isOkAnd!(a => a > 1)(resultOk1) == true);

    auto resultOk2 = R.ok(0);
    assert(isOkAnd!"a>1"(resultOk2) == false);

    auto resultErr = R.err("hey");
    assert(isOkAnd!"a>1"(resultErr) == false);
}

@safe nothrow unittest
{
    size_t isOdd(int n)
    {
        return n & 1;
    }

    alias R = Result!(int, string);

    auto resultOk = R.ok(123);
    assert(isOkAnd!isOdd(resultOk));

    const cResultOk = R.ok(123);
    assert(isOkAnd!isOdd(cResultOk));

    immutable iResultOk = R.ok(123);
    assert(isOkAnd!isOdd(iResultOk));

    auto resultErr = R.err("123");
    assert(!isOkAnd!isOdd(resultErr));

    const cResultErr = R.err("123");
    assert(!isOkAnd!isOdd(cResultErr));

    immutable iResultErr = R.err("123");
    assert(!isOkAnd!isOdd(iResultErr));
}

/// Checks if a [Result] contains an error.
/// Equivalent to `!`[isOk]`(r)`.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `bool`
///     `.ok(*)`|`false`
///     `.err(*)`|`true`
/// )
@CorrespondingTo("rust", "is_err")
alias isErr = not!isOk;

///
@safe @nogc nothrow unittest
{
    alias R = Result!(int, string);

    auto resultOk = R.ok(-3);
    assert(!isErr(resultOk));

    auto resultErr = R.err("Some error message");
    assert(isErr(resultErr));
}

@safe @nogc nothrow unittest
{
    alias R = Result!(int, string);

    const cResultErr = R.err("123");
    assert(isErr(cResultErr));

    immutable iResultErr = R.err("123");
    assert(isErr(iResultErr));

    auto resultOk = R.ok(123);
    assert(!isErr(resultOk));

    const cResultOk = R.ok(123);
    assert(!isErr(cResultOk));

    immutable iResultOk = R.ok(123);
    assert(!isErr(iResultOk));
}

/// Checks if a [Result] contains an error satisfying a predicate.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `bool`
///     `.ok(*)`|`false`
///     `.err(e)`|`pred(e)`
/// )
///
/// Params:
///     r = The [Result] to check
///     pred = The predicate to apply to the `E` value
///
/// Returns: `true` if `r` has an error and it satisfies `pred`, `false` otherwise
@CorrespondingTo("rust", "is_err_and")
bool isErrAnd(alias pred = "a", T, E)(scope auto ref inout(Result!(T, E)) r)
        if (!is(typeof(unaryFun!pred(inout(E).init)) : void))
{
    return isErr(r) && !!unaryFun!pred(unwrapErr(r));
}

///
@safe nothrow unittest
{
    alias R = Result!(uint, string);

    auto resultErr1 = R.err("!!!");
    assert(isErrAnd!(e => e == "!!!")(resultErr1) == true);

    auto resultErr2 = R.err("?");
    assert(isErrAnd!`a=="!!!"`(resultErr2) == false);

    auto resultOk = R.ok(123);
    assert(isErrAnd!`a=="!!!"`(resultOk) == false);
}

@safe nothrow unittest
{
    import std.string : isNumeric;

    alias R = Result!(int, string);

    auto resultOk = R.ok(123);
    assert(!isErrAnd!isNumeric(resultOk));

    const cResultOk = R.ok(123);
    assert(!isErrAnd!isNumeric(cResultOk));

    immutable iResultOk = R.ok(123);
    assert(!isErrAnd!isNumeric(iResultOk));

    auto resultErr = R.err("123");
    assert(isErrAnd!isNumeric(resultErr));

    const cResultErr = R.err("123");
    assert(isErrAnd!isNumeric(cResultErr));

    immutable iResultErr = R.err("123");
    assert(isErrAnd!isNumeric(iResultErr));

    auto resultErr2 = R.err("Good morning, 007.");
    assert(!isErrAnd!isNumeric(resultErr2));
}

/// Extracts the `T` value from a [Result] as a `Nullable!T`.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `Nullable!T`
///     `.ok(t)`|`t`
///     `.err(*)`|null state
/// )
///
/// Params:
///     r = The [Result] to extract from
///
/// Returns: A `Nullable!T` containing the `T` value, or in the null state if an `E`
@CorrespondingTo("rust", "ok")
inout(Nullable!T) ok(T, E)(scope auto ref inout(Result!(T, E)) r) if (!is(T : void))
{
    alias N = typeof(return);
    return isErr(r) ? N.init : N(unwrap(r));
}

///
@safe nothrow unittest
{
    alias R = Result!(uint, string);

    import std.typecons : Nullable;

    auto resultOk = R.ok(2);
    assert(ok(resultOk) == Nullable!uint(2));

    auto resultErr = R.err("Nothing here");
    assert(ok(resultErr).isNull);
}

@safe nothrow unittest
{
    alias R = Result!(uint, string);

    const cResultOk = R.ok(2);
    assert(ok(cResultOk) == Nullable!uint(2));

    immutable iResultOk = R.ok(2);
    assert(ok(iResultOk) == Nullable!uint(2));

    const cResultErr = R.err("Nothing here");
    assert(ok(cResultErr).isNull);

    immutable iResultErr = R.err("Nothing here");
    assert(ok(iResultErr).isNull);
}

/// Extracts the error value from a [Result] as a `Nullable!E`.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `Nullable!E`
///     `.ok(*)`|null state
///     `.err(e)`|`e`
/// )
///
/// Params:
///     r = The [Result] to extract from
///
/// Returns: A `Nullable!E` containing the `E` value, in the null state if a `T`
@CorrespondingTo("rust", "err")
inout(Nullable!E) err(T, E)(scope auto ref inout(Result!(T, E)) r)
{
    static if (is(T : void))
    {
        return r.payload;
    }
    else
    {
        alias N = typeof(return);
        return isOk(r) ? N.init : N(unwrapErr(r));
    }
}

///
@safe nothrow unittest
{
    alias R = Result!(uint, string);

    import std.typecons : Nullable;

    auto resultOk = R.ok(2);
    assert(err(resultOk).isNull);

    auto resultErr = R.err("Nothing here");
    assert(err(resultErr) == Nullable!string("Nothing here"));
}

///
@safe nothrow unittest
{
    alias R = Result!(void, string);

    import std.typecons : Nullable;

    auto resultOk = R.ok();
    assert(err(resultOk).isNull);

    auto resultErr = R.err("Nothing here");
    assert(err(resultErr) == Nullable!string("Nothing here"));
}

@safe nothrow unittest
{
    alias R = Result!(uint, string);

    const cResultOk = R.ok(2);
    assert(err(cResultOk).isNull);

    immutable iResultOk = R.ok(2);
    assert(err(iResultOk).isNull);

    const cResultErr = R.err("Nothing here");
    assert(err(cResultErr) == Nullable!string("Nothing here"));

    immutable iResultErr = R.err("Nothing here");
    assert(err(iResultErr) == Nullable!string("Nothing here"));
}

@safe nothrow unittest
{
    alias R = Result!(immutable(void), string);

    const cResultOk = R.ok();
    assert(err(cResultOk).isNull);

    immutable iResultOk = R.ok();
    assert(err(iResultOk).isNull);

    const cResultErr = R.err("Nothing here");
    assert(err(cResultErr) == Nullable!string("Nothing here"));

    immutable iResultErr = R.err("Nothing here");
    assert(err(iResultErr) == Nullable!string("Nothing here"));
}

/// Chains two [Result]s, returning the second if the first has a successful state.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input 1: `Result!(T, E)`|Input 2: `Result!(U, E)`|Output: `Result!(U, E)`
///     `.ok(*)`|Any `r2`|`r2`
///     `.err(e)`|Any (ignored)|`.err(e)`
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
    return isOk(r1) ? r2 : Result!(U, E).err(unwrapErr(r1));
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(uint, string);
    alias S = Result!(string, string);

    auto x1 = R.ok(2);
    auto y1 = S.err("late error");
    assert(and(x1, y1) == S.err("late error"));

    auto x2 = R.err("early error");
    auto y2 = S.ok("foo");
    assert(and(x2, y2) == S.err("early error"));

    auto x3 = R.err("not a 2");
    auto y3 = S.err("late error");
    assert(and(x3, y3) == S.err("not a 2"));

    auto x4 = R.ok(2);
    auto y4 = S.ok("different result type");
    assert(and(x4, y4) == S.ok("different result type"));
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(void, string);
    alias S = Result!(string, string);

    auto x1 = R.ok();
    auto y1 = S.err("late error");
    assert(and(x1, y1) == S.err("late error"));

    auto x2 = R.err("early error");
    auto y2 = S.ok("foo");
    assert(and(x2, y2) == S.err("early error"));

    auto x3 = R.err("not a 2");
    auto y3 = S.err("late error");
    assert(and(x3, y3) == S.err("not a 2"));

    auto x4 = R.ok();
    auto y4 = S.ok("different result type");
    assert(and(x4, y4) == S.ok("different result type"));
}

@safe @nogc nothrow unittest
{
    alias R = Result!(uint, string);
    alias S = Result!(const(void), string);

    immutable x1 = R.ok(2);
    auto y1 = S.err("late error");
    assert(and(x1, y1) == S.err("late error"));

    auto x2 = R.err("early error");
    const y2 = S.ok();
    assert(and(x2, y2) == S.err("early error"));

    const x3 = R.err("not a 2");
    immutable y3 = S.err("late error");
    assert(and(x3, y3) == S.err("not a 2"));

    immutable x4 = R.ok(2);
    immutable y4 = S.ok();
    assert(and(x4, y4) == S.ok());
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
///     `.ok(t)`|`fun(t)`
///     `.err(e)`|`.err(e)`
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
        if (!is(T : void) && is(E == ErrValueTypeOf!(typeof(unaryFun!fun(inout(T).init)))))
{
    alias U = OkValueTypeOf!(typeof(unaryFun!fun(inout(T).init)));
    return isOk(r) ? unaryFun!fun(unwrap(r)) : Result!(U, E).err(unwrapErr(r));
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
            .apply!(S.ok)
            .get(S.err("overflowed"));
    }

    assert(andThen!sqThenToString(R.ok(2)) == S.ok("4"));
    assert(andThen!sqThenToString(R.ok(1_000_000)) == S.err("overflowed"));
    assert(andThen!sqThenToString(R.err("not a number")) == S.err("not a number"));
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

            return S.ok(to!int(x));
        }
        catch (Exception e)
        {
            return S.err(typeid(e).toString());
        }
    }

    auto resultOk1 = R.ok(2.3);
    assert(andThen!toInt(resultOk1) == S.ok(2));

    auto resultOk2 = R.ok(float.nan);
    assert(andThen!toInt(resultOk2) == S.err("std.conv.ConvException"));

    auto resultErr = R.err("bad value");
    assert(andThen!toInt(resultErr) == S.err("bad value"));
}

/// Chains two [Result]s, returning the first if the first has a successful state.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input 1: `Result!(T, E)`|Input 2: `Result!(T, F)`|Output: `Result!(T, F)`
///     `.ok(t)`|Any (ignored)|`.ok(t)`
///     `.err(*)`|Any `r2`|`r2`
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
        return isErr(r1) ? r2 : Result!(T, F).ok();
    }
    else
    {
        return isErr(r1) ? r2 : Result!(T, F).ok(unwrap(r1));
    }
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(uint, string);
    alias S = Result!(uint, dstring);

    auto x1 = R.ok(2);
    auto y1 = S.err("late error");
    assert(or(x1, y1) == S.ok(2));

    auto x2 = R.err("early error");
    auto y2 = S.ok(2);
    assert(or(x2, y2) == S.ok(2));

    auto x3 = R.err("not a 2");
    auto y3 = S.err("late error");
    assert(or(x3, y3) == S.err("late error"));

    auto x4 = R.ok(2);
    auto y4 = S.ok(100);
    assert(or(x4, y4) == S.ok(2));
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(void, string);
    alias S = Result!(void, dstring);

    auto x1 = R.ok();
    auto y1 = S.err("late error");
    assert(or(x1, y1) == S.ok());

    auto x2 = R.err("early error");
    auto y2 = S.ok();
    assert(or(x2, y2) == S.ok());

    auto x3 = R.err("not a 2");
    auto y3 = S.err("late error");
    assert(or(x3, y3) == S.err("late error"));

    auto x4 = R.ok();
    auto y4 = S.ok();
    assert(or(x4, y4) == S.ok());
}

@safe @nogc nothrow unittest
{
    alias R = Result!(const(void), string);
    alias S = Result!(const(void), dstring);

    auto x1 = R.ok();
    const y1 = S.err("late error");
    assert(or(x1, y1) == S.ok());

    immutable x2 = R.err("early error");
    const y2 = S.ok();
    assert(or(x2, y2) == S.ok());

    immutable x3 = R.err("not a 2");
    immutable y3 = S.err("late error");
    assert(or(x3, y3) == S.err("late error"));

    const x4 = R.ok();
    const y4 = S.ok();
    assert(or(x4, y4) == S.ok());
}

@safe @nogc nothrow unittest
{
    alias R = Result!(uint, string);
    alias S = Result!(uint, dstring);

    auto x1 = R.ok(2);
    const y1 = S.err("late error");
    assert(or(x1, y1) == S.ok(2));

    immutable x2 = R.err("early error");
    const y2 = S.ok(2);
    assert(or(x2, y2) == S.ok(2));

    immutable x3 = R.err("not a 2");
    immutable y3 = S.err("late error");
    assert(or(x3, y3) == S.err("late error"));

    const x4 = R.ok(2);
    const y4 = S.ok(100);
    assert(or(x4, y4) == S.ok(2));
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
///     `.ok(t)`|`.ok(t)`
///     `.err(e)`|`fun(e)`
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
        if (is(T == OkValueTypeOf!(typeof(unaryFun!fun(inout(E).init)))))
{
    alias F = ErrValueTypeOf!(typeof(unaryFun!fun(inout(E).init)));
    static if (is(T : void))
    {
        return isErr(r) ? unaryFun!fun(unwrapErr(r)) : Result!(T, F).ok();
    }
    else
    {
        return isErr(r) ? unaryFun!fun(unwrapErr(r)) : Result!(T, F).ok(unwrap(r));
    }
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(uint, uint);

    R sq(uint x)
    {
        return R.ok(x * x);
    }

    R err(uint x)
    {
        return R.err(x);
    }

    assert(orElse!sq(orElse!sq(R.ok(2))) == R.ok(2));
    assert(orElse!sq(orElse!err(R.ok(2))) == R.ok(2));
    assert(orElse!err(orElse!sq(R.err(3))) == R.ok(9));
    assert(orElse!err(orElse!err(R.err(3))) == R.err(3));
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(void, uint);

    R forge(uint x)
    {
        return R.ok();
    }

    R err(uint x)
    {
        return R.err(x);
    }

    assert(orElse!forge(orElse!forge(R.ok())) == R.ok());
    assert(orElse!forge(orElse!err(R.ok())) == R.ok());
    assert(orElse!err(orElse!forge(R.err(3))) == R.ok());
    assert(orElse!err(orElse!err(R.err(3))) == R.err(3));
}

@safe @nogc nothrow unittest
{
    alias R = Result!(bool, string);
    alias S = Result!(bool, size_t);

    S isEmpty(string x)
    {
        if (x.length > 0)
        {
            return S.err(x.length);
        }

        return S.ok(true);
    }

    auto resultOk = R.ok(false);
    assert(orElse!isEmpty(resultOk) == S.ok(false));

    auto resultErr1 = R.err("");
    assert(orElse!isEmpty(resultErr1) == S.ok(true));

    auto resultErr2 = R.err("too long string");
    assert(orElse!isEmpty(resultErr2) == S.err(15));
}

/// Extracts the `T` value from a [Result].
///
/// The [Result] must contain a successful state. Use [isOk] to check.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `T`
///     `.ok(t)`|`t`
///     `.err(*)`|Undefined
/// )
///
/// Params:
///     r = The [Result] to unwrap
///
/// Returns: The contained `T` value, or nothing if `T` is `void`
@CorrespondingTo("rust", "unwrap")
@CorrespondingTo("rust", "unwrap_unchecked")
auto ref inout(T) unwrap(T, E)(scope return auto ref inout(Result!(T, E)) r)
{
    assert(isOk(r), "Result does not have an Ok value.");

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

    auto resultOk = R.ok(2);
    assert(unwrap(resultOk) == 2);

    import std.exception : assertThrown;
    import core.exception : AssertError;

    auto resultErr = R.err("emergency failure");
    assertThrown!AssertError(unwrap(resultErr));
}

///
unittest
{
    alias R = Result!(void, string);

    import std.exception : assertNotThrown, assertThrown;
    import core.exception : AssertError;

    auto resultOk = R.ok();
    assertNotThrown!AssertError(unwrap(resultOk));

    auto resultErr = R.err("emergency failure");
    assertThrown!AssertError(unwrap(resultErr));
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;
    import core.exception : AssertError;

    auto resultOk1 = Result!(immutable(void), string).ok();
    assertNotThrown!AssertError(unwrap(resultOk1));

    alias R = Result!(void, uint);

    auto resultOk2 = R.ok();
    assertNotThrown!AssertError(unwrap(resultOk2));

    auto resultErr = R.err(123);
    assertThrown!AssertError(unwrap(resultErr));
}

/// Extracts the `E` value from a [Result].
///
/// The [Result] must contain an `E` value. Use [isErr] to check.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `E`
///     `.ok(*)`|Undefined
///     `.err(e)`|`e`
/// )
///
/// Params:
///     r = The [Result] to unwrap
///
/// Returns: The contained `E` value
@CorrespondingTo("rust", "unwrap_err")
@CorrespondingTo("rust", "unwrap_err_unchecked")
@CorrespondingTo("c++", "error")
auto ref inout(E) unwrapErr(T, E)(scope return auto ref inout(Result!(T, E)) r)
{
    assert(isErr(r), "Result does not have an error value.");

    static if (is(T : void))
    {
        return r.payload.get();
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

    auto resultOk = R.ok(2);
    assertThrown!AssertError(unwrapErr(resultOk));

    auto resultErr = R.err("emergency failure");
    assert(unwrapErr(resultErr) == "emergency failure");
}

///
unittest
{
    import std.exception : assertThrown;
    import core.exception : AssertError;

    alias R = Result!(void, string);

    auto resultOk = R.ok();
    assertThrown!AssertError(unwrapErr(resultOk));

    auto resultErr = R.err("emergency failure");
    assert(unwrapErr(resultErr) == "emergency failure");
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;
    import core.exception : AssertError;

    auto resultErr1 = Result!(int, string).err("123");
    assert(assertNotThrown!AssertError(unwrapErr(resultErr1)) == "123");

    alias R = Result!(string, uint);

    auto resultErr2 = R.err(123);
    assert(assertNotThrown!AssertError(unwrapErr(resultErr2)) == 123);

    auto resultOk = R.ok("123");
    assertThrown!AssertError(unwrapErr(resultOk));
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;
    import core.exception : AssertError;

    auto resultErr1 = Result!(void, string).err("123");
    assert(assertNotThrown!AssertError(unwrapErr(resultErr1)) == "123");

    alias R = Result!(const(void), uint);

    auto resultErr2 = R.err(123);
    assert(assertNotThrown!AssertError(unwrapErr(resultErr2)) == 123);

    auto resultOk = R.ok();
    assertThrown!AssertError(unwrapErr(resultOk));
}

/// Tries to extract the `T` value from a [Result], with a custom error message.
///
/// If the [Result] has an `E`, an [UnwrapException] is thrown with `msg`.
/// If `msg` is not provided, the default message is used.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `T`
///     `.ok(t)`|`t`
///     `.err(*)`|`UnwrapException` is thrown
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
        enforce!UnwrapException(isOk(r), "Result does not have a successful state.");
    }
    else
    {
        enforce!UnwrapException(isOk(r), msg);
    }
    return unwrap(r);
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    alias R = Result!(uint, string);

    auto resultOk = R.ok(2);
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk, "Testing expect")) == 2);

    auto resultErr = R.err("emergency failure");
    assertThrown!UnwrapException(tryUnwrap(resultErr, "Testing expect"));
    assert(collectExceptionMsg(tryUnwrap(resultErr, "Testing expect")) == "Testing expect");
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    alias R = Result!(void, string);

    auto resultOk = R.ok();
    assertNotThrown!UnwrapException(tryUnwrap(resultOk, "Testing expect"));

    auto resultErr = R.err("emergency failure");
    assertThrown!UnwrapException(tryUnwrap(resultErr, "Testing expect"));
    assert(collectExceptionMsg(tryUnwrap(resultErr, "Testing expect")) == "Testing expect");
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    auto resultOk1 = Result!(int, string).ok(123);
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk1, "foo")) == 123);
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk1)) == 123);

    alias R = Result!(string, uint);

    auto resultOk2 = R.ok("123");
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk2, "foo")) == "123");
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk2)) == "123");

    auto resultErr = R.err(123);
    assertThrown!UnwrapException(tryUnwrap(resultErr, "foo"));
    assert(collectExceptionMsg(tryUnwrap(resultErr, "foo")) == "foo");
    assertThrown!UnwrapException(tryUnwrap(resultErr));
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    auto resultOk1 = Result!(void, string).ok();
    assertNotThrown!UnwrapException(tryUnwrap(resultOk1, "foo"));
    assertNotThrown!UnwrapException(tryUnwrap(resultOk1));

    alias R = Result!(const(void), uint);

    auto resultOk2 = R.ok();
    assertNotThrown!UnwrapException(tryUnwrap(resultOk2, "foo"));
    assertNotThrown!UnwrapException(tryUnwrap(resultOk2));

    auto resultErr = R.err(123);
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
///     `.ok(*)`|`UnwrapException` is thrown
///     `.err(e)`|`e`
/// )
////// Params:
///     r = The [Result] to unwrap
///     msg = The message to include in the exception if [Result] has a successful state
///
/// Returns: The contained `E` value
///
/// Throws: [UnwrapException] with message `msg` if the `r` has a successful state
@CorrespondingTo("rust", "expect_err")
auto ref inout(E) tryUnwrapErr(T, E)(scope return auto ref inout(Result!(T, E)) r,
        lazy string msg = null)
{
    import std.exception : enforce;

    if (msg is null)
    {
        enforce!UnwrapException(isErr(r), "Result does not have an Err value.");
    }
    else
    {
        enforce!UnwrapException(isErr(r), msg);
    }
    return unwrapErr(r);
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    alias R = Result!(uint, string);

    auto resultOk = R.ok(2);
    assertThrown!UnwrapException(tryUnwrapErr(resultOk, "Testing tryUnwrapErr"));
    assert(collectExceptionMsg(tryUnwrapErr(resultOk,
            "Testing tryUnwrapErr")) == "Testing tryUnwrapErr");

    auto resultErr = R.err("emergency failure");
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr,
            "Testing tryUnwrapErr")) == "emergency failure");
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    alias R = Result!(void, string);

    auto resultOk = R.ok();
    assertThrown!UnwrapException(tryUnwrapErr(resultOk, "Testing tryUnwrapErr"));
    assert(collectExceptionMsg(tryUnwrapErr(resultOk,
            "Testing tryUnwrapErr")) == "Testing tryUnwrapErr");

    auto resultErr = R.err("emergency failure");
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr,
            "Testing tryUnwrapErr")) == "emergency failure");
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    auto resultErr1 = Result!(immutable(void), string).err("123");
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr1, "bar")) == "123");
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr1)) == "123");

    alias R = Result!(const(void), uint);

    auto resultErr2 = R.err(123);
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr2, "bar")) == 123);
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr2)) == 123);

    auto resultOk = R.ok();
    assertThrown!UnwrapException(tryUnwrapErr(resultOk, "bar"));
    assert(collectExceptionMsg(tryUnwrapErr(resultOk, "bar")) == "bar");
    assertThrown!UnwrapException(tryUnwrapErr(resultOk));
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    auto resultErr1 = Result!(int, string).err("123");
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr1, "bar")) == "123");
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr1)) == "123");

    alias R = Result!(string, uint);

    auto resultErr2 = R.err(123);
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr2, "bar")) == 123);
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr2)) == 123);

    auto resultOk = R.ok("123");
    assertThrown!UnwrapException(tryUnwrapErr(resultOk, "bar"));
    assert(collectExceptionMsg(tryUnwrapErr(resultOk, "bar")) == "bar");
    assertThrown!UnwrapException(tryUnwrapErr(resultOk));
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
///     `.ok(t)`|`t`
///     `.err(*)`|Default value
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
    return isOk(r) ? unwrap(r) : defaultValue;
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(uint, string);

    immutable defaultValue = 2;

    auto resultOk = R.ok(9);
    assert(unwrapOr(resultOk, defaultValue) == 9);

    auto resultErr = R.err("error");
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

            return R.ok(to!int(s));
        }
        catch (Exception _)
        {
            return R.err(s);
        }
    }

    immutable goodYearFromInput = "1909";
    immutable badYearFromInput = "190blarg";

    assert(unwrapOr(parse(goodYearFromInput)) == 1909);
    assert(unwrapOr(parse(badYearFromInput)) == 0);
}

@safe @nogc nothrow unittest
{
    auto resultOk1 = Result!(int, string).ok(123);
    assert(unwrapOr(resultOk1, 456) == 123);
    assert(unwrapOr(resultOk1) == 123);

    alias R = Result!(string, uint);

    const resultOk2 = R.ok("123");
    assert(unwrapOr(resultOk2, "456") == "123");
    assert(unwrapOr(resultOk2) == "123");

    auto resultErr = R.err(123);
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
///     `.ok(t)`|`t`
///     `.err(e)`|`fun(e)`
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
    return isOk(r) ? unwrap(r) : unaryFun!fun(unwrapErr(r));
}

///
@safe nothrow unittest
{
    alias count = x => x.length;

    alias R = Result!(size_t, string);

    auto resultOk = R.ok(2);
    assert(unwrapOrElse!count(resultOk) == 2);

    auto resultErr = R.err("foo");
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

    auto resultOk1 = Result!(int, string).ok(123);
    assert(unwrapOrElse!"999"(resultOk1) == 123);
    assert(unwrapOrElse!f999(resultOk1) == 123);

    alias R = Result!(string, uint);

    immutable resultOk2 = R.ok("123");
    assert(unwrapOrElse!(to!string)(resultOk2) == "123");
    assert(unwrapOrElse!fFoo(resultOk2) == "123");

    auto resultErr = R.err(123);
    assert(unwrapOrElse!(to!string)(resultErr) == "123");
    assert(unwrapOrElse!"to!string(a+2)"(resultErr) == "125");
    assert(unwrapOrElse!"`foo`"(resultErr) == "foo");
    assert(unwrapOrElse!fFoo(resultErr) == "Foo is 123");
}

/// Extracts the `E` value from a [Result], with a default value for an error.
///
/// If the [Result] has a `T`, returns the default value.
/// If the [Result] has an `E`, returns the value.
/// The `E` value and the default value must be able to be implicitly converted to some common type.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `auto`
///     `.ok(*)`|Default value
///     `.err(e)`|`e`
/// )
///
/// Params:
///     r = The [Result] to unwrap
///     defaultValue = The fallback value to be used if an error
///
/// Returns: The contained `E` value, or `defaultValue` if `r` has a `T`
@CorrespondingTo("c++", "error_or")
auto unwrapErrOr(T, E, F)(scope auto ref inout(Result!(T, E)) r, F defaultValue = inout(E).init)
{
    return isErr(r) ? unwrapErr(r) : defaultValue;
}

///
@safe @nogc nothrow unittest
{
    alias R = Result!(uint, string);

    immutable defaultValue = "Being right is wrong.";

    auto resultOk = R.ok(9);
    assert(unwrapErrOr(resultOk, defaultValue) == defaultValue);
    assert(unwrapErrOr(resultOk) == "");

    auto resultErr = R.err("error");
    assert(unwrapErrOr(resultErr, defaultValue) == "error");
    assert(unwrapErrOr(resultErr) == "error");
}

@safe @nogc nothrow unittest
{
    auto resultOk1 = Result!(int, string).ok(123);
    assert(unwrapErrOr(resultOk1, "bad") == "bad");
    assert(unwrapErrOr(resultOk1) == "");

    alias R = Result!(string, uint);

    const resultOk2 = R.ok("123");
    assert(unwrapErrOr(resultOk2, 1) == 1);
    assert(unwrapErrOr(resultOk2) == 0);

    auto resultErr1 = R.err(123);
    assert(unwrapErrOr(resultErr1, 1) == 123);
    assert(unwrapErrOr(resultErr1) == 123);

    const resultErr2 = R.err(123);
    assert(unwrapErrOr(resultErr2, 1) == 123);
    assert(unwrapErrOr(resultErr2) == 123);
}

/// Transforms the `T` value of a [Result] using a function, keeping the `E` value unchanged.
///
/// If the [Result] has a `T`, applies `fun` to the value and returns a new [Result] with the transformed value.
/// If the [Result] has an `E`, returns a new [Result] with the same `E` value.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `Result!(U, E)`
///     `.ok(t)`|`.ok(fun(t))`
///     `.err(e)`|`.err(e)`
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
    if (isOk(r))
    {
        static if (is(T : void) && is(U : void))
        {
            fun();
            return S.ok();
        }
        else static if (!is(T : void) && is(U : void))
        {
            unaryFun!fun(unwrap(r));
            return S.ok();
        }
        else static if (is(T : void) && !is(U : void))
        {
            return S.ok(fun());
        }
        else
        {
            return S.ok(unaryFun!fun(unwrap(r)));
        }
    }
    else
    {
        return S.err(unwrapErr(r));
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

            return R.ok(to!int(s));
        }
        catch (Exception _)
        {
            return R.err(s);
        }
    }

    immutable line = "1\n2\n3\n4\n";
    int[] arr;

    import std.string : lineSplitter;

    foreach (num; lineSplitter(line))
    {
        import std.sumtype : match;

        immutable r = map!`a*2`(parse(num));
        if (isOk(r))
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

    auto resultOk = R.ok(-22);
    assert(map!(to!dstring)(resultOk) == S.ok("-22"));
    assert(map(resultOk) == R.ok(-22));

    const cResultOk = R.ok(-22);
    assert(map!(to!dstring)(cResultOk) == S.ok("-22"));
    assert(map(cResultOk) == R.ok(-22));

    immutable iResultOk = R.ok(-22);
    assert(map!(to!dstring)(iResultOk) == S.ok("-22"));
    assert(map(iResultOk) == R.ok(-22));

    auto resultErr = R.err("bad");
    assert(map!(to!dstring)(resultErr) == S.err("bad"));
    assert(map(resultErr) == R.err("bad"));

    const cResultErr = R.err("bad");
    assert(map!(to!dstring)(cResultErr) == S.err("bad"));
    assert(map(cResultErr) == R.err("bad"));

    immutable iResultErr = R.err("bad");
    assert(map!(to!dstring)(iResultErr) == S.err("bad"));
    assert(map(iResultErr) == R.err("bad"));
}

@safe unittest
{
    alias R = Result!(void, string);
    void f()
    {
        return;
    }

    auto resultOk = R.ok();
    assert(map!f(resultOk) == R.ok());

    const cResultOk = R.ok();
    assert(map!f(cResultOk) == R.ok());

    immutable iResultOk = R.ok();
    assert(map!f(iResultOk) == R.ok());

    auto resultErr = R.err("bad");
    assert(map!f(resultErr) == R.err("bad"));

    const cResultErr = R.err("bad");
    assert(map!f(cResultErr) == R.err("bad"));

    immutable iResultErr = R.err("bad");
    assert(map!f(iResultErr) == R.err("bad"));
}

@safe unittest
{
    alias R = Result!(void, string);
    alias S = Result!(int, string);
    int f()
    {
        return 11;
    }

    auto resultOk = R.ok();
    assert(map!f(resultOk) == S.ok(11));

    const cResultOk = R.ok();
    assert(map!f(cResultOk) == S.ok(11));

    immutable iResultOk = R.ok();
    assert(map!f(iResultOk) == S.ok(11));

    auto resultErr = R.err("bad");
    assert(map!f(resultErr) == S.err("bad"));

    const cResultErr = R.err("bad");
    assert(map!f(cResultErr) == S.err("bad"));

    immutable iResultErr = R.err("bad");
    assert(map!f(iResultErr) == S.err("bad"));
}

@safe unittest
{
    alias R = Result!(int, string);
    alias S = Result!(void, string);
    void f(int _)
    {
        return;
    }

    auto resultOk = R.ok(-22);
    assert(map!f(resultOk) == S.ok());

    const cResultOk = R.ok(-22);
    assert(map!f(cResultOk) == S.ok());

    immutable iResultOk = R.ok(-22);
    assert(map!f(iResultOk) == S.ok());

    auto resultErr = R.err("bad");
    assert(map!f(resultErr) == S.err("bad"));

    const cResultErr = R.err("bad");
    assert(map!f(cResultErr) == S.err("bad"));

    immutable iResultErr = R.err("bad");
    assert(map!f(iResultErr) == S.err("bad"));
}

/// Transforms the `E` value of a [Result] using a function, keeping the `T` value unchanged.
///
/// If the [Result] has an `E`, applies `fun` to the value and returns a new [Result] with the transformed error value.
/// If the [Result] has a `T`, returns a new [Result] with the same `T` value.
///
/// $(SMALL_TABLE
///     Conceptual I/O summary
///     Input: `Result!(T, E)`|Output: `Result!(T, F)`
///     `.ok(t)`|`.ok(t)`
///     `.err(e)`|`.err(fun(e))`
/// )
///
/// Params:
///     r = The [Result] to transform
///     fun = The function to apply to the `E` value
///
/// Returns: A new [Result] with the transformed error value from `E`, or with the original `T` value
@CorrespondingTo("rust", "map_err")
@CorrespondingTo("c++", "transform_error")
auto mapErr(alias fun = "a", T, E)(scope auto ref inout(Result!(T, E)) r)
        if (!is(typeof(unaryFun!fun(inout(E).init)) : void))
{
    alias F = Unqual!(typeof(unaryFun!fun(inout(E).init)));
    alias S = Result!(T, F);
    static if (is(T : void))
    {
        return isErr(r) ? S.err(unaryFun!fun(unwrapErr(r))) : S.ok();
    }
    else
    {
        return isErr(r) ? S.err(unaryFun!fun(unwrapErr(r))) : S.ok(unwrap(r));
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

    auto resultOk = R.ok(2);
    assert(mapErr!stringify(resultOk) == S.ok(2));

    auto resultErr = R.err(13);
    assert(mapErr!stringify(resultErr) == S.err("error code: 13"));
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

    auto resultOk = R.ok();
    assert(mapErr!stringify(resultOk) == S.ok());

    auto resultErr = R.err(13);
    assert(mapErr!stringify(resultErr) == S.err("error code: 13"));
}

@safe unittest
{
    import std.conv : to;

    alias R = Result!(int, string);
    alias S = Result!(int, size_t);

    auto resultOk = R.ok(-22);
    assert(mapErr!(a => a.length)(resultOk) == S.ok(-22));
    assert(mapErr(resultOk) == R.ok(-22));

    const cResultOk = R.ok(-22);
    assert(mapErr!(a => a.length)(cResultOk) == S.ok(-22));
    assert(mapErr(cResultOk) == R.ok(-22));

    immutable iResultOk = R.ok(-22);
    assert(mapErr!(a => a.length)(iResultOk) == S.ok(-22));
    assert(mapErr(iResultOk) == R.ok(-22));

    auto resultErr = R.err("bad");
    assert(mapErr!(a => a.length)(resultErr) == S.err(3));
    assert(mapErr(resultErr) == R.err("bad"));

    const cResultErr = R.err("bad");
    assert(mapErr!(a => a.length)(cResultErr) == S.err(3));
    assert(mapErr(cResultErr) == R.err("bad"));

    immutable iResultErr = R.err("bad");
    assert(mapErr!(a => a.length)(iResultErr) == S.err(3));
    assert(mapErr(iResultErr) == R.err("bad"));
}

@safe unittest
{
    import std.conv : to;

    alias R = Result!(void, string);
    alias S = Result!(void, size_t);

    auto resultOk = R.ok();
    assert(mapErr!(a => a.length)(resultOk) == S.ok());
    assert(mapErr(resultOk) == R.ok());

    const cResultOk = R.ok();
    assert(mapErr!(a => a.length)(cResultOk) == S.ok());
    assert(mapErr(cResultOk) == R.ok());

    immutable iResultOk = R.ok();
    assert(mapErr!(a => a.length)(iResultOk) == S.ok());
    assert(mapErr(iResultOk) == R.ok());

    auto resultErr = R.err("bad");
    assert(mapErr!(a => a.length)(resultErr) == S.err(3));
    assert(mapErr(resultErr) == R.err("bad"));

    const cResultErr = R.err("bad");
    assert(mapErr!(a => a.length)(cResultErr) == S.err(3));
    assert(mapErr(cResultErr) == R.err("bad"));

    immutable iResultErr = R.err("bad");
    assert(mapErr!(a => a.length)(iResultErr) == S.err(3));
    assert(mapErr(iResultErr) == R.err("bad"));
}

@safe unittest
{
    alias R = Result!(int*, int);

    auto resultOk = R.ok(null);
    assert(mapErr!" a + 4"(resultOk) == R.ok(null));
    assert(mapErr!(a => a + 4)(resultOk) == R.ok(null));
    assert(mapErr(resultOk) == R.ok(null));

    const cResultOk = R.ok(null);
    assert(mapErr!(a => a + 4)(cResultOk) == R.ok(null));
    assert(mapErr(cResultOk) == R.ok(null));

    immutable iResultOk = R.ok(null);
    assert(mapErr!(a => a + 4)(iResultOk) == R.ok(null));
    assert(mapErr(iResultOk) == R.ok(null));

    auto resultErr = R.err(9);
    assert(mapErr!(a => a + 4)(resultErr) == R.err(13));
    assert(mapErr(resultErr) == R.err(9));

    const cResultErr = R.err(9);
    assert(mapErr!(a => a + 4)(cResultErr) == R.err(13));
    assert(mapErr(cResultErr) == R.err(9));

    immutable iResultErr = R.err(9);
    assert(mapErr!(a => a + 4)(iResultErr) == R.err(13));
    assert(mapErr(iResultErr) == R.err(9));
}

@safe unittest
{
    alias R = Result!(const(void), int);

    auto resultOk = R.ok();
    assert(mapErr!" a + 4"(resultOk) == R.ok());
    assert(mapErr!(a => a + 4)(resultOk) == R.ok());
    assert(mapErr(resultOk) == R.ok());

    const cResultOk = R.ok();
    assert(mapErr!(a => a + 4)(cResultOk) == R.ok());
    assert(mapErr(cResultOk) == R.ok());

    immutable iResultOk = R.ok();
    assert(mapErr!(a => a + 4)(iResultOk) == R.ok());
    assert(mapErr(iResultOk) == R.ok());

    auto resultErr = R.err(9);
    assert(mapErr!(a => a + 4)(resultErr) == R.err(13));
    assert(mapErr(resultErr) == R.err(9));

    const cResultErr = R.err(9);
    assert(mapErr!(a => a + 4)(cResultErr) == R.err(13));
    assert(mapErr(cResultErr) == R.err(9));

    immutable iResultErr = R.err(9);
    assert(mapErr!(a => a + 4)(iResultErr) == R.err(13));
    assert(mapErr(iResultErr) == R.err(9));
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
///     `.ok(t)`|`fun(t)`
///     `.err(*)`|Default value
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
    return isOk(r) ? unaryFun!fun(unwrap(r)) : defaultValue;
}

///
@safe nothrow unittest
{
    alias R = Result!(string, string);

    auto resultOk = R.ok("foo");
    assert(mapOr!"a.length"(resultOk, 42) == 3);

    auto resultErr = R.err("bar");
    assert(mapOr!"a.length"(resultErr, 42) == 42);
}

/// Using default parameter
@safe nothrow unittest
{
    alias R = Result!(string, string);

    auto resultOk = R.ok("foo");
    assert(mapOr!"a.length"(resultOk) == 3);

    auto resultErr = R.err("bar");
    assert(mapOr!"a.length"(resultErr) == 0);
}

@safe nothrow unittest
{
    bool isOdd(int x)
    {
        return x % 2 == 1;
    }

    alias R = Result!(int, string);

    auto resultOk = R.ok(33);
    assert(mapOr!isOdd(resultOk, -1) == 1);
    assert(mapOr!"a%5"(resultOk) == 3);

    const cResultOk = R.ok(33);
    assert(mapOr!isOdd(cResultOk, -1) == 1);
    assert(mapOr!"a%5"(cResultOk) == 3);

    immutable iResultOk = R.ok(33);
    assert(mapOr!isOdd(iResultOk, -1) == 1);
    assert(mapOr!"a%5"(iResultOk) == 3);

    auto resultErr = R.err("33");
    assert(mapOr!isOdd(resultErr, -1) == -1);
    assert(mapOr!"a%5"(resultErr) == 0);

    const cResultErr = R.err("33");
    assert(mapOr!isOdd(cResultErr, -1) == -1);
    assert(mapOr!"a%5"(cResultErr) == 0);

    immutable iResultErr = R.err("33");
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
///     `.ok(t)`|`fun(t)`
///     `.err(e)`|`defaultFun(e)`
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
    return isOk(r) ? unaryFun!fun(unwrap(r)) : unaryFun!defaultFun(unwrapErr(r));
}

///
@safe nothrow unittest
{
    alias R = Result!(string, string);
    immutable k = 21;

    auto resultOk = R.ok("foo");
    assert(mapOrElse!(_ => k * 2, "a.length")(resultOk) == 3);

    auto resultErr = R.err("bar");
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

    auto resultOk = R.ok(33);
    assert(mapOrElse!(getLength, isPos)(resultOk) == 1);

    const cResultOk = R.ok(33);
    assert(mapOrElse!(getLength, isPos)(cResultOk) == 1);

    immutable iResultOk = R.ok(33);
    assert(mapOrElse!(getLength, isPos)(iResultOk) == 1);

    auto resultErr = R.err("33");
    assert(mapOrElse!(getLength, isPos)(resultErr) == 2);

    const cResultErr = R.err("33");
    assert(mapOrElse!(getLength, isPos)(cResultErr) == 2);

    immutable iResultErr = R.err("33");
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
////// Params:
///     r = The [Result] to inspect
///     fun = The function to apply to the `T` value
///
/// Returns: The original [Result]
@CorrespondingTo("rust", "inspect")
auto ref inout(Result!(T, E)) inspect(alias fun, T, E)(scope auto ref inout(Result!(T, E)) r)
        if ((!is(T : void) && is(typeof(unaryFun!fun(inout(T).init)))) || (is(T
            : void) && is(typeof(fun()))))
{
    if (isOk(r))
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

            return R.ok(to!ubyte(s));
        }
        catch (Exception _)
        {
            return R.err(s);
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
            return R.ok();
        }
        catch (Exception _)
        {
            return R.err(s);
        }
    }

    import std.array : appender;
    import std.conv : writeText;

    auto writer = appender!string();
    assert(isParsable("4").inspect!(() => writer.writeText("success")).isOk());
    assert(writer[] == "success");
}

@safe unittest
{
    alias R = Result!(int, string);

    import std.array : appender;
    import std.conv : writeText;

    auto writer1 = appender!string();
    auto okResult = R.ok(42).inspect!(x => writer1.writeText("value: ", x));
    assert(okResult == R.ok(42));
    assert(writer1[] == "value: 42");

    auto writer2 = appender!string();
    auto errResult = R.err("bad").inspect!(x => writer2.writeText("value: ", x));
    assert(errResult == R.err("bad"));
    assert(writer2.length == 0);
}

@safe unittest
{
    alias R = Result!(void, string);

    import std.array : appender;
    import std.conv : writeText;

    auto writer1 = appender!string();
    assert(R.ok().inspect!(() => writer1.writeText("ok")).isOk());
    assert(writer1[] == "ok");

    auto writer2 = appender!string();
    auto errResult = R.err("bad").inspect!(() => writer2.writeText("no"));
    assert(errResult == R.err("bad"));
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
auto ref inout(Result!(T, E)) inspectErr(alias fun, T, E)(scope auto ref inout(Result!(T, E)) r)
        if (is(typeof(unaryFun!fun(inout(E).init))))
{
    if (isErr(r))
    {
        unaryFun!fun(unwrapErr(r));
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

            return R.ok(readText(path));
        }
        catch (Exception e)
        {
            return R.err(e.msg);
        }
    }

    import std.array : appender;
    import std.conv : writeText;

    auto writer = appender!string();
    auto r = inspectErr!(e => writer.writeText("failed to read file: ", e))(
            readToString("address.txt"));

    assert(isOk(r) || writer[].length > 0);
}

@safe unittest
{
    alias R = Result!(int, string);

    import std.array : appender;
    import std.conv : writeText;

    auto writer1 = appender!string();
    auto okResult = R.ok(42).inspectErr!(e => writer1.writeText("error: ", e));
    assert(okResult == R.ok(42));
    assert(writer1.length == 0);

    auto writer2 = appender!string();
    auto errResult = R.err("fail").inspectErr!(e => writer2.writeText("error: ", e));
    assert(errResult == R.err("fail"));
    assert(writer2[] == "error: fail");
}

@safe unittest
{
    alias R = Result!(void, string);

    import std.array : appender;
    import std.conv : writeText;

    auto writer1 = appender!string();
    assert(R.ok().inspectErr!(e => writer1.writeText("error: ", e)).isOk());
    assert(writer1.length == 0);

    auto writer2 = appender!string();
    auto errResult = R.err("fail").inspectErr!(e => writer2.writeText("error: ", e));
    assert(errResult == R.err("fail"));
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
///     `.ok(n)`, n is non-null|`Result!(T, E).ok(n.get)`
///     `.ok(n)`, n is null|null state
///     `.err(e)`|`Result!(T, E).err(e)`
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
    if (isErr(r))
    {
        return N(R.err(unwrapErr(r)));
    }
    inout t = unwrap(r);
    return t.isNull ? N.init : N(R.ok(t.get));
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

    auto x = R.ok(nullable(5));
    auto y = nullable(S.ok(5));
    assert(transpose(x) == y);
}

unittest
{
    alias M = Nullable!Exception;
    alias R = Result!(M, int);
    alias S = Result!(Exception, int);
    alias N = Nullable!S;
    import std.typecons : nullable;

    auto resultOk = R.ok(nullable(new Exception("foo")));
    auto nullableOk = nullable(S.ok(new Exception("foo")));
    assert(transpose(resultOk).get.unwrap.msg == nullableOk.get.unwrap.msg);

    const cResultOk = R.ok(nullable(new Exception("foo")));
    const cNullableOk = nullable(S.ok(new Exception("foo")));
    assert(transpose(cResultOk).get.unwrap.msg == cNullableOk.get.unwrap.msg);

    immutable iResultOk = R.ok(nullable(new Exception("foo")));
    immutable iNullableOk = nullable(S.ok(new Exception("foo")));
    assert(transpose(iResultOk).get.unwrap.msg == iNullableOk.get.unwrap.msg);

    auto resultOkNull = R.ok(M.init);
    assert(transpose(resultOkNull).isNull);

    const cResultOkNull = R.ok(M.init);
    assert(transpose(cResultOkNull).isNull);

    immutable iResultOkNull = R.ok(M.init);
    assert(transpose(iResultOkNull).isNull);

    auto resultErr = R.err(-999);
    auto nullableErr = nullable(S.err(-999));
    assert(transpose(resultErr) == nullableErr);

    const cResultErr = R.err(-999);
    const cNullableErr = nullable(S.err(-999));
    assert(transpose(cResultErr) == cNullableErr);

    immutable iResultErr = R.err(-999);
    immutable iNullableErr = nullable(S.err(-999));
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
///     `.ok(inner)`|`inner`
///     `.err(e)`|`.err(e)`
/// )
///
/// Params:
///     r = The nested [Result] to flatten
///
/// Returns: A flattened [Result] with the inner [Result] or the `E` value
@CorrespondingTo("rust", "flatten")
inout(Result!(T, E)) flatten(T, E)(scope auto ref inout(Result!(Result!(T, E), E)) r)
{
    return isOk(r) ? unwrap(r) : Result!(T, E).err(unwrapErr(r));
}

///
@safe @nogc nothrow unittest
{
    alias R1 = Result!(string, uint);
    alias R2 = Result!(R1, uint);

    auto result1 = R2.ok(R1.ok("hello"));
    assert(flatten(result1) == R1.ok("hello"));

    auto result2 = R2.ok(R1.err(6));
    assert(flatten(result2) == R1.err(6));

    auto result3 = R2.err(6);
    assert(flatten(result3) == R1.err(6));
}

///
@safe @nogc nothrow unittest
{
    alias R1 = Result!(string, uint);
    alias R2 = Result!(R1, uint);
    alias R3 = Result!(R2, uint);

    auto result = R3.ok(R2.ok(R1.ok("hello")));
    assert(flatten(result) == R2.ok(R1.ok("hello")));
    assert(flatten(flatten(result)) == R1.ok("hello"));
}

@safe @nogc nothrow unittest
{
    alias R1 = Result!(int, string);
    alias R2 = Result!(R1, string);

    auto outerOk = R2.ok(R1.err("inner failure"));
    assert(flatten(outerOk) == R1.err("inner failure"));

    auto outerErr = R2.err("outer failure");
    assert(flatten(outerErr) == R1.err("outer failure"));
}
