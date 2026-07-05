# Result Demo

This demo shows how to use the `yares` library in D.

## Run the demo

Open a terminal in the `result_demo` directory and run:

    dub

## What this demo shows

- Parsing input text into a positive integer and returning a `Result` with user-friendly errors
- Chaining operations using `andThen` and `map` to compose success flows
- Handling success and failure explicitly with `match`
- Converting thrown exceptions into a `Result` and reporting them cleanly
- Formatting successful numeric output and emitting readable error messages

## Expected output

When the demo runs successfully, you should see output similar to:

    === yares demo ===

    Success: 6.00
    Failure: Value must be a positive integer
    Caught exception: Unexpected 'n' when converting from type string to type int
