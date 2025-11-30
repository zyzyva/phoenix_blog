defmodule PhoenixBlog.Content.FeatureScreenshot do
  @moduledoc """
  Schema for feature workflow screenshots.

  Screenshots document product features and are included in blog posts
  to provide visual context for readers.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "blog_feature_screenshots" do
    field :feature_key, :string
    field :position, :integer, default: 0
    field :url, :string
    field :storage_key, :string
    field :alt_text, :string
    field :caption, :string
    field :step_description, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating feature screenshots.
  """
  def changeset(screenshot, attrs) do
    screenshot
    |> cast(attrs, [
      :feature_key,
      :position,
      :url,
      :storage_key,
      :alt_text,
      :caption,
      :step_description
    ])
    |> validate_required([:feature_key, :url, :storage_key])
    |> validate_length(:alt_text, max: 255)
    |> validate_length(:caption, max: 500)
    |> validate_length(:step_description, max: 200)
  end
end
