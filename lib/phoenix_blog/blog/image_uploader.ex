defmodule PhoenixBlog.Blog.ImageUploader do
  @moduledoc """
  Handles image uploads to cloud storage (R2/S3) for the blog system.

  Uses ExAws.S3 to generate presigned URLs for direct browser uploads
  and manage image storage.
  """

  alias ExAws.Config
  alias ExAws.S3

  @allowed_types ~w(image/jpeg image/png image/gif image/webp)
  @max_file_size 10 * 1024 * 1024

  @doc """
  Presign function for Phoenix LiveView external uploads.

  This is called by LiveView for each file entry. Returns the upload URL
  and metadata to be sent with the upload.
  """
  def presign_upload(entry, socket) do
    case get_storage_config() do
      {:ok, config} ->
        storage_key = generate_storage_key(entry.client_name)
        content_type = entry.client_type

        opts = [
          expires_in: 3600,
          virtual_host: false,
          query_params: [{"Content-Type", content_type}]
        ]

        {:ok, presigned_url} =
          S3.presigned_url(Config.new(:s3), :put, config.bucket, storage_key, opts)

        public_url = "#{config.public_url}/#{storage_key}"

        meta = %{
          uploader: "S3",
          storage_key: storage_key,
          public_url: public_url,
          filename: entry.client_name,
          content_type: content_type
        }

        {:ok, %{uploader: "S3", url: presigned_url, fields: %{}}, meta, socket}

      {:error, :storage_not_configured} ->
        {:error, "Cloud storage not configured"}
    end
  end

  @doc """
  Generates a presigned PUT URL for direct browser upload.

  Returns {:ok, %{url: presigned_url, storage_key: key, public_url: cdn_url}}
  or {:error, reason}
  """
  def generate_presigned_url(filename, content_type) do
    with :ok <- validate_content_type(content_type),
         storage_key <- generate_storage_key(filename),
         presigned_url <- build_presigned_url(storage_key, content_type),
         public_url <- build_public_url(storage_key) do
      {:ok, %{url: presigned_url, storage_key: storage_key, public_url: public_url}}
    end
  end

  @doc """
  Generates a unique storage key for the image with date-based path structure.
  Format: blog/images/{year}/{month}/{uuid}-{sanitized-filename}.{ext}

  Options:
  - `:ai_generated` - if true, stores in blog/images/ai-generated/ subfolder
  """
  def generate_storage_key(filename, opts \\ []) do
    now = DateTime.utc_now()
    year = now.year
    month = now.month |> Integer.to_string() |> String.pad_leading(2, "0")
    uuid = Ecto.UUID.generate() |> String.slice(0, 8)
    sanitized = sanitize_filename(filename)

    if Keyword.get(opts, :ai_generated, false) do
      "blog/images/ai-generated/#{year}/#{month}/#{uuid}-#{sanitized}"
    else
      "blog/images/#{year}/#{month}/#{uuid}-#{sanitized}"
    end
  end

  @doc """
  Builds the public CDN URL for an image given its storage key.
  """
  def build_public_url(storage_key) do
    case get_storage_config() do
      {:ok, config} ->
        "#{config.public_url}/#{storage_key}"

      {:error, _} ->
        nil
    end
  end

  @doc """
  Uploads image data directly to storage (server-side upload).

  Used for AI-generated images that are already in memory.

  Options:
  - `:ai_generated` - if true, stores in blog/images/ai-generated/ subfolder

  Returns {:ok, %{storage_key: key, public_url: url}} or {:error, reason}
  """
  def upload_image_data(image_data, filename, content_type, opts \\ []) do
    with :ok <- validate_content_type(content_type),
         {:ok, config} <- get_storage_config() do
      storage_key = generate_storage_key(filename, opts)

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
    end
  end

  @doc """
  Deletes an image from storage.
  """
  def delete_from_storage(storage_key) do
    case get_storage_config() do
      {:ok, config} ->
        config.bucket
        |> S3.delete_object(storage_key)
        |> ExAws.request()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the list of allowed content types.
  """
  def allowed_types, do: @allowed_types

  @doc """
  Returns the maximum file size in bytes.
  """
  def max_file_size, do: @max_file_size

  # Private Functions

  defp validate_content_type(content_type) do
    if content_type in @allowed_types do
      :ok
    else
      {:error, "Invalid content type. Allowed: #{Enum.join(@allowed_types, ", ")}"}
    end
  end

  defp build_presigned_url(storage_key, content_type) do
    case get_storage_config() do
      {:ok, config} ->
        opts = [
          expires_in: 3600,
          virtual_host: false,
          query_params: [{"Content-Type", content_type}]
        ]

        {:ok, url} = S3.presigned_url(Config.new(:s3), :put, config.bucket, storage_key, opts)

        url

      {:error, _} = error ->
        error
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
