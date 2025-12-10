defmodule PhoenixBlog.Research.Tactic do
  @moduledoc """
  Schema for storing marketing tactics found during research.

  Tactics can be in various states:
  - saved: Just captured, not yet evaluated
  - testing: Currently being tested
  - validated: Tested and confirmed to work
  - debunked: Tested and confirmed not to work
  - archived: No longer relevant
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "research_tactics" do
    field :title, :string
    field :description, :string
    field :source_url, :string
    field :source_platform, :string
    field :source_author, :string
    field :status, :string, default: "saved"

    # Categorization
    field :category, :string
    field :tags, {:array, :string}, default: []
    field :platforms, {:array, :string}, default: []

    # Testing
    field :test_plan, :string
    field :test_results, :string
    field :test_started_at, :utc_datetime
    field :test_completed_at, :utc_datetime

    # Metrics from testing
    field :metrics, :map, default: %{}

    # Engagement from source (if from Reddit/Twitter)
    field :source_score, :integer
    field :source_comments, :integer

    # Notes
    field :notes, :string

    timestamps()
  end

  @valid_statuses ["saved", "testing", "validated", "debunked", "archived"]
  @valid_categories ["content", "seo", "paid_ads", "social", "email", "outreach", "growth_hack", "other"]

  def changeset(tactic, attrs) do
    tactic
    |> cast(attrs, [
      :title, :description, :source_url, :source_platform, :source_author,
      :status, :category, :tags, :platforms, :test_plan, :test_results,
      :test_started_at, :test_completed_at, :metrics, :source_score,
      :source_comments, :notes
    ])
    |> validate_required([:title, :source_platform])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:category, @valid_categories, message: "must be one of: #{Enum.join(@valid_categories, ", ")}")
  end

  def start_test_changeset(tactic, test_plan) do
    tactic
    |> change(%{
      status: "testing",
      test_plan: test_plan,
      test_started_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  def complete_test_changeset(tactic, attrs) do
    tactic
    |> cast(attrs, [:status, :test_results, :metrics, :notes])
    |> put_change(:test_completed_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> validate_inclusion(:status, ["validated", "debunked"])
  end
end
