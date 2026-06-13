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
    auto result = Result!(int, string)(Ok!int(123));
    assert(result.isOk());
    const constResult = Result!(int, string)(Ok!int(123));
    assert(constResult.isOk());
    immutable immutableResult = Result!(int, string)(Ok!int(123));
    assert(immutableResult.isOk());
}
