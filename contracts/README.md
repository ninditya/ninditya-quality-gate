# API ↔ web contracts

Each file is one response the web app depends on, written once and checked from
both sides:

- the API suite (`api/spec/requests/contract_spec.rb`) asserts the real response
  has exactly this shape;
- the web suite renders these same files through the components that consume
  them and asserts what the user sees.

A field renamed, dropped or retyped on either side turns one of the two suites
red. That is the whole point: the two services can no longer drift apart
silently.

To change a contract, change the file here first, then make both suites green.
`null` in a fixture means "nullable"; the other side may send any type there.
