module result;
import std.functional : not;
import std.functional : unaryFun;
import std.typecons : Nullable;

private mixin template OkErrImpl(X)
{
    private X value_;
    @property ref value() const
    {
        return value_;
    }

    bool opEquals(scope const X rhs) const
    {
        return value_ == rhs;
    }

    bool opEquals(scope const ref X rhs) const
    {
        return value_ == rhs;
    }

    size_t toHash() const
    {
        return hashOf(value);
    }

    alias value this;
}

///
struct Ok(T)
{
    mixin OkErrImpl!T;
}

///
unittest
{
    assert(Ok!int(314) == Ok!int(314));
    assert(Ok!int(314).value == 314);
    assert(Ok!int(314) == 314);
    assert(Ok!string("Good day.") == "Good day.");

    class K
    {
    }

    assert(Ok!K(new K) != Ok!K(new K));
}

///
struct Err(E)
{
    mixin OkErrImpl!E;
}

///
unittest
{
    assert(Err!int(314) == Err!int(314));
    assert(Err!int(314).value == 314);
    assert(Err!int(314) == 314);
    assert(Err!string("Good day.") == "Good day.");

    class K
    {
    }

    assert(Err!K(new K) != Err!K(new K));
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

    // The constructor accepts `Ok!T` and `Err!E` values.
    private this(PT)(auto ref PT value) if (is(PT == Ok!T) || is(PT == Err!E))
    {
        payload = value;
    }

    /// Supports assignment of [Result]
    ref opAssign(R)(auto ref R rhs)
            if (isResult!R && is(typeof({ Payload.init = R.Payload.init; })))
    {
        payload = rhs.payload;
        return this;
    }

    /// Constructs [Result]`!(T, E)` that has [Ok]`!T` with `value`.
    @("Unique to D")
    static Result!(T, E) ok(T value)
    {
        return Result!(T, E)(Ok!T(value));
    }

    /// Constructs [Result]`!(T, E)` that has [Err]`!E` with `value`.
    @("Unique to D")
    static Result!(T, E) err(E value)
    {
        return Result!(T, E)(Err!E(value));
    }
}

// static wrapper of ctor
@safe @nogc nothrow unittest
{
    assert(Result!(int, string).ok(3) == Result!(int, string)(Ok!int(3)));
    assert(Result!(int, string).err("3") == Result!(int, string)(Err!string("3")));
}

// Ctor
@safe @nogc nothrow unittest
{
    import std.sumtype : has, get;

    auto resultOk = Result!(int, string)(Ok!int(123));
    assert(resultOk.has!(Ok!int));
    assert(!resultOk.has!(Err!string));
    assert(resultOk.get!(Ok!int) == Ok!int(123));

    const cResultOk = Result!(int, string)(Ok!int(123));
    assert(!cResultOk.has!(Ok!int));
    assert(!cResultOk.has!(Err!string));
    assert(cResultOk.has!(const(Ok!int)));
    assert(!cResultOk.has!(const(Err!string)));
    assert(cResultOk.get!(const(Ok!int)) == Ok!int(123));
    immutable iResultOk = Result!(int, string)(Ok!int(123));
    assert(!iResultOk.has!(Ok!int));
    assert(!iResultOk.has!(Err!string));
    assert(iResultOk.has!(immutable(Ok!int)));
    assert(!iResultOk.has!(immutable(Err!string)));
    assert(iResultOk.get!(immutable(Ok!int)) == Ok!int(123));
    auto resultErr = Result!(bool, dstring)(Err!dstring("123"d));
    assert(resultErr.has!(Err!dstring));
    assert(!resultErr.has!(Ok!bool));
    assert(resultErr.get!(Err!dstring) == Err!dstring("123"d));
    const cResultErr = Result!(bool, dstring)(Err!dstring("123"d));
    assert(!cResultErr.has!(Ok!bool));
    assert(!cResultErr.has!(Err!dstring));
    assert(!cResultErr.has!(const(Ok!bool)));
    assert(cResultErr.has!(const(Err!dstring)));
    assert(cResultErr.get!(const(Err!dstring)) == Err!dstring("123"d));

    immutable iResultErr = Result!(bool, dstring)(Err!dstring("123"d));
    assert(!iResultErr.has!(Ok!bool));
    assert(!iResultErr.has!(Err!dstring));
    assert(!iResultErr.has!(immutable(Ok!bool)));
    assert(iResultErr.has!(immutable(Err!dstring)));
    assert(iResultErr.get!(immutable(Err!dstring)) == Err!dstring("123"d));
}

// opAssign
@trusted @nogc nothrow unittest
{
    import std.sumtype : get;

    auto result1 = Result!(int, string).err("333");
    auto result2 = Result!(int, string).err("3");

    result2 = result1;
    assert(result2.get!(Err!string) == Err!string("333"));
    const result3 = Result!(int, string).ok(100);
    result2 = result3;
    assert(result2.get!(Ok!int) == Ok!int(100));
    immutable result4 = Result!(int, string).err("1000");
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

/// Returns `true` if `r` has an [Ok] value.
bool isOk(T, E)(scope const auto ref Result!(T, E) r)
{
    import std.sumtype : match;

    return r.payload.match!((Ok!T _) => true, (Err!E _) => false);
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

/// Returns `true` if `r` has an [Ok] value and its value satisfies `pred`.
bool isOkAnd(alias pred = "a", T, E)(scope const auto ref Result!(T, E) r)
        if (is(typeof(unaryFun!pred(T.init))))
{
    return isOk(r) && unaryFun!pred(unwrap(r));
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

/// Returns `true` if `this` has an `Err!E` value.
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

/// Returns `true` if `r` has an [Err] value and its value satisfies `pred`.
bool isErrAnd(alias pred = "a", T, E)(scope const auto ref Result!(T, E) r)
        if (is(typeof(unaryFun!pred(E.init))))
{
    return isErr(r) && unaryFun!pred(unwrapErr(r));
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

/// Converts from [Result]`!(T, E)` to `Nullable!T`.
Nullable!T ok(T, E)(scope const auto ref Result!(T, E) r)
{
    if (isErr(r))
    {
        return Nullable!T.init;
    }

    return Nullable!T(unwrap(r));
}

///
@safe nothrow unittest
{
    alias R = Result!(uint, string);

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

/// Converts from [Result]`!(T, E)` to `Nullable!E`.
Nullable!E err(T, E)(scope const auto ref Result!(T, E) r)
{
    if (isOk(r))
    {
        return Nullable!E.init;
    }

    return Nullable!E(unwrapErr(r));
}

///
@safe nothrow unittest
{
    alias R = Result!(uint, string);

    auto resultOk = R.ok(2);
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

/// Returns `r2` if `r1` is [Ok], otherwise returns `Result!(U, E)` with `r1`'s [Err] value.
Result!(U, E) and(T, U, E)(scope const auto ref Result!(T, E) r1, scope const auto ref Result!(U, E) r2)
{
    if (isOk(r1))
    {
        return r2;
    }

    return Result!(U, E).err(unwrapErr(r1));
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

@safe @nogc nothrow unittest
{
    alias R = Result!(uint, string);
    alias S = Result!(string, string);

    immutable x1 = R.ok(2);
    auto y1 = S.err("late error");
    assert(and(x1, y1) == S.err("late error"));

    auto x2 = R.err("early error");
    const y2 = S.ok("foo");
    assert(and(x2, y2) == S.err("early error"));

    const x3 = R.err("not a 2");
    immutable y3 = S.err("late error");
    assert(and(x3, y3) == S.err("not a 2"));

    immutable x4 = R.ok(2);
    immutable y4 = S.ok("different result type");
    assert(and(x4, y4) == S.ok("different result type"));
}

/// Calls `fun` with the [Ok] value if `r` is [Ok],
/// otherwise returns a new result with `r`'s [Err] value.

auto andThen(alias fun = "a", T, E)(scope const auto ref Result!(T, E) r)
        if (is(E == ErrValueTypeOf!(typeof(unaryFun!fun(T.init)))))
{
    alias U = OkValueTypeOf!(typeof(unaryFun!fun(T.init)));
    alias S = Result!(U, E);

    if (isErr(r))
    {
        return S.err(unwrapErr(r));
    }

    return cast(S) unaryFun!fun(unwrap(r));
}

// FIXME: need to reproduce `Option`
///
@safe nothrow unittest
{
    alias Q = Result!(uint, string);
    alias R = Result!(string, bool);
    alias S = Result!(string, string);

    auto checkedMulToString(uint x, uint y)
    {
        import std.checkedint : opChecked;

        bool overflow;
        immutable r = opChecked!"*"(x, y, overflow);
        if (overflow)
        {
            return R.err(true);
        }
        import std.conv : to;

        return R.ok(to!string(r));
    }

    auto sqThenToString(uint x)
    {
        return orElse!(r => S.err("overflowed"))(checkedMulToString(x, x));
    }

    assert(andThen!sqThenToString(Q.ok(2)) == S.ok("4"));
    assert(andThen!sqThenToString(Q.ok(1_000_000)) == S.err("overflowed"));
    assert(andThen!sqThenToString(Q.err("not a number")) == S.err("not a number"));
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

/// Returns `r2` if `result1` is [Err], otherwise returns a new result of `S` with `r1`'s [Ok] value.
Result!(T, F) or(T, E, F)(scope const auto ref Result!(T, E) r1, scope const auto ref Result!(T, F) r2)
{
    if (isErr(r1))
    {
        return r2;
    }

    return Result!(T, F).ok(unwrap(r1));
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

/// Calls `fun` with the [Err] value if `result` is [Err],
/// otherwise returns a new result with `result`'s [Ok] value.
auto orElse(alias fun = "a", T, E)(scope const auto ref Result!(T, E) r)
        if (is(T == OkValueTypeOf!(typeof(unaryFun!fun(E.init)))))
{
    alias F = ErrValueTypeOf!(typeof(unaryFun!fun(E.init)));
    alias S = Result!(T, F);

    if (isOk(r))
    {
        return S.ok(unwrap(r));
    }

    return cast(S) unaryFun!fun(unwrapErr(r));
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

/// Returns the containing `Ok!T` value.
T unwrap(T, E)(scope const auto ref Result!(T, E) r)
{
    assert(isOk(r), "Result does not have an Ok value.");

    import std.sumtype : get;

    return r.payload.get!(QualifiedOkTypeOf!(typeof(r))).value;
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
    assertThrown!AssertError(unwrap(resultErr)); // Assert will fail, due to SumType
}

unittest
{
    import std.exception : assertThrown, assertNotThrown;
    import core.exception : AssertError;

    auto resultOk1 = Result!(int, string).ok(123);
    assert(assertNotThrown!AssertError(unwrap(resultOk1)) == 123);

    alias R = Result!(string, uint);

    auto resultOk2 = R.ok("123");
    assert(assertNotThrown!AssertError(unwrap(resultOk2)) == "123");

    auto resultErr = R.err(123);
    assertThrown!AssertError(unwrap(resultErr));
}

/// Returns the contained `Err!E` value.
E unwrapErr(T, E)(scope const auto ref Result!(T, E) r)
{
    assert(isErr(r), "Result does not have an Err value.");

    import std.sumtype : get;

    return r.payload.get!(QualifiedErrTypeOf!(typeof(r))).value;
}

///
unittest
{
    import std.exception : assertThrown;
    import core.exception : AssertError;

    alias R = Result!(uint, string);

    auto resultOk = R.ok(2);
    assertThrown!AssertError(unwrapErr(resultOk)); // Assert will fail, due to SumType

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

/// Returns the containing `Ok!T` value.
/// Throws `UnwrapException` with `msg` if the value is an `Err!E`.
T expect(T, E)(scope const auto ref Result!(T, E) r, string msg)
{
    import std.exception : enforce;

    enforce!UnwrapException(isOk(r), msg);
    return unwrap(r);
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    alias R = Result!(uint, string);

    auto resultOk = R.ok(2);
    assert(assertNotThrown!UnwrapException(expect(resultOk, "Testing expect")) == 2);

    auto resultErr = R.err("emergency failure");
    assertThrown!UnwrapException(expect(resultErr, "Testing expect"));
    assert(collectExceptionMsg(expect(resultErr, "Testing expect")) == "Testing expect");
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    auto resultOk1 = Result!(int, string).ok(123);
    assert(assertNotThrown!UnwrapException(expect(resultOk1, "foo")) == 123);

    alias R = Result!(string, uint);

    auto resultOk2 = R.ok("123");
    assert(assertNotThrown!UnwrapException(expect(resultOk2, "foo")) == "123");

    auto resultErr = R.err(123);
    assertThrown!UnwrapException(expect(resultErr, "foo"));
    assert(collectExceptionMsg(expect(resultErr, "foo")) == "foo");
}

/// Returns the contained `Err!E` value.
/// Throws `UnwrapException` with `msg` if the value is an `Ok!T`.
E expectErr(T, E)(scope const auto ref Result!(T, E) r, string msg)
{
    import std.exception : enforce;

    enforce!UnwrapException(isErr(r), msg);
    return unwrapErr(r);
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    alias R = Result!(uint, string);

    auto resultOk = R.ok(2);
    assertThrown!UnwrapException(expectErr(resultOk, "Testing expectErr"));
    assert(collectExceptionMsg(expectErr(resultOk, "Testing expectErr")) == "Testing expectErr");

    auto resultErr = R.err("emergency failure");
    assert(assertNotThrown!UnwrapException(expectErr(resultErr,
            "Testing expectErr")) == "emergency failure");
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown, collectExceptionMsg;

    auto resultErr1 = Result!(int, string).err("123");
    assert(assertNotThrown!UnwrapException(expectErr(resultErr1, "bar")) == "123");

    alias R = Result!(string, uint);

    auto resultErr2 = R.err(123);
    assert(assertNotThrown!UnwrapException(expectErr(resultErr2, "bar")) == 123);

    auto resultOk = R.ok("123");
    assertThrown!UnwrapException(expectErr(resultOk, "bar"));
    assert(collectExceptionMsg(expectErr(resultOk, "bar")) == "bar");
}

/// Returns the containing `Ok!T` value.
/// Throws `UnwrapException` if the value is an `Err!E`.
@("Unique to D")
T tryUnwrap(T, E)(scope const auto ref Result!(T, E) r)
{
    return expect(r, "Result does not have an Ok value.");
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown;

    alias R = Result!(uint, string);

    auto resultOk = R.ok(2);
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk)) == 2);

    auto resultErr = R.err("emergency failure");
    assertThrown!UnwrapException(tryUnwrap(resultErr));
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown;

    auto resultOk1 = Result!(int, string).ok(123);
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk1)) == 123);

    alias R = Result!(string, uint);

    auto resultOk2 = R.ok("123");
    assert(assertNotThrown!UnwrapException(tryUnwrap(resultOk2)) == "123");

    auto resultErr = R.err(123);
    assertThrown!UnwrapException(tryUnwrap(resultErr));
}

/// Returns the contained `Err!E` value.
/// Throws `UnwrapException` if the value is an `Ok!T`.
@("Unique to D")
E tryUnwrapErr(T, E)(scope const auto ref Result!(T, E) r)
{
    return expectErr(r, "Result does not have an Err value.");
}

///
@safe unittest
{
    import std.exception : assertThrown, assertNotThrown;

    alias R = Result!(uint, string);

    auto resultOk = R.ok(2);
    assertThrown!UnwrapException(tryUnwrapErr(resultOk));

    auto resultErr = R.err("emergency failure");
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr)) == "emergency failure");
}

@safe unittest
{
    import std.exception : assertThrown, assertNotThrown;

    auto resultErr1 = Result!(int, string).err("123");
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr1)) == "123");

    alias R = Result!(string, uint);

    auto resultErr2 = R.err(123);
    assert(assertNotThrown!UnwrapException(tryUnwrapErr(resultErr2)) == 123);

    auto resultOk = R.ok("123");
    assertThrown!UnwrapException(tryUnwrapErr(resultOk));
}

/// Returns the contained `Ok!T` value.
/// Or returns `defaultValue` if the contained value is an `Err!E`.
T unwrapOr(T, E)(scope const auto ref Result!(T, E) r, T defaultValue)
{
    if (isErr(r))
    {
        return defaultValue;
    }

    return unwrap(r);
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

@safe @nogc nothrow unittest
{
    auto resultOk1 = Result!(int, string).ok(123);
    assert(unwrapOr(resultOk1, 456) == 123);

    alias R = Result!(string, uint);

    const resultOk2 = R.ok("123");
    assert(unwrapOr(resultOk2, "456") == "123");

    auto resultErr = R.err(123);
    assert(unwrapOr(resultErr, "456") == "456");
}

/// Returns the contained `Ok!T` value.
/// Or returns `T.init` if the contained value is an `Err!E`.
T unwrapOrDefault(T, E)(scope const auto ref Result!(T, E) r)
{
    return unwrapOr(r, T.init);
}

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

    assert(unwrapOrDefault(parse(goodYearFromInput)) == 1909);
    assert(unwrapOrDefault(parse(badYearFromInput)) == 0);
}

@safe @nogc nothrow unittest
{
    auto resultOk1 = Result!(int, string).ok(123);
    assert(unwrapOrDefault(resultOk1) == 123);

    alias R = Result!(string, uint);

    const resultOk2 = R.ok("123");
    assert(unwrapOrDefault(resultOk2) == "123");

    auto resultErr = R.err(123);
    assert(unwrapOrDefault(resultErr) == "");
}

/// Returns the contained `Ok!T` value.
/// If the value is an `Err!E`, calls `fun` with the value of `Err!E` and returns the resulting `Ok!T` value.
T unwrapOrElse(alias fun = "a", T, E)(scope const auto ref Result!(T, E) r)
        if (is(typeof(unaryFun!fun(E.init)) : T))
{
    if (isErr(r))
    {
        return unaryFun!fun(unwrapErr(r));
    }

    return unwrap(r);
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
