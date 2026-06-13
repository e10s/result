module result;

///
struct Ok(T)
{
    ///
    T okValue;
    alias okValue this;
}

///
@safe @nogc nothrow unittest
{
    assert(Ok!int(314).okValue == 314);
    assert(Ok!int(314) == 314); // alias this
    assert(Ok!string("Good day.") == "Good day."); // alias this
}

///
struct Err(E)
{
    ///
    E errValue;
    alias errValue this;
}

///
@safe @nogc nothrow unittest
{
    assert(Err!int(314).errValue == 314);
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
    Result result;
    alias result this;

    /// The constructor accepts `Result!(T, E)`, `Ok!T` and `Err!E` values.
    this(R)(auto ref R value) if (is(typeof({ Result.init = R.init; })))
    {
        this.result = value;
    }

    /// Supports assignment of `Result!(T, E)`, `Ok!T` and `Err!E` values.
    ref opAssign(R)(auto ref R value) if (is(typeof({ Result.init = R.init; })))
    {
        this.result = value;
        return this;
    }

    /// Returns `true` if `this` has an `Ok!T` value.
    bool isOk() const
    {
        import std.sumtype : has;

        static assert(is(typeof(result) == const(Result))); // <--
        return result.has!(const(Ok!T)); // <--
    }

    /// Returns `true` if `this` has an `Err!E` value.
    bool isErr() const
    {
        import std.sumtype : has;

        static assert(is(typeof(result) == const(Result))); // <--
        return result.has!(const(Err!E)); // <--
    }

    /// Returns the containing `Ok!T` value.
    /// Throws `UnwrapException` if the value is an `Err!E`.
    T unwrap() const
    {
        if (this.isErr())
        {
            throw new UnwrapException("Bad"); // FIXME: message should be reasonable
        }

        import std.sumtype : get;

        static assert(is(typeof(result) == const(Result))); // <--
        return result.get!(const(Ok!T)).okValue;
    }

    /// Returns the contained `Ok!T` value.
    /// Or returns the contained `defaultValue` if the value is an `Err!E`.
    T unwrapOr(T defaultValue) const
    {
        if (this.isErr())
        {
            return defaultValue;
        }

        import std.sumtype : get;

        static assert(is(typeof(result) == const(Result))); // <--
        return result.get!(const(Ok!T)).okValue;
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

// isOk
@safe @nogc nothrow unittest
{
    auto resultOk = Result!(int, string)(Ok!int(123));
    assert(resultOk.isOk());
    const constResultOk = Result!(int, string)(Ok!int(123));
    assert(constResultOk.isOk());
    immutable immutableResultOk = Result!(int, string)(Ok!int(123));
    assert(immutableResultOk.isOk());

    auto resultErr = Result!(int, string)(Err!string("123"));
    assert(!resultErr.isOk());
    const constResultErr = Result!(int, string)(Err!string("123"));
    assert(!constResultErr.isOk());
    immutable immutableResultErr = Result!(int, string)(Err!string("123"));
    assert(!immutableResultErr.isOk());
}

// isErr
@safe @nogc nothrow unittest
{
    auto resultErr = Result!(int, string)(Err!string("123"));
    assert(resultErr.isErr());
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

// unwrap
unittest
{
    import std.exception : assertThrown, assertNotThrown;

    auto resultOk1 = Result!(int, string)(Ok!int(123));
    static assert(is(typeof(resultOk1.unwrap()) == int));
    assert(resultOk1.unwrap() == 123);
    assertNotThrown!UnwrapException(resultOk1.unwrap());

    auto resultOk2 = Result!(string, uint)(Ok!string("123"));
    static assert(is(typeof(resultOk2.unwrap()) == string));
    assert(resultOk2.unwrap() == "123");
    assertNotThrown!UnwrapException(resultOk1.unwrap());

    auto resultErr = Result!(string, uint)(Err!uint(123));
    assertThrown!UnwrapException(resultErr.unwrap());
}

// unwrapOp
@safe @nogc nothrow unittest
{
    auto resultOk1 = Result!(int, string)(Ok!int(123));
    static assert(is(typeof(resultOk1.unwrapOr(456)) == int));
    assert(resultOk1.unwrapOr(456) == 123);

    auto resultOk2 = Result!(string, uint)(Ok!string("123"));
    static assert(is(typeof(resultOk2.unwrapOr("456")) == string));
    assert(resultOk2.unwrapOr("456") == "123");

    auto resultErr = Result!(string, uint)(Err!uint(123));
    static assert(is(typeof(resultErr.unwrapOr("456")) == string));
    assert(resultErr.unwrapOr("456") == "456");
}
