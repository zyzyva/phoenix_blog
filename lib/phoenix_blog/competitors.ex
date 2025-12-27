defmodule PhoenixBlog.Competitors do
  @moduledoc """
  Context for managing competitors and their research.

  Provides CRUD operations for competitors and triggers
  research jobs for scraping and analysis.
  """

  import Ecto.Query, warn: false
  alias PhoenixBlog.Repo
  alias PhoenixBlog.Competitors.Competitor

  @doc """
  Lists all competitors for a user.
  """
  def list_competitors(user_id, opts \\ []) do
    status = Keyword.get(opts, :status)

    Competitor
    |> where([c], c.user_id == ^user_id)
    |> maybe_filter_status(status)
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  @doc """
  Gets a single competitor.
  """
  def get_competitor!(id), do: Repo.get!(Competitor, id)

  @doc """
  Gets a competitor by ID, scoped to a user.
  """
  def get_competitor!(user_id, id) do
    Competitor
    |> where([c], c.user_id == ^user_id and c.id == ^id)
    |> Repo.one!()
  end

  @doc """
  Gets a competitor by name for a user.
  """
  def get_competitor_by_name(user_id, name) do
    Competitor
    |> where([c], c.user_id == ^user_id and c.name == ^name)
    |> Repo.one()
  end

  @doc """
  Creates a competitor.
  """
  def create_competitor(attrs) do
    %Competitor{}
    |> Competitor.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a competitor.
  """
  def update_competitor(%Competitor{} = competitor, attrs) do
    competitor
    |> Competitor.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Pauses a competitor (stops research jobs).
  """
  def pause_competitor(%Competitor{} = competitor) do
    update_competitor(competitor, %{status: "paused"})
  end

  @doc """
  Activates a competitor.
  """
  def activate_competitor(%Competitor{} = competitor) do
    update_competitor(competitor, %{status: "active"})
  end

  @doc """
  Deletes a competitor.
  """
  def delete_competitor(%Competitor{} = competitor) do
    Repo.delete(competitor)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking competitor changes.
  """
  def change_competitor(%Competitor{} = competitor, attrs \\ %{}) do
    Competitor.changeset(competitor, attrs)
  end

  @doc """
  Adds a social URL to a competitor.
  """
  def add_social_url(%Competitor{} = competitor, url) do
    new_urls = Enum.uniq([url | competitor.social_urls])
    update_competitor(competitor, %{social_urls: new_urls})
  end

  @doc """
  Adds a Meta Ad Library page ID to a competitor.
  """
  def add_ad_page_id(%Competitor{} = competitor, page_id) do
    new_ids = Enum.uniq([page_id | competitor.ad_page_ids])
    update_competitor(competitor, %{ad_page_ids: new_ids})
  end

  @doc """
  Returns count of competitors by status for a user.
  """
  def count_by_status(user_id) do
    Competitor
    |> where([c], c.user_id == ^user_id)
    |> group_by([c], c.status)
    |> select([c], {c.status, count(c.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns all active competitors for a user.
  """
  def active_competitors(user_id) do
    list_competitors(user_id, status: "active")
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: where(query, [c], c.status == ^status)
end
