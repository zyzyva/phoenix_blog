defmodule PhoenixBlog.Content.FeatureScreenshots do
  @moduledoc """
  Context for managing feature screenshots.

  Provides functions to upload, reorder, and retrieve screenshots
  that document product feature workflows.
  """

  import Ecto.Query
  alias ExAws.S3
  alias PhoenixBlog.Blog.ImageUploader
  alias PhoenixBlog.Content.FeatureScreenshot
  alias PhoenixBlog.Content.ImageProcessor
  alias PhoenixBlog.Repo

  @doc """
  Returns all screenshots for a feature, ordered by position.
  """
  def list_screenshots(feature_key) do
    FeatureScreenshot
    |> where([s], s.feature_key == ^feature_key)
    |> order_by([s], asc: s.position)
    |> Repo.all()
  end

  @doc """
  Returns screenshots for multiple features as a map.
  """
  def list_screenshots_by_features(feature_keys) when is_list(feature_keys) do
    FeatureScreenshot
    |> where([s], s.feature_key in ^feature_keys)
    |> order_by([s], asc: s.feature_key, asc: s.position)
    |> Repo.all()
    |> Enum.group_by(& &1.feature_key)
  end

  @doc """
  Returns all screenshots grouped by feature.
  """
  def list_all_screenshots do
    FeatureScreenshot
    |> order_by([s], asc: s.feature_key, asc: s.position)
    |> Repo.all()
    |> Enum.group_by(& &1.feature_key)
  end

  @doc """
  Gets a single screenshot by ID.
  """
  def get_screenshot(id) do
    Repo.get(FeatureScreenshot, id)
  end

  @doc """
  Gets a single screenshot by ID, raises if not found.
  """
  def get_screenshot!(id) do
    Repo.get!(FeatureScreenshot, id)
  end

  @doc """
  Creates a screenshot record after processing and uploading the image.

  The image is resized to max 1200px width and optimized before upload.
  """
  def create_screenshot(feature_key, image_data, filename, content_type, attrs \\ %{}) do
    # Process image (resize, optimize) before upload
    {processed_data, processed_type} =
      case ImageProcessor.process_screenshot(image_data, content_type) do
        {:ok, data, type} -> {data, type}
        # Fall back to original if processing fails
        _ -> {image_data, content_type}
      end

    # Update filename extension if content type changed
    processed_filename = update_filename_extension(filename, processed_type)

    # Upload to storage in feature-screenshots folder
    case upload_screenshot(processed_data, processed_filename, processed_type, feature_key) do
      {:ok, %{storage_key: storage_key, public_url: url}} ->
        # Get next position for this feature
        next_position = get_next_position(feature_key)

        screenshot_attrs =
          Map.merge(attrs, %{
            feature_key: feature_key,
            position: next_position,
            url: url,
            storage_key: storage_key,
            alt_text: attrs[:alt_text] || attrs["alt_text"] || "Screenshot of #{feature_key}"
          })

        %FeatureScreenshot{}
        |> FeatureScreenshot.changeset(screenshot_attrs)
        |> Repo.insert()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates a screenshot's metadata (not the image itself).
  """
  def update_screenshot(%FeatureScreenshot{} = screenshot, attrs) do
    screenshot
    |> FeatureScreenshot.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a screenshot and removes the file from storage.
  """
  def delete_screenshot(%FeatureScreenshot{} = screenshot) do
    # Delete from storage
    ImageUploader.delete_from_storage(screenshot.storage_key)

    # Delete from database
    Repo.delete(screenshot)
  end

  @doc """
  Reorders screenshots for a feature.

  Takes a list of screenshot IDs in the desired order.
  """
  def reorder_screenshots(feature_key, screenshot_ids) when is_list(screenshot_ids) do
    Repo.transaction(fn ->
      screenshot_ids
      |> Enum.with_index()
      |> Enum.each(fn {id, position} ->
        FeatureScreenshot
        |> where([s], s.id == ^id and s.feature_key == ^feature_key)
        |> Repo.update_all(set: [position: position])
      end)
    end)
  end

  @doc """
  Moves a screenshot to a new position.
  """
  def move_screenshot(%FeatureScreenshot{} = screenshot, new_position) do
    old_position = screenshot.position
    feature_key = screenshot.feature_key

    Repo.transaction(fn ->
      cond do
        new_position > old_position ->
          # Moving down: shift items in between up
          FeatureScreenshot
          |> where([s], s.feature_key == ^feature_key)
          |> where([s], s.position > ^old_position and s.position <= ^new_position)
          |> Repo.update_all(inc: [position: -1])

        new_position < old_position ->
          # Moving up: shift items in between down
          FeatureScreenshot
          |> where([s], s.feature_key == ^feature_key)
          |> where([s], s.position >= ^new_position and s.position < ^old_position)
          |> Repo.update_all(inc: [position: 1])

        true ->
          :ok
      end

      # Update the screenshot's position
      screenshot
      |> FeatureScreenshot.changeset(%{position: new_position})
      |> Repo.update!()
    end)
  end

  @doc """
  Returns count of screenshots per feature.
  """
  def screenshot_counts do
    FeatureScreenshot
    |> group_by([s], s.feature_key)
    |> select([s], {s.feature_key, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  # Private functions

  defp get_next_position(feature_key) do
    FeatureScreenshot
    |> where([s], s.feature_key == ^feature_key)
    |> select([s], max(s.position))
    |> Repo.one()
    |> case do
      nil -> 0
      max -> max + 1
    end
  end

  defp update_filename_extension(filename, content_type) do
    base = Path.rootname(filename)

    extension =
      case content_type do
        "image/jpeg" -> ".jpg"
        "image/png" -> ".png"
        "image/webp" -> ".webp"
        _ -> Path.extname(filename)
      end

    base <> extension
  end

  defp upload_screenshot(image_data, filename, content_type, feature_key) do
    # Sanitize feature key for path
    safe_key = String.replace(feature_key, ~r/[^\w-]/, "_")

    # Generate storage key with feature-specific path
    now = DateTime.utc_now()
    year = now.year
    month = now.month |> Integer.to_string() |> String.pad_leading(2, "0")
    uuid = Ecto.UUID.generate() |> String.slice(0, 8)
    sanitized = sanitize_filename(filename)

    storage_key =
      "blog/images/feature-screenshots/#{safe_key}/#{year}/#{month}/#{uuid}-#{sanitized}"

    case get_storage_config() do
      {:ok, config} ->
        result =
          config.bucket
          |> S3.put_object(storage_key, image_data, content_type: content_type)
          |> ExAws.request()

        case result do
          {:ok, _} ->
            public_url = "#{config.public_url}/#{storage_key}"
            {:ok, %{storage_key: storage_key, public_url: public_url}}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sanitize_filename(filename) do
    filename
    |> String.downcase()
    |> String.replace(~r/[^\w\.\-]/u, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
    |> String.slice(0, 100)
  end

  defp get_storage_config do
    case Application.get_env(:phoenix_blog, :storage) do
      nil ->
        {:error, :storage_not_configured}

      config ->
        {:ok,
         %{
           bucket: Keyword.get(config, :bucket),
           public_url: Keyword.get(config, :public_url)
         }}
    end
  end
end
