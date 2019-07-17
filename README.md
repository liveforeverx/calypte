# Calypte

Small embeddable, flexible rule-based engine framework. To be really embeddable, it uses pluggable
architecture and concept of rule `lifecycle`. Users of rule engine will need to configure and plug
and change behaviour via `callbacks`.

Example would be, how to implement persistence. Rule engine works in memory, but you can plug different
behaviours, which can implement callback `after_execute` and persist changes. With this approach you
can have different behaviours, like: `SaveAfterExec`, `SaveBySideEffect` and different storages
(DGraph, Postgresql). `after_execute` - callback allows to write audit log(in any place of your choise),
which is very important to understand, which rules applied, which not (some solutions doesn't
provide this feature).

Via callback in lifecycle `load_data` the data will be loaded and should be updated, if there any
change available in extern source (so it interact with a source of truth via loading data and
actions and loading data back, so without direct persistence at all).

The rule language will have a pluggable interface for functions, which can be used to implement
functions for the applied domain, and meta information, which can be accessed by `lifecycle` modules t
o modify behaviour of rules based on this meta information.

Little bit complexer example: by implementing a function, this function can set meta information (
for example `side_effect: true`), and if a rule using this function, than module `SaveBySideEffect`
can persist information if any side effect functions were used.

The concept of rule evaluation and execution life cycle and user defined functions should allow to
embedd rule processing to different systems, storages and use cases.

The intern representation of data is a graph (candidate for it: [libgraph](https://github.com/bitwalker/libgraph)).

Inference algorythm, which will be used is RETE (or inspired by RETE), so that rule condition graph
is build, where the same conditions from different rules grouped togehter, so that we can check if
a condition doesn't eval to true, than we can ignore all rules, which have this condition in one go.

Using forward chaining algorythm there is, because rule-based systems (in my personal opinion) should
support dynamic situations and forward chaining is better suited for dynamic situations, where data
changes and only subpart should be evaluated to produce new inferences. Backwards chaining shines
more in static query-like analytic questions, where my goal to support long running dynamic inference
cases first. But there are exstensions for RETE, which uses rete network for backwards chaining, so
it can be extended and explored in a future.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `calypte` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:calypte, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/calypte](https://hexdocs.pm/calypte).

### Language

Goals to have compact language (exstensible via meta information and domain functions), which will
looks like this (may be changed):

```
@if
  $father isa Person
    gender == "male"

  $child isa Person ($father has:child $child)
    age < 18

@then
  ...
```

## Very initial Roadmap

- [ ] language
  - [ ] int - signed 64 bit integer
  - [ ] float/decimal - float or decimal
  - [ ] string - string
  - [ ] bool - boolean
  - [ ] datetime - datetime
  - [ ] list - list
  - [ ] meta information
  - [ ] type definitions
  - [ ] relationship matching
- [ ] rule compiler
- [ ] graph of interconnected nodes
  - [ ] node representation
  - [ ] graph traversing
- [ ] processing rule matching network (inspired by RETE)
  - [ ] building condition graph
  - [ ] propagate nodes to rules graph
- [ ] life cycle