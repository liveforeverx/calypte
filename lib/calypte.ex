defmodule Calypte do
  @moduledoc """
  Documentation for Calypte.
  """

  alias Calypte.{Binding, Changeset, Context, Compiler, Engine, Execution, Graph, Rule}

  @doc """
  Parse and compile rule
  """
  def string(str, opts \\ []) do
    with {:ok, parsed} <- parse(str, opts), do: compile(parsed)
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

  def add_change(context, %Changeset{} = changeset, binding \\ nil) do
    %Context{graph: graph, engine: engine, state: state, life_cycle: _life_cycle} = context
    graph = Graph.add_change(graph, changeset)

    state =
      case binding do
        nil -> Engine.add_change(engine, state, changeset)
        _ -> Engine.add_exec_change(engine, state, changeset, binding)
      end

    %{context | graph: graph, state: state}
  end

  @spec eval(Context.t()) :: {Binding.t(), Context.t()}
  def eval(%Context{graph: graph, engine: engine, state: state, exec_log: exec_log} = context) do
    case Engine.eval(engine, state, graph) do
      {[], state} ->
        %Context{context | state: state, executed?: false}

      {[binding | _possible_executions], state} ->
        %Binding{rule: rule} = binding
        {_executed_binding, changeset} = Rule.exec(binding)

        context = %Context{
          context
          | state: state,
            executed?: true,
            exec_log: [%Execution{rule_id: Rule.id(rule), changeset: changeset} | exec_log]
        }

        add_change(context, changeset, binding)
    end
  end
end
