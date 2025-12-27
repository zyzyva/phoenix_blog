defmodule PhoenixBlog.Costs do
  @moduledoc """
  Context for tracking usage costs across AI and scraping services.

  Provides cost recording, querying, and aggregation for budget monitoring.
  """

  import Ecto.Query, warn: false
  alias PhoenixBlog.Repo
  alias PhoenixBlog.Costs.CostEntry

  @doc """
  Records a cost entry for a service usage.
  """
  def record_cost(attrs) do
    %CostEntry{}
    |> CostEntry.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Records a cost entry for an AI text generation.
  """
  def record_text_generation(user_id, service, operation, input_tokens, output_tokens, cost, opts \\ []) do
    record_cost(%{
      user_id: user_id,
      service: service,
      operation: operation,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cost: cost,
      request_id: Keyword.get(opts, :request_id),
      metadata: Keyword.get(opts, :metadata, %{})
    })
  end

  @doc """
  Records a cost entry for an AI image/video generation.
  """
  def record_media_generation(user_id, service, operation, units, cost, opts \\ []) do
    record_cost(%{
      user_id: user_id,
      service: service,
      operation: operation,
      units: units,
      cost: cost,
      request_id: Keyword.get(opts, :request_id),
      metadata: Keyword.get(opts, :metadata, %{})
    })
  end

  @doc """
  Records a cost entry for a scraping operation.
  """
  def record_scrape(user_id, service, operation, cost, opts \\ []) do
    record_cost(%{
      user_id: user_id,
      service: service,
      operation: operation,
      cost: cost,
      request_id: Keyword.get(opts, :request_id),
      metadata: Keyword.get(opts, :metadata, %{})
    })
  end

  @doc """
  Gets total costs for a user within a date range.
  """
  def total_cost(user_id, start_date \\ nil, end_date \\ nil) do
    CostEntry
    |> where([c], c.user_id == ^user_id)
    |> maybe_filter_date_range(start_date, end_date)
    |> select([c], sum(c.cost))
    |> Repo.one()
    |> Kernel.||(Decimal.new("0"))
  end

  @doc """
  Gets total costs for a user this month.
  """
  def total_cost_this_month(user_id) do
    start_of_month = Date.utc_today() |> Date.beginning_of_month()
    end_of_month = Date.utc_today() |> Date.end_of_month()

    total_cost(user_id, start_of_month, end_of_month)
  end

  @doc """
  Gets cost breakdown by service for a user.
  """
  def cost_by_service(user_id, start_date \\ nil, end_date \\ nil) do
    CostEntry
    |> where([c], c.user_id == ^user_id)
    |> maybe_filter_date_range(start_date, end_date)
    |> group_by([c], c.service)
    |> select([c], {c.service, sum(c.cost)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Gets cost breakdown by operation for a user and service.
  """
  def cost_by_operation(user_id, service, start_date \\ nil, end_date \\ nil) do
    CostEntry
    |> where([c], c.user_id == ^user_id and c.service == ^service)
    |> maybe_filter_date_range(start_date, end_date)
    |> group_by([c], c.operation)
    |> select([c], {c.operation, sum(c.cost), count(c.id)})
    |> Repo.all()
    |> Enum.map(fn {op, cost, count} -> %{operation: op, cost: cost, count: count} end)
  end

  @doc """
  Gets daily costs for a user over the last N days.
  """
  def daily_costs(user_id, days \\ 30) do
    start_date = Date.utc_today() |> Date.add(-days)

    CostEntry
    |> where([c], c.user_id == ^user_id)
    |> where([c], fragment("?::date", c.inserted_at) >= ^start_date)
    |> group_by([c], fragment("?::date", c.inserted_at))
    |> select([c], {fragment("?::date", c.inserted_at), sum(c.cost)})
    |> order_by([c], asc: fragment("?::date", c.inserted_at))
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Gets recent cost entries for a user.
  """
  def recent_entries(user_id, limit \\ 50) do
    CostEntry
    |> where([c], c.user_id == ^user_id)
    |> order_by([c], desc: c.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets token usage stats for a user.
  """
  def token_usage(user_id, start_date \\ nil, end_date \\ nil) do
    CostEntry
    |> where([c], c.user_id == ^user_id)
    |> where([c], not is_nil(c.input_tokens) or not is_nil(c.output_tokens))
    |> maybe_filter_date_range(start_date, end_date)
    |> select([c], %{
      total_input: sum(c.input_tokens),
      total_output: sum(c.output_tokens),
      total_cost: sum(c.cost)
    })
    |> Repo.one()
  end

  @doc """
  Checks if user has exceeded a budget threshold.
  """
  def budget_exceeded?(user_id, budget) do
    total = total_cost_this_month(user_id)
    Decimal.compare(total, Decimal.new(budget)) != :lt
  end

  @doc """
  Returns all available services.
  """
  def services, do: CostEntry.services()

  defp maybe_filter_date_range(query, nil, nil), do: query

  defp maybe_filter_date_range(query, start_date, nil) do
    start_datetime = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    where(query, [c], c.inserted_at >= ^start_datetime)
  end

  defp maybe_filter_date_range(query, nil, end_date) do
    end_datetime = DateTime.new!(end_date, ~T[23:59:59], "Etc/UTC")
    where(query, [c], c.inserted_at <= ^end_datetime)
  end

  defp maybe_filter_date_range(query, start_date, end_date) do
    start_datetime = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_datetime = DateTime.new!(end_date, ~T[23:59:59], "Etc/UTC")

    query
    |> where([c], c.inserted_at >= ^start_datetime)
    |> where([c], c.inserted_at <= ^end_datetime)
  end
end
