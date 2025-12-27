defmodule PhoenixBlog.Competitors.Competitor do
  @moduledoc """
  Schema for tracked competitors.

  Stores competitor information including their website, social profiles,
  and Meta Ad Library page IDs for monitoring.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @status_values ~w(active paused)

  schema "competitors" do
    field :name, :string
    field :website_urls, {:array, :string}, default: []
    field :social_urls, {:array, :string}, default: []
    field :ad_page_ids, {:array, :string}, default: []
    field :status, :string, default: "active"
    field :metadata, :map, default: %{}

    belongs_to :user, PhoenixBlog.Blog.Author, foreign_key: :user_id
    has_many :research_jobs, PhoenixBlog.Research.ResearchJob

    timestamps(type: :utc_datetime)
  end

  def changeset(competitor, attrs) do
    competitor
    |> cast(attrs, [:name, :website_urls, :social_urls, :ad_page_ids, :status, :metadata, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_inclusion(:status, @status_values)
    |> unique_constraint([:user_id, :name])
    |> foreign_key_constraint(:user_id)
    |> validate_urls(:website_urls)
    |> validate_urls(:social_urls)
  end

  def status_values, do: @status_values

  def active?(%__MODULE__{status: "active"}), do: true
  def active?(_), do: false

  defp validate_urls(changeset, field) do
    validate_change(changeset, field, fn _, urls ->
      invalid_urls =
        urls
        |> Enum.filter(&(&1 != ""))
        |> Enum.reject(&valid_url?/1)

      if invalid_urls == [] do
        []
      else
        [{field, "contains invalid URLs: #{Enum.join(invalid_urls, ", ")}"}]
      end
    end)
  end

  defp valid_url?(url) do
    uri = URI.parse(url)
    uri.scheme in ["http", "https"] and uri.host != nil
  end
end
