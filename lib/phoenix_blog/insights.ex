defmodule PhoenixBlog.Insights do
  @moduledoc """
  Context for managing AI-generated insights.

  Provides CRUD operations for insights discovered from research data,
  including filtering, activation, and usage tracking.
  """

  import Ecto.Query, warn: false
  alias PhoenixBlog.Repo
  alias PhoenixBlog.Insights.Insight

  @doc """
  Lists all insights for a user.
  """
  def list_insights(user_id, opts \\ []) do
    status = Keyword.get(opts, :status)
    insight_type = Keyword.get(opts, :insight_type)
    limit = Keyword.get(opts, :limit, 50)

    Insight
    |> where([i], i.user_id == ^user_id)
    |> maybe_filter_status(status)
    |> maybe_filter_type(insight_type)
    |> order_by([i], desc: i.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Lists active insights for a user.
  """
  def list_active_insights(user_id, opts \\ []) do
    list_insights(user_id, Keyword.put(opts, :status, "active"))
  end

  @doc """
  Lists high-confidence insights for a user.
  """
  def list_high_confidence_insights(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    Insight
    |> where([i], i.user_id == ^user_id)
    |> where([i], i.status == "active")
    |> where([i], i.confidence_score >= ^Decimal.new("0.8"))
    |> order_by([i], desc: i.confidence_score)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets a single insight.
  """
  def get_insight!(id), do: Repo.get!(Insight, id)

  @doc """
  Gets an insight by ID, scoped to a user.
  """
  def get_insight!(user_id, id) do
    Insight
    |> where([i], i.user_id == ^user_id and i.id == ^id)
    |> Repo.one!()
  end

  @doc """
  Creates an insight.
  """
  def create_insight(attrs) do
    %Insight{}
    |> Insight.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an insight.
  """
  def update_insight(%Insight{} = insight, attrs) do
    insight
    |> Insight.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Activates an insight.
  """
  def activate_insight(%Insight{} = insight) do
    insight
    |> Insight.activate_changeset()
    |> Repo.update()
  end

  @doc """
  Archives an insight.
  """
  def archive_insight(%Insight{} = insight) do
    insight
    |> Insight.archive_changeset()
    |> Repo.update()
  end

  @doc """
  Increments the usage count for an insight.
  """
  def increment_usage(%Insight{} = insight) do
    insight
    |> Insight.increment_usage()
    |> Repo.update()
  end

  @doc """
  Deletes an insight.
  """
  def delete_insight(%Insight{} = insight) do
    Repo.delete(insight)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking insight changes.
  """
  def change_insight(%Insight{} = insight, attrs \\ %{}) do
    Insight.changeset(insight, attrs)
  end

  @doc """
  Returns counts of insights by status for a user.
  """
  def count_by_status(user_id) do
    Insight
    |> where([i], i.user_id == ^user_id)
    |> group_by([i], i.status)
    |> select([i], {i.status, count(i.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns counts of insights by type for a user.
  """
  def count_by_type(user_id) do
    Insight
    |> where([i], i.user_id == ^user_id)
    |> group_by([i], i.insight_type)
    |> select([i], {i.insight_type, count(i.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns the most used insights for a user.
  """
  def most_used_insights(user_id, limit \\ 10) do
    Insight
    |> where([i], i.user_id == ^user_id)
    |> where([i], i.used_count > 0)
    |> order_by([i], desc: i.used_count)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Searches insights by title or description.
  """
  def search_insights(user_id, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    search_term = "%#{query}%"

    Insight
    |> where([i], i.user_id == ^user_id)
    |> where([i], ilike(i.title, ^search_term) or ilike(i.description, ^search_term))
    |> order_by([i], desc: i.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: where(query, [i], i.status == ^status)

  defp maybe_filter_type(query, nil), do: query
  defp maybe_filter_type(query, type), do: where(query, [i], i.insight_type == ^type)
end
