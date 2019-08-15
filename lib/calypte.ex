defmodule Calypte do
  @moduledoc """
  Documentation for Calypte.
  """

  alias Calypte.{
    Binding,
    Changeset,
    Context,
    Compiler,
    Engine,
    LogEntry,
    Graph,
    Rule,
    Truth,
    Utils
  }

  import Utils

  @doc """
  Parse and compile rule
  """
  def string(str, opts \\ []) do
    with {:ok, parsed} <- parse(str, opts), do: compile(parsed)
  end

  @doc """
  The same as `string/2`, but returns compiled rule or raises error
  """
  def string!(str, opts \\ []) do
    case string(str, opts) do
      {:ok, compiled} -> compiled
      {:error, error} -> raise error
    end
  end

  @doc """
  Parse expert system item to an AST
  """
  def parse(str, _opts \\ []) do
    with {:ok, tokens, _} <- str |> to_charlist |> :calypte_lexer.string(),
         {:ok, parsed} <- :calypte_parser.parse(tokens),
         do: {:ok, parsed}
  end

  @doc """
  The same as `parse/2`, but it raises on error.
  """
  def parse!(str, opts \\ []) do
    case parse(str, opts) do
      {:ok, ast} -> ast
      {:error, error} -> raise error
    end
  end

  @doc """
  Compile parsed ast.
  """
  def compile(parsed, opts \\ []), do: Compiler.compile(parsed, opts)

  @doc """
  Init context with engine and life cicle.
  """
  @spec init(Keyword.t()) :: Context.t()
  def init(graph, opts_list \\ []) do
    opts =
      opts_list
      |> Map.new()
      |> Map.put_new(:id_key, "uid")
      |> Map.put_new(:type_key, "type")
      |> Map.put_new(:engine, Engine.NaiveFirst)
      |> Map.put_new(:life_cycle, [])

    graph = to_graph(graph, opts)

    %Context{
      graph: graph,
      engine: opts.engine,
      state: Engine.init(opts.engine, graph),
      life_cycle: opts.life_cycle
    }
  end

  defp to_graph(%Graph{} = graph, _opts), do: graph
  defp to_graph(graph, opts), do: Graph.new(graph, opts)

  @doc """
  Add rules to a context
  """
  @spec add_rules(Context.t(), [Rule.t()]) :: Context.t()
  def add_rules(%Context{engine: engine, state: state} = context, rules) do
    %{context | state: Engine.add_rules(engine, state, rules)}
  end

  @doc """
  Add changeset or graph to a context.
  """

  def add_change(context, change, binding \\ nil)

  def add_change(context, %Changeset{} = changeset, binding) do
    %Context{graph: graph, engine: engine, state: state, life_cycle: _life_cycle} = context
    new_graph = Graph.add_change(graph, changeset)

    case binding do
      nil ->
        new_state = Engine.add_change(engine, state, changeset)
        Truth.add_change(%{context | graph: new_graph, state: new_state}, changeset)

      %Binding{rule: rule, hash: hash} ->
        rule_id = Rule.id(rule)
        new_state = Engine.add_exec_change(engine, state, {rule_id, hash}, changeset)
        Truth.add_exec_change(%{context | graph: new_graph, state: new_state}, binding)
    end
  end

  def add_change(%Context{graph: graph} = context, json, nil) do
    changeset = Changeset.from_json(graph, json)
    add_change(context, changeset, nil)
  end

  @doc """
  Evaluation cycle. It runs and waits till next binding is found or not and executed
  """
  @spec eval(Context.t()) :: {Binding.t(), Context.t()}
  def eval(%Context{graph: graph, engine: engine, state: state} = context) do
    case Engine.eval(engine, state, graph) do
      {[], state} ->
        %Context{context | state: state, executed?: false}

      {[binding | _possible_executions], state} ->
        exec_binding(binding, %Context{context | state: state, executed?: true})
    end
  end

  defp exec_binding(%Binding{rule: rule, hash: hash} = binding, context) do
    rule_id = Rule.id(rule)
    %Context{exec_count: exec_count, exec_log: exec_log, exec_store: exec_store} = context
    {executed_binding, changeset} = Rule.exec(binding)

    log_entry = %LogEntry{id: exec_count, tag: :exec, rule_id: rule_id, change: hash}

    context = %Context{
      context
      | exec_count: exec_count + 1,
        exec_log: [log_entry | exec_log],
        exec_store: deep_put(exec_store, [rule_id, hash], %{id: exec_count, changeset: changeset})
    }

    add_change(context, changeset, executed_binding)
  end

  def del_exec(context, {rule_id, hash}) do
    %Context{
      graph: graph,
      engine: engine,
      state: state,
      exec_count: exec_count,
      exec_log: exec_log,
      exec_store: exec_store
    } = context

    %{changeset: changeset} = exec_store[rule_id][hash]
    changeset = Changeset.revert(changeset)
    log_entry = %LogEntry{id: exec_count, tag: :exec, rule_id: rule_id, change: hash}

    %Context{
      context
      | graph: Graph.add_change(graph, changeset),
        state: Engine.del_exec_change(engine, state, {rule_id, hash}, changeset),
        exec_count: exec_count + 1,
        exec_log: [log_entry | exec_log]
    }
  end
end
