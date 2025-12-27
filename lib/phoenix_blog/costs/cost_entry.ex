defmodule PhoenixBlog.Costs.CostEntry do
  @moduledoc """
  Schema for cost tracking entries.

  Records usage and costs for external AI and scraping services
  to enable budget monitoring and usage analysis.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @services ~w(apify huggingface claude gemini replicate meta_ads openai anthropic)

  schema "cost_tracking" do
    field :service, :string
    field :operation, :string
    field :input_tokens, :integer
    field :output_tokens, :integer
    field :units, :decimal
    field :cost, :decimal
    field :request_id, :string
    field :metadata, :map, default: %{}

    belongs_to :user, PhoenixBlog.Blog.Author, foreign_key: :user_id

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :service,
      :operation,
      :input_tokens,
      :output_tokens,
      :units,
      :cost,
      :request_id,
      :metadata,
      :user_id
    ])
    |> validate_required([:service, :operation, :cost, :user_id])
    |> validate_inclusion(:service, @services)
    |> validate_number(:cost, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
  end

  def services, do: @services

  def total_tokens(%__MODULE__{input_tokens: input, output_tokens: output}) do
    (input || 0) + (output || 0)
  end
end
