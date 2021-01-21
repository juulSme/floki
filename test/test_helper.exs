# fast_html uses a C-Node worker for parsing, so starting the application
# is necessary for it to work
if Application.get_env(:floki, :html_parser) == Floki.HTMLParser.FastHtml do
  Application.ensure_all_started(:fast_html)
end

defmodule TokenizerTestLoader do
  alias Floki.HTML.Tokenizer

  @moduledoc """
  It helps with tests from the tokenizer
  """

  defmacro __using__(_opts) do
    quote do
      ExUnit.Case.register_attribute(__MODULE__, :params, accumulate: true)
      import TokenizerTestLoader, only: [load_tests_from_file: 1]
    end
  end

  @doc """
  Loads tests from a file in the format of HTML5lib-tests.
  It executes the tokenization and match with the expected output.
  """
  defmacro load_tests_from_file(file_name) do
    quote bind_quoted: [file_name: file_name] do
      {:ok, content} = File.read(file_name)
      {:ok, json} = Jason.decode(content)
      tests = Map.get(json, "tests")

      Enum.map(tests, fn definition ->
        description = Map.get(definition, "description")

        @params {:input, Map.get(definition, "input")}
        @params {:output, Map.get(definition, "output")}
        test "tokenize/1 #{description}", context do
          result =
            Keyword.get(context.registered.params, :input)
            |> Floki.HTML.Tokenizer.tokenize()
            |> TokenizerTestLoader.tokenization_result()

          output = Keyword.get(context.registered.params, :output)

          assert result.tokens == output
        end
      end)
    end
  end

  defmodule HTMLTestResult do
    defstruct errors: [], tokens: []
  end

  @doc """
  It transforms the tokens from the tokenizer state into the
  tokens from HTML5lib test file format.
  """
  def tokenization_result(state = %Tokenizer.State{}) do
    output_tokens =
      state.tokens
      |> Enum.map(&transform_token/1)
      |> Enum.reduce([], fn token, tokens ->
        if token do
          [token | tokens]
        else
          tokens
        end
      end)

    output_errors =
      state.errors
      |> Enum.map(fn error ->
        %{
          "code" => error.id,
          "col" => error.position.col,
          "line" => error.position.line
        }
      end)

    %HTMLTestResult{tokens: output_tokens, errors: output_errors}
  end

  defp transform_token(doctype = %Tokenizer.Doctype{}) do
    [
      "DOCTYPE",
      doctype.name,
      doctype.public_id,
      doctype.system_id,
      doctype.force_quirks == :off
    ]
  end

  defp transform_token(comment = %Tokenizer.Comment{}) do
    [
      "Comment",
      comment.data
    ]
  end

  defp transform_token(tag = %Tokenizer.Tag{type: :start}) do
    [
      "StartTag",
      tag.name,
      Enum.reduce(tag.attributes, %{}, fn attr, attributes ->
        Map.put(attributes, attr.name, attr.value)
      end)
    ]
  end

  defp transform_token(tag = %Tokenizer.Tag{type: :end}) do
    [
      "EndTag",
      tag.name
    ]
  end

  defp transform_token(char = %Tokenizer.Char{}) do
    [
      "Character",
      char.data
    ]
  end

  defp transform_token(%Tokenizer.EOF{}), do: nil

  defp transform_token(other), do: other
end

ExUnit.start()
