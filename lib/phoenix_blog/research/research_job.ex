defmodule PhoenixBlog.Research.ResearchJob do
  @moduledoc """
  Schema for research jobs.

  Tracks async scraping and analysis jobs with their status,
  results, and associated costs.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @job_types ~w(social_scrape ad_library comment_analysis review_analysis)
  @status_values ~w(pending running completed failed)

  schema "research_jobs" do
    field :job_type, :string
    field :status, :string, default: "pending"
    field :external_job_id, :string
    field :input_params, :map, default: %{}
    field :results, :map, default: %{}
    field :error_message, :string
    field :cost, :decimal
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :user, PhoenixBlog.Blog.Author, foreign_key: :user_id
    belongs_to :competitor, PhoenixBlog.Competitors.Competitor
    has_many :research_data, PhoenixBlog.Research.ResearchData

    timestamps(type: :utc_datetime)
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :job_type,
      :status,
      :external_job_id,
      :input_params,
      :results,
      :error_message,
      :cost,
      :started_at,
      :completed_at,
      :user_id,
      :competitor_id
    ])
    |> validate_required([:job_type, :user_id])
    |> validate_inclusion(:job_type, @job_types)
    |> validate_inclusion(:status, @status_values)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:competitor_id)
  end

  def start_changeset(job) do
    job
    |> change(%{status: "running", started_at: DateTime.utc_now()})
  end

  def complete_changeset(job, results) do
    job
    |> change(%{status: "completed", results: results, completed_at: DateTime.utc_now()})
  end

  def fail_changeset(job, error_message) do
    job
    |> change(%{status: "failed", error_message: error_message, completed_at: DateTime.utc_now()})
  end

  def job_types, do: @job_types
  def status_values, do: @status_values

  def running?(%__MODULE__{status: "running"}), do: true
  def running?(_), do: false

  def completed?(%__MODULE__{status: "completed"}), do: true
  def completed?(_), do: false
end
