# yares: Yet another Result type for D

`Result!(T, E)` is a type for D programs that need to return either a successful value or an error value from a function.

Its design is heavily inspired by Rust's `Result` and C++'s `expected`.

A `Result!(T, E)` object stores one of two states:

- the operation succeeded and contains a value of type `T`.
- the operation failed and contains an error of type `E`.

The error type is chosen by the caller.
It can be a `string`, an `Exception`, a user-defined `struct`, or any other type that fits the application.
The module does not prescribe how errors should be logged or handled.

## Basic use

The following example validates input and then handles the result explicitly.

```d
import yares;
import std.conv : ConvException, to;
import std.stdio : writeln;

Result!(int, string) parsePositiveInt(string text)
{
    try
    {
        auto value = to!int(text);
        return value > 0 ?
            Result!(int, string).success(value) :
            Result!(int, string).error("Value must be positive");
    }
    catch (ConvException)
    {
        return Result!(int, string).error("Invalid integer");
    }
}

auto parsed = parsePositiveInt("42");
if (parsed.isSuccess)
{
    writeln("Value: ", unwrap(parsed));
}
else
{
    writeln("Error: ", unwrapError(parsed));
}
```

For a success state with no value, use `Result!(void, E)`.

## Core types and construction

<table>
<thead>
<tr>
<th>Type</th>
<th>Description</th>
</tr>
</thead>
<tbody>
<tr>
<td><code>Result!(T, E)</code></td>
<td>Holds either a successful <code>T</code> value or an error <code>E</code> value.
<code>T</code> may be <code>void</code> when success has no payload.</td>
</tr>
<tr>
<td><code>ErrorValue!E</code></td>
<td>Wraps an error value. Used for assigning the error to a <code>Result</code>.
Its value is available through <code>.error</code>.</td>
</tr>
<tr>
<td><code>UnwrapException</code></td>
<td>Thrown by <code>tryUnwrap</code> or <code>tryUnwrapError</code> when the requested state is not present.</td>
</tr>
<tr>
<td><code>std.sumtype.SumType!(T, ErrorValue!E)</code></td>
<td>The underlying <code>SumType</code> for a non-<code>void</code> <code>T</code>.
It can be obtained by referring to <code>.payload</code> field of a <code>Result</code>.</td>
</tr>
<tr>
<td><code>std.typecons.Nullable!(ErrorValue!E)</code></td>
<td>The underlying <code>Nullable</code> for a <code>void</code> <code>T</code>.
It can be obtained by referring to <code>.payload</code> field of a <code>Result</code>.</td>
</tr>
</tbody>
</table>

Note that `Result!(T, E)` rejects `void` as `E` and prevents using `ErrorValue!X` as `T`.

`Result` also provides the following static member functions to construct `Result` objects easily.

<table>
<thead>
<tr>
<th>Function</th>
<th>Description</th>
</tr>
</thead>
<tbody>
<tr>
<td><code>Result!(T, E).success(value)</code></td>
<td>Creates a successful result containing <code>value</code> of <code>T</code>.</td>
</tr>
<tr>
<td><code>Result!(void, E).success()</code></td>
<td>Creates a successful result with no value.</td>
</tr>
<tr>
<td><code>Result!(T, E).error(error)</code></td>
<td>Creates an error result containing <code>error</code> of <code>E</code>.</td>
</tr>
</tbody>
</table>

## API reference

UFCS-friendly functions are provided.

The tables below summarize the predefined functions for `Result`.
In the tables, `t` is a success value, `e` is an error value,
and `*` means that the behavior depends on the state rather than the value.
If `T` is `void`, interpret the table entries appropriately.

### State checks and extraction

<table>
<thead>
<tr>
<th>Property</th>
<th><code>this</code></th>
<th>Output</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td rowspan="2"><code>r.isSuccess</code></td>
<td><code>Result!(T, E).success(*)</code></td>
<td><code>true</code></td>
<td rowspan="2">Equivalent to <code>!isError(r)</code></td>
</tr>
<tr>
<td><code>Result!(T, E).error(*)</code></td>
<td><code>false</code></td>
</tr>
</tbody>
</table>

<table>
<thead>
<tr>
<th>Function</th>
<th>Input</th>
<th>Output</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td rowspan="2"><code>isSuccessAnd!pred(r)</code></td>
<td><code>Result!(T, E).success(t)</code></td>
<td><code>pred(t)</code></td>
<td rowspan="2">For a non-<code>void</code> <code>T</code></td>
</tr>
<tr>
<td><code>Result!(T, E).error(*)</code></td>
<td><code>false</code></td>
</tr>
<tr>
<td rowspan="2"><code>isError(r)</code></td>
<td><code>Result!(T, E).success(*)</code></td>
<td><code>false</code></td>
<td rowspan="2">Equivalent to <code>!isSuccess(r)</code></td>
</tr>
<tr>
<td><code>Result!(T, E).error(*)</code></td>
<td><code>true</code></td>
</tr>
<tr>
<td rowspan="2"><code>isErrorAnd!pred(r)</code></td>
<td><code>Result!(T, E).success(*)</code></td>
<td><code>false</code></td>
<td></td>
</tr>
<tr>
<td><code>Result!(T, E).error(e)</code></td>
<td><code>pred(e)</code></td>
<td></td>
</tr>
<tr>
<td rowspan="2"><code>nullableSuccess(r)</code></td>
<td><code>Result!(T, E).success(t)</code></td>
<td><code>nullable(t)</code></td>
<td rowspan="2">For a non-<code>void</code> <code>T</code></td>
</tr>
<tr>
<td><code>Result!(T, E).error(*)</code></td>
<td><code>Nullable!T.init</code> (the null state)</td>
</tr>
<tr>
<td rowspan="2"><code>nullableError(r)</code></td>
<td><code>Result!(T, E).success(*)</code></td>
<td><code>Nullable!E.init</code> (the null state)</td>
<td></td>
</tr>
<tr>
<td><code>Result!(T, E).error(e)</code></td>
<td><code>nullable(e)</code></td>
<td></td>
</tr>
<tr>
<td><code>unwrap(r)</code></td>
<td><code>Result!(T, E).success(t)</code></td>
<td><code>t</code></td>
<td></td>
</tr>
<tr>
<td rowspan="2"><code>unwrapError(r)</code></td>
<td><code>Result!(T, E).error(e)</code></td>
<td><code>e</code></td>
<td></td>
</tr>
</tbody>
</table>

Use `isSuccess` or `isError` before `unwrap` and `unwrapError` when the contained state is unknown.
The `Nullable`-returning `ok` and `err` functions are useful when absence should be represented as a value.

### Checked unwrapping and fallback values

<table>
<thead>
<tr>
<th>Function</th>
<th>Input</th>
<th>Output</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td rowspan="2"><code>tryUnwrap(r, msg)</code></td>
<td><code>Result!(T, E).success(t)</code></td>
<td><code>t</code></td>
<td></td>
</tr>
<tr>
<td><code>Result!(T, E).error(*)</code></td>
<td></td>
<td>Throws <code>UnwrapException</code>.</td>
</tr>
<tr>
<td rowspan="2"><code>tryUnwrapError(r, msg)</code></td>
<td><code>Result!(T, E).success(*)</code></td>
<td></td>
<td>Throws <code>UnwrapException</code>.</td>
</tr>
<tr>
<td><code>Result!(T, E).error(e)</code></td>
<td><code>e</code></td>
<td></td>
</tr>
<tr>
<td rowspan="2"><code>unwrapOr(r, defaultValue)</code></td>
<td><code>Result!(T, E).success(t)</code></td>
<td><code>t</code></td>
<td rowspan="2">For a non-<code>void</code> <code>T</code></td>
</tr>
<tr>
<td><code>Result!(T, E).error(*)</code></td>
<td><code>defaultValue</code></td>
</tr>
<tr>
<td rowspan="2"><code>unwrapOrElse!fun(r)</code></td>
<td><code>Result!(T, E).success(t)</code></td>
<td><code>t</code></td>
<td rowspan="2">For a non-<code>void</code> <code>T</code></td>
</tr>
<tr>
<td><code>Result!(T, E).error(e)</code></td>
<td><code>fun(e)</code></td>
</tr>
<tr>
<td rowspan="3"><code>unwrapErrorOr(r, defaultValue)</code></td>
<td><code>Result!(T, E).success(*)</code></td>
<td><code>defaultValue</code></td>
<td></td>
</tr>
<tr>
<td><code>Result!(T, E).error(e)</code></td>
<td><code>e</code></td>
<td></td>
</tr>
</tbody>
</table>

`tryUnwrap` and `tryUnwrapError` accept an optional message.

### Chaining and mapping

<table>
<thead>
<tr>
<th>Function</th>
<th>Input</th>
<th>Output</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td rowspan="2"><code>and(r1, r2)</code></td>
<td><code>Result!(T, E).success(*)</code>, <code>Result!(U, E)</code></td>
<td><code>r2</code></td>
<td></td>
</tr>
<tr>
<td><code>Result!(T, E).error(e)</code>, <code>Result!(U, E)</code></td>
<td><code>Result!(U, E).error(e)</code></td>
<td></td>
</tr>
<tr>
<td rowspan="2"><code>andThen!fun(r)</code></td>
<td><code>Result!(T, E).success(t)</code></td>
<td><code>fun(t)</code></td>
<td rowspan="2"><code>Result!(U, E) fun(T);</code> and for a non-<code>void</code> <code>T</code></td>
</tr>
<tr>
<td><code>Result!(T, E).error(e)</code></td>
<td><code>Result!(U, E).error(e)</code></td>
</tr>
<tr>
<td rowspan="2"><code>or(r1, r2)</code></td>
<td><code>Result!(T, E).success(t)</code>, <code>Result!(T, F)</code></td>
<td><code>Result!(T, F).success(t)</code></td>
<td></td>
</tr>
<tr>
<td><code>Result!(T, E).error(*)</code>, <code>Result!(T, F)</code></td>
<td><code>r2</code></td>
<td></td>
</tr>
<tr>
<td rowspan="2"><code>orElse!fun(r)</code></td>
<td><code>Result!(T, E).success(t)</code></td>
<td><code>Result!(T, F).success(t)</code></td>
<td rowspan="2"><code>Result!(T, F) fun(E);</code></td>
</tr>
<tr>
<td><code>Result!(T, E).error(e)</code></td>
<td><code>fun(e)</code></td>
</tr>
<tr>
<td rowspan="2"><code>map!fun(r)</code></td>
<td><code>Result!(T, E).success(t)</code></td>
<td><code>Result!(U, E).success(fun(t))</code></td>
<td rowspan="2"><code>U fun(T);</code></td>
</tr>
<tr>
<td><code>Result!(T, E).error(e)</code></td>
<td><code>Result!(U, E).error(e)</code></td>
</tr>
<tr>
<td rowspan="2"><code>mapError!fun(r)</code></td>
<td><code>Result!(T, E).success(t)</code></td>
<td><code>Result!(T, F).success(t)</code></td>
<td rowspan="2"><code>F fun(E);</code></td>
</tr>
<tr>
<td><code>Result!(T, E).error(e)</code></td>
<td><code>Result!(T, F).error(fun(e))</code></td>
</tr>
<tr>
<td rowspan="2"><code>mapOr!fun(r, defaultValue)</code></td>
<td><code>Result!(T, E).success(t)</code></td>
<td><code>fun(t)</code></td>
<td rowspan="2">For a non-<code>void</code> <code>T</code></td>
</tr>
<tr>
<td><code>Result!(T, E).error(*)</code></td>
<td><code>defaultValue</code></td>
</tr>
<tr>
<td rowspan="2"><code>mapOrElse!(defaultFun,fun)(r)</code></td>
<td><code>Result!(T, E).success(t)</code></td>
<td><code>fun(t)</code></td>
<td rowspan="2">For a non-<code>void</code> <code>T</code></td>
</tr>
<tr>
<td><code>Result!(T, E).error(e)</code></td>
<td><code>defaultFun(e)</code></td>
</tr>
</tbody>
</table>

### Inspection

<table>
<thead>
<tr>
<th>Function</th>
<th>Input</th>
<th>Output</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td rowspan="2"><code>inspect!fun(r)</code></td>
<td><code>Result!(T, E).success(t)</code></td>
<td><code>r</code></td>
<td>Calls <code>fun(t)</code> before returning.</td>
</tr>
<tr>
<td><code>Result!(T, E).error(*)</code></td>
<td><code>r</code></td>
<td></td>
</tr>
<tr>
<td rowspan="2"><code>inspectError!fun(r)</code></td>
<td><code>Result!(T, E).success(*)</code></td>
<td><code>r</code></td>
<td></td>
</tr>
<td><code>Result!(T, E).error(e)</code></td>
<td><code>r</code></td>
<td>Calls <code>fun(e)</code> before returning.</td>
</tr>
</tbody>
</table>

`inspect` and `inspectError` are intended for side effects such as logging or
debugging while preserving the result for subsequent operations.

### Structural helpers

<table>
<thead>
<tr>
<th>Function</th>
<th>Input</th>
<th>Output</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td rowspan="3"><code>transpose(r)</code></td>
<td><code>Result!(Nullable!T, E).success(nullable(t))</code></td>
<td><code>nullable(Result!(Nullable!T, E).success(t))</code></td>
<td rowspan="3">For a non-<code>void</code> <code>T</code></td>
</tr>
<tr>
<td><code>Result!(Nullable!T, E).success(Nullable!T.init)</code></td>
<td><code>Nullable!(Result!(T, E)).init</code> (the null state)</td>
</tr>
<tr>
<td><code>Result!(Nullable!T, E).error(e)</code></td>
<td><code>nullable(Result!(Nullable!T, E).error(e))</code></td>
</tr>
<tr>
<td rowspan="2"><code>flatten(r)</code></td>
<td><code>Result!(Result!(T, E), E).success(inner)</code></td>
<td><code>inner</code></td>
<td></td>
</tr>
<tr>
<td><code>Result!(Result!(T, E), E).error(e)</code></td>
<td><code>Result!(T, E).error(e)</code></td>
<td></td>
</tr>
</tbody>
</table>

## More information

[The official documentation](https://e10s.github.io/yares/), generated with [adrdox](https://code.dlang.org/packages/adrdox), is available.
To create an offline copy, run:

```sh
dub fetch adrdox
dub run adrdox -- -i path/to/yares/source
```

## License

This project is available under the MIT License. See [LICENSE](LICENSE).
