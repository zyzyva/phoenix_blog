defmodule PhoenixBlog.Keywords.CSVImporter do
  @moduledoc """
  Imports keyword data from Google Keyword Planner CSV exports.

  Handles both UTF-8 and UTF-16 encoded CSV files from Google Keyword Planner.
  Expected columns:
  - Keyword
  - Avg. monthly searches
  - Competition
  - Competition (indexed value)
  - Three month change
  - YoY change
  - Top of page bid (low range)
  - Top of page bid (high range)
  """

  alias PhoenixBlog.Keywords
  require Logger

  @doc """
  Imports keywords from a CSV file path.

  Returns `{:ok, %{imported: count, skipped: count, errors: list}}` on completion.
  """
  def import_from_file(file_path) do
    with {:ok, content} <- read_and_decode_file(file_path),
         {:ok, rows} <- parse_csv(content) do
      import_rows(rows)
    end
  end

  @doc """
  Imports keywords from raw CSV content (already decoded to UTF-8).
  """
  def import_from_content(content) do
    with {:ok, rows} <- parse_csv(content) do
      import_rows(rows)
    end
  end

  defp read_and_decode_file(file_path) do
    case File.read(file_path) do
      {:ok, binary} ->
        content = decode_to_utf8(binary)
        {:ok, content}

      {:error, reason} ->
        {:error, "Failed to read file: #{reason}"}
    end
  end

  defp decode_to_utf8(binary) do
    cond do
      # UTF-16 LE BOM
      String.starts_with?(binary, <<0xFF, 0xFE>>) ->
        <<_bom::binary-size(2), rest::binary>> = binary

        rest
        |> :unicode.characters_to_binary({:utf16, :little})
        |> handle_unicode_result()

      # UTF-16 BE BOM
      String.starts_with?(binary, <<0xFE, 0xFF>>) ->
        <<_bom::binary-size(2), rest::binary>> = binary

        rest
        |> :unicode.characters_to_binary({:utf16, :big})
        |> handle_unicode_result()

      # UTF-8 BOM
      String.starts_with?(binary, <<0xEF, 0xBB, 0xBF>>) ->
        String.trim_leading(binary, <<0xEF, 0xBB, 0xBF>>)

      # Assume UTF-8
      true ->
        binary
    end
  end

  defp handle_unicode_result(result) when is_binary(result), do: result
  defp handle_unicode_result({:incomplete, converted, _rest}), do: converted
  defp handle_unicode_result({:error, _converted, _rest}), do: ""

  defp parse_csv(content) do
    lines =
      content
      |> String.split(~r/\r?\n/, trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    {header, data_rows} = find_header_row(lines)

    case {header, data_rows} do
      {nil, _} ->
        {:error, "Could not find header row with 'Keyword' column"}

      {_, []} ->
        {:error, "CSV file has no data rows"}

      {header, data_rows} ->
        delimiter = detect_delimiter(header)
        column_map = parse_header(header, delimiter)
        rows = Enum.map(data_rows, &parse_row(&1, column_map, delimiter))
        {:ok, rows}
    end
  end

  defp find_header_row(lines) do
    index =
      Enum.find_index(lines, fn line ->
        lower = String.downcase(line)

        String.starts_with?(lower, "keyword\t") or
          String.starts_with?(lower, "keyword,")
      end)

    case index do
      nil -> {nil, lines}
      idx -> {Enum.at(lines, idx), Enum.drop(lines, idx + 1)}
    end
  end

  defp detect_delimiter(header_line) do
    tab_count = header_line |> String.graphemes() |> Enum.count(&(&1 == "\t"))
    comma_count = header_line |> String.graphemes() |> Enum.count(&(&1 == ","))

    if tab_count > comma_count, do: "\t", else: ","
  end

  defp parse_header(header_line, delimiter) do
    header_line
    |> split_csv_line(delimiter)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&normalize_header/1)
    |> Enum.with_index()
    |> Map.new()
  end

  defp split_csv_line(line, "\t"), do: String.split(line, "\t")

  defp split_csv_line(line, ",") do
    Regex.scan(~r/(?:^|,)(?:"([^"]*(?:""[^"]*)*)"|([^,]*))/, line)
    |> Enum.map(fn
      [_, quoted, ""] -> String.replace(quoted, ~S(""), ~S("))
      [_, "", unquoted] -> unquoted
      [_, quoted] -> String.replace(quoted, ~S(""), ~S("))
      _ -> ""
    end)
  end

  defp normalize_header(header) do
    header
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end

  defp parse_row(line, column_map, delimiter) do
    values =
      line
      |> split_csv_line(delimiter)
      |> Enum.map(&String.trim/1)

    %{
      keyword: get_column_value(values, column_map, "keyword"),
      monthly_searches:
        parse_integer(get_column_value(values, column_map, "avg_monthly_searches")),
      competition: get_column_value(values, column_map, "competition"),
      competition_index:
        parse_integer(get_column_value(values, column_map, "competition_indexed_value")),
      three_month_change: get_column_value(values, column_map, "three_month_change"),
      yoy_change: get_column_value(values, column_map, "yoy_change"),
      top_bid_low:
        parse_decimal(get_column_value(values, column_map, "top_of_page_bid_low_range")),
      top_bid_high:
        parse_decimal(get_column_value(values, column_map, "top_of_page_bid_high_range"))
    }
  end

  defp get_column_value(values, column_map, key) do
    case Map.get(column_map, key) do
      nil -> nil
      index -> Enum.at(values, index)
    end
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(value) when is_binary(value) do
    cleaned = String.replace(value, ~r/[^0-9]/, "")

    case Integer.parse(cleaned) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_decimal(nil), do: nil
  defp parse_decimal(""), do: nil

  defp parse_decimal(value) when is_binary(value) do
    cleaned =
      value
      |> String.replace(~r/[$€£,]/, "")
      |> String.trim()

    case Decimal.parse(cleaned) do
      {decimal, _} -> decimal
      :error -> nil
    end
  end

  defp import_rows(rows) do
    results =
      Enum.reduce(rows, %{imported: 0, skipped: 0, errors: []}, fn row, acc ->
        case import_single_row(row) do
          {:ok, _keyword} ->
            %{acc | imported: acc.imported + 1}

          {:error, :duplicate} ->
            %{acc | skipped: acc.skipped + 1}

          {:error, changeset} ->
            error = "#{row.keyword}: #{inspect(changeset.errors)}"
            %{acc | errors: [error | acc.errors]}
        end
      end)

    {:ok, %{results | errors: Enum.reverse(results.errors)}}
  end

  defp import_single_row(%{keyword: nil}), do: {:error, :duplicate}
  defp import_single_row(%{keyword: ""}), do: {:error, :duplicate}

  defp import_single_row(row) do
    case Keywords.get_keyword_by_text(row.keyword) do
      nil ->
        Keywords.create_keyword(row)

      _existing ->
        {:error, :duplicate}
    end
  end
end
