defmodule PhoenixBlog.Insights.Insight do
  @moduledoc """
  Schema for AI-generated insights.

  Stores actionable insights discovered from research data,
  including messaging angles, objections, and opportunities.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @insight_types ~w(messaging_angle objection opportunity winning_hook competitor_weakness)
  @status_values ~w(draft active archived)

  schema "insights" do
    field :insight_type, :string
    field :title, :string
    field :description, :string
    field :evidence_ids, {:array, :integer}, default: []
    field :confidence_score, :decimal
    field :tags, {:array, :string}, default: []
    field :status, :string, default: "draft"
    field :used_count, :integer, default: 0

    belongs_to :user, PhoenixBlog.Blog.Author, foreign_key: :user_id
    has_many :content_generations, PhoenixBlog.Generations.ContentGeneration

    timestamps(type: :utc_datetime)
  end

  def changeset(insight, attrs) do
    insight
    |> cast(attrs, [
      :insight_type,
      :title,
      :description,
      :evidence_ids,
      :confidence_score,
      :tags,
      :status,
      :used_count,
      :user_id
    ])
    |> validate_required([:insight_type, :title, :user_id])
    |> validate_inclusion(:insight_type, @insight_types)
    |> validate_inclusion(:status, @status_values)
    |> validate_number(:confidence_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> foreign_key_constraint(:user_id)
  end

  def activate_changeset(insight) do
    insight
    |> change(%{status: "active"})
  end

  def archive_changeset(insight) do
    insight
    |> change(%{status: "archived"})
  end

  def increment_usage(insight) do
    insight
    |> change(%{used_count: insight.used_count + 1})
  end

  def insight_types, do: @insight_types
  def status_values, do: @status_values

  def active?(%__MODULE__{status: "active"}), do: true
  def active?(_), do: false

  def high_confidence?(%__MODULE__{confidence_score: score}) when not is_nil(score) do
    Decimal.compare(score, Decimal.new("0.8")) != :lt
  end

  def high_confidence?(_), do: false
end
