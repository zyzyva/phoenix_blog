defmodule PhoenixBlog.Generations do
  @moduledoc """
  Context for managing content generations.

  Provides queue management, status tracking, and delivery handling
  for AI-generated content (text, images, videos).
  """

  import Ecto.Query, warn: false
  alias PhoenixBlog.Repo
  alias PhoenixBlog.Generations.ContentGeneration

  @doc """
  Lists all generations for a user.
  """
  def list_generations(user_id, opts \\ []) do
    status = Keyword.get(opts, :status)
    content_type = Keyword.get(opts, :content_type)
    limit = Keyword.get(opts, :limit, 50)

    ContentGeneration
    |> where([g], g.user_id == ^user_id)
    |> maybe_filter_status(status)
    |> maybe_filter_content_type(content_type)
    |> order_by([g], desc: g.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Lists queued generations ready for processing.
  """
  def list_queued(limit \\ 10) do
    ContentGeneration
    |> where([g], g.status == "queued")
    |> order_by([g], asc: g.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Lists completed generations awaiting delivery.
  """
  def list_pending_delivery(user_id) do
    ContentGeneration
    |> where([g], g.user_id == ^user_id)
    |> where([g], g.status == "completed")
    |> where([g], not is_nil(g.delivery_method))
    |> order_by([g], asc: g.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single generation.
  """
  def get_generation!(id), do: Repo.get!(ContentGeneration, id)

  @doc """
  Gets a generation by ID, scoped to a user.
  """
  def get_generation!(user_id, id) do
    ContentGeneration
    |> where([g], g.user_id == ^user_id and g.id == ^id)
    |> Repo.one!()
  end

  @doc """
  Gets a generation with its associated insight.
  """
  def get_generation_with_insight!(id) do
    ContentGeneration
    |> Repo.get!(id)
    |> Repo.preload(:insight)
  end

  @doc """
  Queues a new generation.
  """
  def queue_generation(attrs) do
    %ContentGeneration{}
    |> ContentGeneration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Starts processing a generation.
  """
  def start_processing(%ContentGeneration{} = generation) do
    generation
    |> ContentGeneration.start_processing_changeset()
    |> Repo.update()
  end

  @doc """
  Marks a generation as completed.
  """
  def complete_generation(%ContentGeneration{} = generation, output_content, output_urls, provider, model, cost) do
    generation
    |> ContentGeneration.complete_changeset(output_content, output_urls, provider, model, cost)
    |> Repo.update()
  end

  @doc """
  Marks a generation as failed.
  """
  def fail_generation(%ContentGeneration{} = generation, error_message) do
    generation
    |> ContentGeneration.fail_changeset(error_message)
    |> Repo.update()
  end

  @doc """
  Marks a generation as delivered.
  """
  def mark_delivered(%ContentGeneration{} = generation) do
    generation
    |> ContentGeneration.deliver_changeset()
    |> Repo.update()
  end

  @doc """
  Deletes a generation.
  """
  def delete_generation(%ContentGeneration{} = generation) do
    Repo.delete(generation)
  end

  @doc """
  Returns counts of generations by status for a user.
  """
  def count_by_status(user_id) do
    ContentGeneration
    |> where([g], g.user_id == ^user_id)
    |> group_by([g], g.status)
    |> select([g], {g.status, count(g.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns counts of generations by content type for a user.
  """
  def count_by_content_type(user_id) do
    ContentGeneration
    |> where([g], g.user_id == ^user_id)
    |> group_by([g], g.content_type)
    |> select([g], {g.content_type, count(g.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns total cost for a user's generations.
  """
  def total_cost(user_id) do
    ContentGeneration
    |> where([g], g.user_id == ^user_id)
    |> where([g], not is_nil(g.cost))
    |> select([g], sum(g.cost))
    |> Repo.one()
    |> Kernel.||(Decimal.new("0"))
  end

  @doc """
  Returns recent completed generations for a user.
  """
  def recent_completed(user_id, limit \\ 10) do
    ContentGeneration
    |> where([g], g.user_id == ^user_id)
    |> where([g], g.status in ["completed", "delivered"])
    |> order_by([g], desc: g.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: where(query, [g], g.status == ^status)

  defp maybe_filter_content_type(query, nil), do: query
  defp maybe_filter_content_type(query, type), do: where(query, [g], g.content_type == ^type)
end
