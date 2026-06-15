module result;

///
struct Ok(T)
{
    ///
    T value;
    alias value this;
}

///
@safe @nogc nothrow unittest
{
    assert(Ok!int(314).value == 314);
    assert(Ok!int(314) == 314); // alias this
    assert(Ok!string("Good day.") == "Good day."); // alias this
}

///
struct Err(E)
{
    ///
    E value;
    alias value this;
}

///
@safe @nogc nothrow unittest
{
    assert(Err!int(314).value == 314);
    assert(Err!int(314) == 314); // alias this
    assert(Err!string("Good day.") == "Good day."); // alias this
}

///
class UnwrapException : Exception
{
    ///
    pure @safe @nogc nothrow this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// Performs as a `std.sumtype.SumType` but has some additional features.
struct Result(T, E)
{
    import std.sumtype : SumType;

    ///
    alias Result = SumType!(Ok!T, Err!E);
    Result payload;
    alias payload this;

    /// The constructor accepts `Result!(T, E)`, `Ok!T` and `Err!E` values.
    this(R)(auto ref R value) if (is(typeof({ Result.init = R.init; })))
    {
        payload = value;
    }

    /// Supports assignment of `Result!(T, E)`, `Ok!T` and `Err!E` values.
    ref opAssign(R)(auto ref R rhs) if (is(typeof({ Result.init = R.init; })))
    {
        payload = rhs;
        return this;
    }
}

// Ctor
@safe @nogc nothrow unittest
{
    import std.sumtype : has, get;

    auto resultOk = Result!(int, string)(Ok!int(123));
    assert(resultOk.has!(Ok!int));
    assert(!resultOk.has!(Err!string));
    assert(resultOk.get!(Ok!int) == Ok!int(123));

    Result!(bool, dstring) resultErr = Err!dstring("123"d);
    assert(resultErr.has!(Err!dstring));
    assert(!resultErr.has!(Ok!bool));
    assert(resultErr.get!(Err!dstring) == Err!dstring("123"d));

    auto newResult = Result!(bool, dstring)(resultErr);
    assert(newResult.get!(Err!dstring) == Err!dstring("123"d));
}

// opAssign
@trusted @nogc nothrow unittest
{
    import std.sumtype : get;

    auto resultOk = Result!(int, string)(Ok!int(123));
    resultOk = Ok!int(1234);
    assert(resultOk.get!(Ok!int) == Ok!int(1234));

    auto resultErr = Result!(bool, dstring)(Err!dstring("123"d));
    resultErr = Err!dstring("1234"d);
    assert(resultErr.get!(Err!dstring) == Err!dstring("1234"d));

    auto resultEither = Result!(bool, dstring)(Err!dstring("123"d));
    resultEither = Ok!bool(false);
    assert(resultEither.get!(Ok!bool) == Ok!bool(false));

    resultEither = resultErr;
    assert(resultEither.get!(Err!dstring) == Err!dstring("1234"d));
}

import std.traits : TemplateArgsOf, CopyTypeQualifiers;

alias OkTypeOf(R) = TemplateArgsOf!(typeof(R.payload))[0];
unittest
{
    alias R = Result!(int, string);
    assert(is(OkTypeOf!R == Ok!int));
    assert(is(OkTypeOf!(const(R)) == Ok!int));
    assert(is(OkTypeOf!(immutable(R)) == Ok!int));
}

alias QualifiedOkTypeOf(R) = CopyTypeQualifiers!(R, OkTypeOf!R);
unittest
{
    alias R = Result!(int, string);
    assert(is(QualifiedOkTypeOf!R == Ok!int));
    assert(is(QualifiedOkTypeOf!(const(R)) == const(Ok!int)));
    assert(is(QualifiedOkTypeOf!(immutable(R)) == immutable(Ok!int)));
}

alias ErrTypeOf(R) = TemplateArgsOf!(typeof(R.payload))[1];
unittest
{
    alias R = Result!(int, string);
    assert(is(ErrTypeOf!R == Err!string));
    assert(is(ErrTypeOf!(const(R)) == Err!string));
    assert(is(ErrTypeOf!(immutable(R)) == Err!string));
}

alias QualifiedErrTypeOf(R) = CopyTypeQualifiers!(R, ErrTypeOf!R);
unittest
{
    alias R = Result!(int, string);
    assert(is(QualifiedErrTypeOf!R == Err!string));
    assert(is(QualifiedErrTypeOf!(const(R)) == const(Err!string)));
    assert(is(QualifiedErrTypeOf!(immutable(R)) == immutable(Err!string)));
}

alias OkValueTypeOf(R) = TemplateArgsOf!(OkTypeOf!R)[0];
unittest
{
    alias R = Result!(int, string);
    assert(is(OkValueTypeOf!R == int));
    assert(is(OkValueTypeOf!(const(R)) == int));
    assert(is(OkValueTypeOf!(immutable(R)) == int));
}

alias ErrValueTypeOf(R) = TemplateArgsOf!(ErrTypeOf!R)[0];
unittest
{
    alias R = Result!(int, string);
    assert(is(ErrValueTypeOf!R == string));
    assert(is(ErrValueTypeOf!(const(R)) == string));
    assert(is(ErrValueTypeOf!(immutable(R)) == string));
}

enum bool isResult(R) = is(R : Result!(T, E), T, E);
///
unittest
{
    alias R = Result!(int, string);
    assert(isResult!R);
    assert(isResult!(const(R)));
    assert(isResult!(immutable(R)));
    assert(isResult!(shared(R)));
}

/// Returns `true` if `result` has an [Ok] value.
bool isOk(R)(auto ref R result) if (isResult!R)
{
    import std.sumtype : match;

    return result.payload.match!((OkTypeOf!R _) => true, (ErrTypeOf!R _) => false);
}

///
@safe @nogc nothrow unittest
{
    auto resultOk = Result!(int, string)(Ok!int(-3));
    assert(isOk(resultOk));

    auto resultErr = Result!(int, string)(Err!string("Some error message"));
    assert(!isOk(resultErr));
}

@safe @nogc nothrow unittest
{
    const constResultOk = Result!(int, string)(Ok!int(123));
    assert(isOk(constResultOk));

    immutable immutableResultOk = Result!(int, string)(Ok!int(123));
    assert(isOk(immutableResultOk));

    auto resultErr = Result!(int, string)(Err!string("123"));
    assert(!isOk(resultErr));

    const constResultErr = Result!(int, string)(Err!string("123"));
    assert(!isOk(constResultErr));

    immutable immutableResultErr = Result!(int, string)(Err!string("123"));
    assert(!isOk(immutableResultErr));
}

/// Returns `true` if `this` has an `Err!E` value.
bool isErr(R)(auto ref R result) if (isResult!R)
{
    return !isOk(result);
}

///
@safe @nogc nothrow unittest
{
    auto resultOk = Result!(int, string)(Ok!int(-3));
    assert(!isErr(resultOk));

    auto resultErr = Result!(int, string)(Err!string("Some error message"));
    assert(isErr(resultErr));
}

@safe @nogc nothrow unittest
{
    const constResultErr = Result!(int, string)(Err!string("123"));
    assert(constResultErr.isErr());

    immutable immutableResultErr = Result!(int, string)(Err!string("123"));
    assert(immutableResultErr.isErr());

    auto resultOk = Result!(int, string)(Ok!int(123));
    assert(!resultOk.isErr());

    const constResultOk = Result!(int, string)(Ok!int(123));
    assert(!constResultOk.isErr());

    immutable immutableResultOk = Result!(int, string)(Ok!int(123));
    assert(!immutableResultOk.isErr());
}

/// Returns the containing `Ok!T` value,
/// without checking that the value is not an `Err!E`
OkValueTypeOf!R unwrapUnchecked(R)(auto ref R result) if (isResult!R)
{
    import std.sumtype : get;

    return result.payload.get!(QualifiedOkTypeOf!R).value;
}

///
unittest
{
    auto resultOk = Result!(uint, string)(Ok!uint(2));
    assert(unwrapUnchecked(resultOk) == 2);

    import std.exception : assertThrown;
    import core.exception : AssertError;

    auto resultErr = Result!(uint, string)(Err!string("emergency failure"));
    assertThrown!AssertError(unwrapUnchecked(resultErr)); // Assert will fail
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;
    import core.exception : AssertError;

    auto resultOk1 = Result!(int, string)(Ok!int(123));
    assert(resultOk1.unwrapUnchecked() == 123);
    assertNotThrown!AssertError(resultOk1.unwrapUnchecked());

    auto resultOk2 = Result!(string, uint)(Ok!string("123"));
    assert(resultOk2.unwrapUnchecked() == "123");
    assertNotThrown!AssertError(resultOk2.unwrapUnchecked());
    auto resultOk22 = Result!(string, uint)(Ok!string("123"));
    assert(resultOk22.unwrapUnchecked() == "123");
    auto resultErr = Result!(string, uint)(Err!uint(123));
    assertThrown!AssertError(resultErr.unwrapUnchecked());
}

/// Returns the contained `Err!E` value.
/// without checking that the value is not an `Ok!T`.
ErrValueTypeOf!R unwrapErrUnchecked(R)(auto ref R result) if (isResult!R)
{
    import std.sumtype : get;

    return result.payload.get!(QualifiedErrTypeOf!R).value;
}

///
unittest
{
    import std.exception : assertThrown;
    import core.exception : AssertError;

    auto resultOk = Result!(uint, string)(Ok!uint(2));
    assertThrown!AssertError(unwrapErrUnchecked(resultOk));

    auto resultErr = Result!(uint, string)(Err!string("emergency failure"));
    assert(unwrapErrUnchecked(resultErr) == "emergency failure");
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;
    import core.exception : AssertError;

    auto resultErr1 = Result!(int, string)(Err!string("123"));
    assert(resultErr1.unwrapErrUnchecked() == "123");
    assertNotThrown!AssertError(resultErr1.unwrapErrUnchecked());

    auto resultErr2 = Result!(string, uint)(Err!uint(123));
    assert(resultErr2.unwrapErrUnchecked() == 123);
    assertNotThrown!AssertError(resultErr2.unwrapErrUnchecked());

    auto resultOk = Result!(string, uint)(Ok!string("123"));
    assertThrown!AssertError(resultOk.unwrapErrUnchecked());
}

/// Returns the containing `Ok!T` value.
/// Throws `UnwrapException` if the value is an `Err!E`.
OkValueTypeOf!R unwrap(R)(auto ref R result) if (isResult!R)
{
    if (isErr(result))
    {
        throw new UnwrapException("Bad"); // FIXME: message should be reasonable
    }

    return unwrapUnchecked(result);
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown;

    auto resultOk = Result!(uint, string)(Ok!uint(2));
    assert(unwrap(resultOk) == 2);

    import std.exception : assertThrown;

    auto resultErr = Result!(uint, string)(Err!string("emergency failure"));
    assertThrown!UnwrapException(unwrap(resultErr));
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown;

    auto resultOk1 = Result!(int, string)(Ok!int(123));
    assert(resultOk1.unwrap() == 123);
    assertNotThrown!UnwrapException(resultOk1.unwrap());

    auto resultOk2 = Result!(string, uint)(Ok!string("123"));
    assert(resultOk2.unwrap() == "123");
    assertNotThrown!UnwrapException(resultOk2.unwrap());

    auto resultErr = Result!(string, uint)(Err!uint(123));
    assertThrown!UnwrapException(resultErr.unwrap());
}

/// Returns the contained `Err!E` value.
/// Throws `UnwrapException` if the value is an `Ok!T`.
ErrValueTypeOf!R unwrapErr(R)(auto ref R result) if (isResult!R)
{
    if (isOk(result))
    {
        throw new UnwrapException("Bad"); // FIXME: message should be reasonable
    }

    return unwrapErrUnchecked(result);
}

///
@safe unittest
{
    import std.exception : assertThrown;

    auto resultOk = Result!(uint, string)(Ok!uint(2));
    assertThrown!UnwrapException(unwrapErr(resultOk));

    auto resultErr = Result!(uint, string)(Err!string("emergency failure"));
    assert(unwrapErr(resultErr) == "emergency failure");
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown;

    auto resultErr1 = Result!(int, string)(Err!string("123"));
    assert(resultErr1.unwrapErr() == "123");
    assertNotThrown!UnwrapException(resultErr1.unwrapErr());

    auto resultErr2 = Result!(string, uint)(Err!uint(123));
    assert(resultErr2.unwrapErr() == 123);
    assertNotThrown!UnwrapException(resultErr2.unwrapErr());

    auto resultOk = Result!(string, uint)(Ok!string("123"));
    assertThrown!UnwrapException(resultOk.unwrapErr());
}

/// Returns the contained `Ok!T` value.
/// Or returns the contained `defaultValue` if the value is an `Err!E`.
OkValueTypeOf!R unwrapOr(R, T)(auto ref R result, T defaultValue)
        if (isResult!R && is(T : OkValueTypeOf!R))
{
    import std.sumtype : match;

    return result.payload.match!((OkTypeOf!R t) => t.value, (ErrTypeOf!R _) => defaultValue);
}

///
@safe @nogc nothrow unittest
{
    immutable defaultValue = 2;
    auto resultOk = Result!(uint, string)(Ok!uint(9));
    assert(unwrapOr(resultOk, defaultValue) == 9);

    auto resultErr = Result!(uint, string)(Err!string("error"));
    assert(unwrapOr(resultErr, defaultValue) == defaultValue);
}

@safe @nogc nothrow unittest
{
    auto resultOk1 = Result!(int, string)(Ok!int(123));
    assert(resultOk1.unwrapOr(456) == 123);

    const resultOk2 = Result!(string, uint)(Ok!string("123"));
    assert(resultOk2.unwrapOr("456") == "123");

    auto resultErr = Result!(string, uint)(Err!uint(123));
    assert(resultErr.unwrapOr("456") == "456");
}

import std.functional : unaryFun;

/// Returns the contained `Ok!T` value.
/// If the value is an `Err!E`, calls `fun` with the value of `Err!E` and returns the resulting `Ok!T` value.
OkValueTypeOf!R unwrapOrElse(alias fun = "a", R)(auto ref R result)
        if (isResult!R && is(typeof(unaryFun!fun(ErrValueTypeOf!R.init)) : OkValueTypeOf!R))
{
    import std.sumtype : match;

    return result.payload.match!((OkTypeOf!R t) => t.value,
            (ErrTypeOf!R e) => unaryFun!fun(e.value));
}

///
@safe nothrow unittest
{
    alias count = x => x.length;

    auto resultOk = Result!(size_t, string)(Ok!size_t(2));
    assert(unwrapOrElse!count(resultOk) == 2);

    auto resultErr = Result!(size_t, string)(Err!string("foo"));
    assert(unwrapOrElse!count(resultErr) == 3);
    assert(unwrapOrElse!`a.length`(resultErr) == 3);
}

@safe nothrow unittest
{
    import std.conv : to;

    auto f999(string s)
    {
        return 999;
    }

    auto fFoo(uint n)
    {
        return "Foo is " ~ to!string(n);
    }

    auto resultOk1 = Result!(int, string)(Ok!int(123));
    assert(resultOk1.unwrapOrElse!"999"() == 123);
    assert(resultOk1.unwrapOrElse!f999() == 123);

    immutable resultOk2 = Result!(string, uint)(Ok!string("123"));
    assert(resultOk2.unwrapOrElse!(to!string)() == "123");
    assert(resultOk2.unwrapOrElse!fFoo() == "123");

    auto resultErr = Result!(string, uint)(Err!uint(123));
    assert(resultErr.unwrapOrElse!(to!string)() == "123");
    assert(resultErr.unwrapOrElse!"to!string(a+2)"() == "125");
    assert(resultErr.unwrapOrElse!"`foo`"() == "foo");
    assert(resultErr.unwrapOrElse!fFoo() == "Foo is 123");
}

import std.traits : isCallable;

/// Ditto
OkValueTypeOf!R unwrapOrElse(F, R)(auto ref R result, auto ref F fun)
        if (isCallable!F && is(typeof(fun(ErrValueTypeOf!R.init)) : OkValueTypeOf!R))
{
    import std.sumtype : match;

    return result.payload.match!((OkTypeOf!R t) => t.value, (ErrTypeOf!R e) => fun(e.value));
}

///
@safe nothrow unittest
{
    auto count = (string x) => x.length;

    auto resultOk = Result!(size_t, string)(Ok!size_t(2));
    assert(unwrapOrElse(resultOk, count) == 2);

    auto resultErr = Result!(size_t, string)(Err!string("foo"));
    assert(unwrapOrElse(resultErr, count) == 3);
}

@safe nothrow unittest
{
    import std.conv : to;

    auto f999(string s)
    {
        return 999;
    }

    auto fFoo(uint n)
    {
        return "Foo is " ~ to!string(n);
    }

    auto resultOk1 = Result!(int, string)(Ok!int(123));
    static assert(is(typeof(resultOk1.unwrapOrElse(&f999)) == int));
    assert(resultOk1.unwrapOrElse(&f999) == 123);

    immutable resultOk2 = Result!(string, uint)(Ok!string("123"));
    static assert(is(typeof(resultOk2.unwrapOrElse((uint a) => "456")) == string));
    assert(resultOk2.unwrapOrElse!(to!string)() == "123");

    auto resultErr = Result!(string, uint)(Err!uint(123));
    static assert(is(typeof(resultErr.unwrapOrElse((uint a) => a.to!string)) == string));
    assert(resultErr.unwrapOrElse((uint a) => a.to!string) == "123");
    static assert(is(typeof(resultErr.unwrapOrElse(&fFoo)) == string));
    assert(resultErr.unwrapOrElse(&fFoo) == "Foo is 123");
}
