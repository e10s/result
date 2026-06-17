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
    alias Payload = SumType!(Ok!T, Err!E);
    Payload payload;
    alias payload this;

    /// The constructor accepts `Result!(T, E)`, `Ok!T` and `Err!E` values.
    this(R)(auto ref R value) if (is(typeof({ Payload.init = R.init; })))
    {
        payload = value;
    }
    /// Ditto
    this(R)(auto ref R value) const if (is(typeof({ Payload.init = R.init; })))
    {
        payload = value;
    }
    /// Ditto
    this(R)(auto ref R value) immutable
            if (is(typeof({ Payload.init = R.init; })))
    {
        payload = value;
    }

    /// Supports assignment of `Result!(T, E)`, `Ok!T` and `Err!E` values.
    ref opAssign(R)(auto ref R rhs) if (is(typeof({ Payload.init = R.init; })))
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

    const constResultOk = Result!(int, string)(Ok!int(123));
    assert(!constResultOk.has!(Ok!int));
    assert(!constResultOk.has!(Err!string));
    assert(constResultOk.has!(const(Ok!int)));
    assert(!constResultOk.has!(const(Err!string)));
    assert(constResultOk.get!(const(Ok!int)) == Ok!int(123));

    immutable immutableResultOk = Result!(int, string)(Ok!int(123));
    assert(!immutableResultOk.has!(Ok!int));
    assert(!immutableResultOk.has!(Err!string));
    assert(immutableResultOk.has!(immutable(Ok!int)));
    assert(!immutableResultOk.has!(immutable(Err!string)));
    assert(immutableResultOk.get!(immutable(Ok!int)) == Ok!int(123));

    auto resultErr = Result!(bool, dstring)(Err!dstring("123"d));
    assert(resultErr.has!(Err!dstring));
    assert(!resultErr.has!(Ok!bool));
    assert(resultErr.get!(Err!dstring) == Err!dstring("123"d));

    const constResultErr = Result!(bool, dstring)(Err!dstring("123"d));
    assert(!constResultErr.has!(Ok!bool));
    assert(!constResultErr.has!(Err!dstring));
    assert(!constResultErr.has!(const(Ok!bool)));
    assert(constResultErr.has!(const(Err!dstring)));
    assert(constResultErr.get!(const(Err!dstring)) == Err!dstring("123"d));

    immutable immutableResultErr = Result!(bool, dstring)(Err!dstring("123"d));
    assert(!immutableResultErr.has!(Ok!bool));
    assert(!immutableResultErr.has!(Err!dstring));
    assert(!immutableResultErr.has!(immutable(Ok!bool)));
    assert(immutableResultErr.has!(immutable(Err!dstring)));
    assert(immutableResultErr.get!(immutable(Err!dstring)) == Err!dstring("123"d));

    auto newResult1 = Result!(bool, dstring)(resultErr);
    assert(newResult1.has!(Err!dstring));
    auto newResult2 = Result!(bool, dstring)(constResultErr);
    assert(newResult2.has!(Err!dstring));
    auto newResult3 = Result!(bool, dstring)(immutableResultErr);
    assert(newResult3.has!(Err!dstring));

    const newConstResult1 = Result!(bool, dstring)(resultErr);
    assert(newConstResult1.has!(const(Err!dstring)));
    const newConstResult2 = Result!(bool, dstring)(constResultErr);
    assert(newConstResult2.has!(const(Err!dstring)));
    const newConstResult3 = Result!(bool, dstring)(immutableResultErr);
    assert(newConstResult3.has!(const(Err!dstring)));

    immutable newImmutableResult1 = Result!(bool, dstring)(resultErr);
    assert(newImmutableResult1.has!(immutable(Err!dstring)));
    immutable newImmutableResult2 = Result!(bool, dstring)(constResultErr);
    assert(newImmutableResult2.has!(immutable(Err!dstring)));
    immutable newImmutableResult3 = Result!(bool, dstring)(immutableResultErr);
    assert(newImmutableResult3.has!(immutable(Err!dstring)));
}

// Ctor const
@safe @nogc nothrow unittest
{
    import std.sumtype : has;

    alias R = Result!(int, string);
    alias O = Ok!int;

    auto constResult1 = const(R)(O(123));
    assert(constResult1.has!(const(O)));
    auto constResult2 = const(R)(const(O)(123));
    assert(constResult2.has!(const(O)));
    auto constResult3 = const(R)(immutable(O)(123));
    assert(constResult3.has!(const(O)));

    auto result = R(O(123));
    const constResult = R(O(123));
    immutable immutableResult = R(O(123));

    auto constResult4 = const(R)(result);
    assert(constResult4.has!(const(O)));
    auto constResult5 = const(R)(constResult);
    assert(constResult5.has!(const(O)));
    auto constResult6 = const(R)(immutableResult);
    assert(constResult6.has!(const(O)));
}

// Ctor immutable
@safe @nogc nothrow unittest
{
    import std.sumtype : has;

    alias R = Result!(int, string);
    alias O = Ok!int;

    auto immutableResult1 = immutable(R)(O(123));
    assert(immutableResult1.has!(immutable(O)));
    auto immutableResult2 = immutable(R)(immutable(O)(123));
    assert(immutableResult2.has!(immutable(O)));
    auto immutableResult3 = immutable(R)(immutable(O)(123));
    assert(immutableResult3.has!(immutable(O)));

    auto result = R(O(123));
    const constResult = R(O(123));
    immutable immutableResult = R(O(123));

    auto immutableResult4 = immutable(R)(result);
    assert(immutableResult4.has!(immutable(O)));
    auto immutableResult5 = immutable(R)(constResult);
    assert(immutableResult5.has!(immutable(O)));
    auto immutableResult6 = immutable(R)(immutableResult);
    assert(immutableResult6.has!(immutable(O)));
}

// opAssign
@trusted @nogc nothrow unittest
{
    import std.sumtype : get;

    Result!(int, string) result1, result2;

    result1 = Ok!int(10);
    assert(result1.get!(Ok!int) == Ok!int(10));

    result1 = const(Ok!int)(20);
    assert(result1.get!(Ok!int) == Ok!int(20));

    result1 = immutable(Ok!int)(30);
    assert(result1.get!(Ok!int) == Ok!int(30));

    result1 = Err!string("11");
    assert(result1.get!(Err!string) == Err!string("11"));

    result1 = const(Err!string)("22");
    assert(result1.get!(Err!string) == Err!string("22"));

    result1 = immutable(Err!string)("33");
    assert(result1.get!(Err!string) == Err!string("33"));

    result2 = result1;
    assert(result2.get!(Err!string) == Err!string("33"));

    const result3 = Result!(int, string)(Ok!int(100));
    result2 = result3;
    assert(result2.get!(Ok!int) == Ok!int(100));

    immutable result4 = Result!(int, string)(Err!string("1000"));
    result2 = result4;
    assert(result2.get!(Err!string) == Err!string("1000"));
}

/* Convenience templates begin */
private enum bool isResult(R) = is(R : Result!(T, E), T, E);

unittest
{
    alias R = Result!(int, string);
    assert(isResult!R);
    assert(isResult!(const(R)));
    assert(isResult!(immutable(R)));
    assert(isResult!(shared(R)));
}

private template OkTypeOf(R) if (isResult!R)
{
    alias OkTypeOf = R.Payload.Types[0];
}

unittest
{
    alias R = Result!(int, string);
    assert(is(OkTypeOf!R == Ok!int));
    assert(is(OkTypeOf!(const(R)) == Ok!int));
    assert(is(OkTypeOf!(immutable(R)) == Ok!int));
}

private template QualifiedOkTypeOf(R) if (isResult!R)
{
    import std.traits : CopyTypeQualifiers;

    alias QualifiedOkTypeOf = CopyTypeQualifiers!(R, OkTypeOf!R);
}

unittest
{
    alias R = Result!(int, string);
    assert(is(QualifiedOkTypeOf!R == Ok!int));
    assert(is(QualifiedOkTypeOf!(const(R)) == const(Ok!int)));
    assert(is(QualifiedOkTypeOf!(immutable(R)) == immutable(Ok!int)));
}

private template ErrTypeOf(R) if (isResult!R)
{
    alias ErrTypeOf = R.Payload.Types[1];
}

unittest
{
    alias R = Result!(int, string);
    assert(is(ErrTypeOf!R == Err!string));
    assert(is(ErrTypeOf!(const(R)) == Err!string));
    assert(is(ErrTypeOf!(immutable(R)) == Err!string));
}

private template QualifiedErrTypeOf(R) if (isResult!R)
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
}

private template OkValueTypeOf(R) if (isResult!R)
{
    import std.traits : TemplateArgsOf;

    alias OkValueTypeOf = TemplateArgsOf!(OkTypeOf!R)[0];
}

unittest
{
    alias R = Result!(int, string);
    assert(is(OkValueTypeOf!R == int));
    assert(is(OkValueTypeOf!(const(R)) == int));
    assert(is(OkValueTypeOf!(immutable(R)) == int));
}

private template ErrValueTypeOf(R) if (isResult!R)
{
    import std.traits : TemplateArgsOf;

    alias ErrValueTypeOf = TemplateArgsOf!(ErrTypeOf!R)[0];
}

unittest
{
    alias R = Result!(int, string);
    assert(is(ErrValueTypeOf!R == string));
    assert(is(ErrValueTypeOf!(const(R)) == string));
    assert(is(ErrValueTypeOf!(immutable(R)) == string));
}
/* Convenience templates end */

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

import std.functional : unaryFun;

/// Returns `true` if `result` has an [Ok] value and its value satisfies `pred`.
bool isOkAnd(alias pred = "a", R)(auto ref R result)
        if (isResult!R && is(typeof(unaryFun!pred(OkValueTypeOf!R.init))))
{
    import std.sumtype : match;

    return result.payload.match!((OkTypeOf!R t) => unaryFun!pred(t.value)
            && true, (ErrTypeOf!R _) => false);
}

///
@safe nothrow unittest
{
    auto resultOk1 = Result!(uint, string)(Ok!uint(2));
    assert(isOkAnd!(a => a > 1)(resultOk1) == true);

    auto resultOk2 = Result!(uint, string)(Ok!uint(0));
    assert(isOkAnd!"a>1"(resultOk2) == false);

    auto resultErr = Result!(uint, string)(Err!string("hey"));
    assert(isOkAnd!"a>1"(resultErr) == false);
}

@safe nothrow unittest
{
    size_t isOdd(int n)
    {
        return n & 1;
    }

    auto resultOk = Result!(int, string)(Ok!int(123));
    assert(isOkAnd!isOdd(resultOk));

    const constResultOk = Result!(int, string)(Ok!int(123));
    assert(isOkAnd!isOdd(constResultOk));

    immutable immutableResultOk = Result!(int, string)(Ok!int(123));
    assert(isOkAnd!isOdd(immutableResultOk));

    auto resultErr = Result!(int, string)(Err!string("123"));
    assert(!isOkAnd!isOdd(resultErr));

    const constResultErr = Result!(int, string)(Err!string("123"));
    assert(!isOkAnd!isOdd(constResultErr));

    immutable immutableResultErr = Result!(int, string)(Err!string("123"));
    assert(!isOkAnd!isOdd(immutableResultErr));
}

import std.traits : isCallable;

/// Ditto
bool isOkAnd(F, R)(auto ref R result, auto ref F pred)
        if (isCallable!F && is(typeof(unaryFun!pred(OkValueTypeOf!R.init))))
{
    import std.sumtype : match;

    return result.payload.match!((OkTypeOf!R t) => unaryFun!pred(t.value)
            && true, (ErrTypeOf!R _) => false);
}

///
@safe nothrow unittest
{
    auto resultOk1 = Result!(uint, string)(Ok!uint(2));
    assert(isOkAnd(resultOk1, (uint a) => a > 1) == true);

    auto resultOk2 = Result!(uint, string)(Ok!uint(0));
    assert(isOkAnd(resultOk2, (uint a) => a > 1) == false);

    auto resultErr = Result!(uint, string)(Err!string("hey"));
    assert(isOkAnd(resultErr, (uint a) => a > 1) == false);
}

@safe nothrow unittest
{
    size_t isOdd(int n)
    {
        return n & 1;
    }

    auto resultOk = Result!(int, string)(Ok!int(123));
    assert(isOkAnd(resultOk, &isOdd));

    const constResultOk = Result!(int, string)(Ok!int(123));
    assert(isOkAnd(constResultOk, &isOdd));

    immutable immutableResultOk = Result!(int, string)(Ok!int(123));
    assert(isOkAnd(immutableResultOk, &isOdd));

    auto resultErr = Result!(int, string)(Err!string("123"));
    assert(!isOkAnd(resultErr, &isOdd));

    const constResultErr = Result!(int, string)(Err!string("123"));
    assert(!isOkAnd(constResultErr, &isOdd));

    immutable immutableResultErr = Result!(int, string)(Err!string("123"));
    assert(!isOkAnd(immutableResultErr, &isOdd));
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

/// Returns `true` if `result` has an [Err] value and its value satisfies `pred`.
bool isErrAnd(alias pred = "a", R)(auto ref R result)
        if (isResult!R && is(typeof(unaryFun!pred(ErrValueTypeOf!R.init))))
{
    import std.sumtype : match;

    return result.payload.match!((OkTypeOf!R _) => false,
            (ErrTypeOf!R e) => unaryFun!pred(e.value) && true);
}

///
@safe nothrow unittest
{
    auto resultErr1 = Result!(uint, string)(Err!string("!!!"));
    assert(isErrAnd!(e => e == "!!!")(resultErr1) == true);

    auto resultErr2 = Result!(uint, string)(Err!string("?"));
    assert(isErrAnd!`a=="!!!"`(resultErr2) == false);

    auto resultOk = Result!(uint, string)(Ok!uint(123));
    assert(isErrAnd!`a=="!!!"`(resultOk) == false);
}

@safe nothrow unittest
{
    import std.string : isNumeric;

    auto resultOk = Result!(int, string)(Ok!int(123));
    assert(!isErrAnd!isNumeric(resultOk));

    const constResultOk = Result!(int, string)(Ok!int(123));
    assert(!isErrAnd!isNumeric(constResultOk));

    immutable immutableResultOk = Result!(int, string)(Ok!int(123));
    assert(!isErrAnd!isNumeric(immutableResultOk));

    auto resultErr = Result!(int, string)(Err!string("123"));
    assert(isErrAnd!isNumeric(resultErr));

    const constResultErr = Result!(int, string)(Err!string("123"));
    assert(isErrAnd!isNumeric(constResultErr));

    immutable immutableResultErr = Result!(int, string)(Err!string("123"));
    assert(isErrAnd!isNumeric(immutableResultErr));

    auto resultErr2 = Result!(int, string)(Err!string("Good morning, 007."));
    assert(!isErrAnd!isNumeric(resultErr2));
}

/// Ditto
bool isErrAnd(F, R)(auto ref R result, auto ref F pred)
        if (isCallable!F && is(typeof(unaryFun!pred(ErrValueTypeOf!R.init))))
{
    import std.sumtype : match;

    return result.payload.match!((OkTypeOf!R _) => false,
            (ErrTypeOf!R e) => unaryFun!pred(e.value) && true);
}

///
@safe nothrow unittest
{
    auto resultErr1 = Result!(uint, string)(Err!string("!!!"));
    assert(isErrAnd(resultErr1, (string e) => e == "!!!") == true);

    auto resultErr2 = Result!(uint, string)(Err!string("?"));
    assert(isErrAnd(resultErr2, (string e) => e == "!!!") == false);

    auto resultOk = Result!(uint, string)(Ok!uint(123));
    assert(isErrAnd(resultOk, (string e) => e == "!!!") == false);
}

@safe nothrow unittest
{
    auto somePred(string s)
    {
        return s.length > 2 && s[$ - 2] == '2';
    }

    auto resultOk = Result!(int, string)(Ok!int(123));
    assert(!isErrAnd(resultOk, &somePred));

    const constResultOk = Result!(int, string)(Ok!int(123));
    assert(!isErrAnd(constResultOk, &somePred));

    immutable immutableResultOk = Result!(int, string)(Ok!int(123));
    assert(!isErrAnd(immutableResultOk, &somePred));

    auto resultErr = Result!(int, string)(Err!string("123"));
    assert(isErrAnd(resultErr, &somePred));

    const constResultErr = Result!(int, string)(Err!string("123"));
    assert(isErrAnd(constResultErr, &somePred));

    immutable immutableResultErr = Result!(int, string)(Err!string("123"));
    assert(isErrAnd(immutableResultErr, &somePred));

    auto resultErr2 = Result!(int, string)(Err!string("Good morning, 007."));
    assert(!isErrAnd(resultErr2, &somePred));
}

/// Returns the containing `Ok!T` value.
OkValueTypeOf!R unwrap(R)(auto ref R result) if (isResult!R)
{
    assert(isOk(result), "Result does not have an Ok value.");

    import std.sumtype : get;

    return result.payload.get!(QualifiedOkTypeOf!R).value;
}

///
unittest
{
    auto resultOk = Result!(uint, string)(Ok!uint(2));
    assert(unwrap(resultOk) == 2);

    import std.exception : assertThrown;
    import core.exception : AssertError;

    auto resultErr = Result!(uint, string)(Err!string("emergency failure"));
    assertThrown!AssertError(unwrap(resultErr)); // Assert will fail
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;
    import core.exception : AssertError;

    auto resultOk1 = Result!(int, string)(Ok!int(123));
    assert(resultOk1.unwrap() == 123);
    assertNotThrown!AssertError(resultOk1.unwrap());

    auto resultOk2 = Result!(string, uint)(Ok!string("123"));
    assert(resultOk2.unwrap() == "123");
    assertNotThrown!AssertError(resultOk2.unwrap());
    auto resultOk22 = Result!(string, uint)(Ok!string("123"));
    assert(resultOk22.unwrap() == "123");
    auto resultErr = Result!(string, uint)(Err!uint(123));
    assertThrown!AssertError(resultErr.unwrap());
}

/// Returns the contained `Err!E` value.
ErrValueTypeOf!R unwrapErr(R)(auto ref R result) if (isResult!R)
{
    assert(isErr(result), "Result does not have an Err value.");

    import std.sumtype : get;

    return result.payload.get!(QualifiedErrTypeOf!R).value;
}

///
unittest
{
    import std.exception : assertThrown;
    import core.exception : AssertError;

    auto resultOk = Result!(uint, string)(Ok!uint(2));
    assertThrown!AssertError(unwrapErr(resultOk));

    auto resultErr = Result!(uint, string)(Err!string("emergency failure"));
    assert(unwrapErr(resultErr) == "emergency failure");
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;
    import core.exception : AssertError;

    auto resultErr1 = Result!(int, string)(Err!string("123"));
    assert(resultErr1.unwrapErr() == "123");
    assertNotThrown!AssertError(resultErr1.unwrapErr());

    auto resultErr2 = Result!(string, uint)(Err!uint(123));
    assert(resultErr2.unwrapErr() == 123);
    assertNotThrown!AssertError(resultErr2.unwrapErr());

    auto resultOk = Result!(string, uint)(Ok!string("123"));
    assertThrown!AssertError(resultOk.unwrapErr());
}

/// Returns the containing `Ok!T` value.
/// Throws `UnwrapException` if the value is an `Err!E`.
@("Unique to D")
OkValueTypeOf!R tryUnwrap(R)(auto ref R result) if (isResult!R)
{
    import std.exception : enforce;

    enforce!UnwrapException(isOk(result), "Result does not have an Ok value.");
    return unwrap(result);
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown;

    auto resultOk = Result!(uint, string)(Ok!uint(2));
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk)) == 2);

    auto resultErr = Result!(uint, string)(Err!string("emergency failure"));
    assertThrown!UnwrapException(tryUnwrap(resultErr));
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown;

    auto resultOk1 = Result!(int, string)(Ok!int(123));
    assert(resultOk1.tryUnwrap() == 123);
    assertNotThrown!UnwrapException(resultOk1.tryUnwrap());

    auto resultOk2 = Result!(string, uint)(Ok!string("123"));
    assert(resultOk2.tryUnwrap() == "123");
    assertNotThrown!UnwrapException(resultOk2.tryUnwrap());

    auto resultErr = Result!(string, uint)(Err!uint(123));
    assertThrown!UnwrapException(resultErr.tryUnwrap());
}

/// Returns the contained `Err!E` value.
/// Throws `UnwrapException` if the value is an `Ok!T`.
@("Unique to D")
ErrValueTypeOf!R tryUnwrapErr(R)(auto ref R result) if (isResult!R)
{
    import std.exception : enforce;

    enforce!UnwrapException(isErr(result), "Result does not have an Err value.");
    return unwrapErr(result);
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown;

    auto resultOk = Result!(uint, string)(Ok!uint(2));
    assertThrown!UnwrapException(tryUnwrapErr(resultOk));

    auto resultErr = Result!(uint, string)(Err!string("emergency failure"));
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr)) == "emergency failure");
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown;

    auto resultErr1 = Result!(int, string)(Err!string("123"));
    assert(resultErr1.tryUnwrapErr() == "123");
    assertNotThrown!UnwrapException(resultErr1.tryUnwrapErr());

    auto resultErr2 = Result!(string, uint)(Err!uint(123));
    assert(resultErr2.tryUnwrapErr() == 123);
    assertNotThrown!UnwrapException(resultErr2.tryUnwrapErr());

    auto resultOk = Result!(string, uint)(Ok!string("123"));
    assertThrown!UnwrapException(resultOk.tryUnwrapErr());
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
