defmodule PhoenixBlog.Generations.ContentGeneration do
  @moduledoc """
  Schema for content generations.

  Tracks queued and completed AI content generations (text, images, video)
  with delivery status and cost tracking.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @content_types ~w(social_post blog_post image video carousel)
  @status_values ~w(queued processing completed failed delivered)
  @delivery_methods ~w(email webhook in_app)

  schema "content_generations" do
    field :content_type, :string
    field :status, :string, default: "queued"
    field :input_prompt, :string
    field :input_params, :map, default: %{}
    field :output_content, :string
    field :output_urls, {:array, :string}, default: []
    field :provider, :string
    field :model, :string
    field :cost, :decimal
    field :delivery_method, :string
    field :delivered_at, :utc_datetime
    field :error_message, :string

    belongs_to :user, PhoenixBlog.Blog.Author, foreign_key: :user_id
    belongs_to :insight, PhoenixBlog.Insights.Insight

    timestamps(type: :utc_datetime)
  end

  def changeset(generation, attrs) do
    generation
    |> cast(attrs, [
      :content_type,
      :status,
      :input_prompt,
      :input_params,
      :output_content,
      :output_urls,
      :provider,
      :model,
      :cost,
      :delivery_method,
      :delivered_at,
      :error_message,
      :user_id,
      :insight_id
    ])
    |> validate_required([:content_type, :user_id])
    |> validate_inclusion(:content_type, @content_types)
    |> validate_inclusion(:status, @status_values)
    |> validate_inclusion(:delivery_method, @delivery_methods ++ [nil])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:insight_id)
  end

  def start_processing_changeset(generation) do
    generation
    |> change(%{status: "processing"})
  end

  def complete_changeset(generation, output_content, output_urls, provider, model, cost) do
    generation
    |> change(%{
      status: "completed",
      output_content: output_content,
      output_urls: output_urls,
      provider: provider,
      model: model,
      cost: cost
    })
  end

  def fail_changeset(generation, error_message) do
    generation
    |> change(%{status: "failed", error_message: error_message})
  end

  def deliver_changeset(generation) do
    generation
    |> change(%{status: "delivered", delivered_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end

  def content_types, do: @content_types
  def status_values, do: @status_values
  def delivery_methods, do: @delivery_methods

  def completed?(%__MODULE__{status: "completed"}), do: true
  def completed?(_), do: false

  def delivered?(%__MODULE__{status: "delivered"}), do: true
  def delivered?(_), do: false

  def image?(%__MODULE__{content_type: type}) when type in ["image", "carousel"], do: true
  def image?(_), do: false

  def video?(%__MODULE__{content_type: "video"}), do: true
  def video?(_), do: false
end
