defmodule PhoenixBlog.Research.ResearchData do
  @moduledoc """
  Schema for scraped research data.

  Stores individual data points from research jobs (posts, comments,
  reviews, ads) with sentiment analysis and theme extraction.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @source_types ~w(facebook_post instagram_post tiktok_video ad comment review)
  @sentiment_values ~w(positive negative neutral mixed)

  schema "research_data" do
    field :source_type, :string
    field :content, :string
    field :metrics, :map, default: %{}
    field :sentiment, :string
    field :themes, {:array, :string}, default: []
    field :source_url, :string
    field :source_author, :string
    field :source_date, :utc_datetime
    field :raw_data, :map, default: %{}

    belongs_to :user, PhoenixBlog.Blog.Author, foreign_key: :user_id
    belongs_to :research_job, PhoenixBlog.Research.ResearchJob

    timestamps(type: :utc_datetime)
  end

  def changeset(data, attrs) do
    data
    |> cast(attrs, [
      :source_type,
      :content,
      :metrics,
      :sentiment,
      :themes,
      :source_url,
      :source_author,
      :source_date,
      :raw_data,
      :user_id,
      :research_job_id
    ])
    |> validate_required([:source_type, :user_id])
    |> validate_inclusion(:source_type, @source_types)
    |> validate_inclusion(:sentiment, @sentiment_values ++ [nil])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:research_job_id)
  end

  def source_types, do: @source_types
  def sentiment_values, do: @sentiment_values

  def positive?(%__MODULE__{sentiment: "positive"}), do: true
  def positive?(_), do: false

  def negative?(%__MODULE__{sentiment: "negative"}), do: true
  def negative?(_), do: false
end
