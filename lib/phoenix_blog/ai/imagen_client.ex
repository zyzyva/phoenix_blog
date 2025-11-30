defmodule PhoenixBlog.AI.ImagenClient do
  @moduledoc """
  Google Vertex AI Imagen client for blog image generation.

  Uses Google's Imagen model to generate featured images for blog posts
  based on the post topic and content.

  ## Configuration

  Requires the following environment variables:
  - `GOOGLE_CLOUD_PROJECT` - Your Google Cloud project ID
  - `GOOGLE_CLOUD_LOCATION` - Region (e.g., "us-central1")
  - `GOOGLE_APPLICATION_CREDENTIALS` - Path to service account JSON key file

  Configure in your app:

      config :phoenix_blog,
        google_cloud_project: System.get_env("GOOGLE_CLOUD_PROJECT"),
        google_cloud_location: System.get_env("GOOGLE_CLOUD_LOCATION") || "us-central1",
        imagen_model: System.get_env("IMAGEN_MODEL") || "imagen-4.0-generate-001"

  The service account needs the "Vertex AI User" role.
  """

  require Logger

  @default_model "imagen-4.0-generate-001"
  @timeout 60_000

  @doc """
  Generates an image based on the given prompt.

  Returns the image as base64-encoded PNG data.

  ## Options

  - `:aspect_ratio` - Image aspect ratio: "1:1", "3:4", "4:3", "16:9", "9:16" (default: "16:9")
  - `:style` - Additional style guidance to append to prompt

  ## Returns

  - `{:ok, %{image_data: binary, mime_type: string}}` - The generated image
  - `{:error, reason}` - If generation fails
  """
  def generate_image(prompt, opts \\ []) do
    if configured?() do
      do_generate(prompt, opts)
    else
      {:error, "Google Cloud credentials not configured"}
    end
  end

  @doc """
  Generates a blog featured image based on the generated content.

  Creates an appropriate prompt for blog imagery using the title and excerpt
  for a more tailored image.

  ## Options

  - `:aspect_ratio` - Default "16:9" for blog headers
  - `:tone` - The blog tone to influence image style
  - `:title` - The generated blog title
  - `:excerpt` - The generated blog excerpt/summary
  """
  def generate_blog_image(topic, opts \\ []) do
    tone = Keyword.get(opts, :tone, "professional")
    aspect_ratio = Keyword.get(opts, :aspect_ratio, "16:9")
    title = Keyword.get(opts, :title)
    excerpt = Keyword.get(opts, :excerpt)

    image_prompt = build_blog_image_prompt(topic, tone, title, excerpt)

    generate_image(image_prompt, aspect_ratio: aspect_ratio)
  end

  defp build_blog_image_prompt(topic, tone, title, excerpt) do
    style_modifier =
      case tone do
        "casual" -> "friendly and approachable"
        "friendly" -> "warm and inviting"
        "authoritative" -> "bold and professional"
        "conversational" -> "natural and relatable"
        _ -> "clean and professional"
      end

    main_subject = title || topic

    context_line =
      if excerpt && excerpt != "" do
        "Context: #{excerpt}"
      else
        ""
      end

    """
    Create a #{style_modifier} blog header image for an article titled: "#{main_subject}"

    #{context_line}

    Style requirements:
    - Modern, clean design suitable for a business blog
    - Abstract or conceptual representation (no text or words in the image)
    - Professional color palette
    - High quality, suitable for web use
    - Subtle and sophisticated, not cartoonish
    - Should visually complement the article topic
    """
  end

  defp do_generate(prompt, opts) do
    aspect_ratio = Keyword.get(opts, :aspect_ratio, "16:9")

    project_id = get_config(:google_cloud_project)
    location = get_config(:google_cloud_location) || "us-central1"
    model = get_config(:imagen_model) || @default_model

    url = build_api_url(project_id, location, model)

    body = %{
      instances: [%{prompt: prompt}],
      parameters: %{
        sampleCount: 1,
        aspectRatio: aspect_ratio,
        addWatermark: false,
        safetySetting: "block_medium_and_above"
      }
    }

    case get_access_token() do
      {:ok, token} ->
        make_request(url, body, token)

      {:error, reason} ->
        Logger.error("Imagen: Failed to get access token - #{inspect(reason)}")
        {:error, "Authentication failed"}
    end
  end

  defp build_api_url(project_id, location, model) do
    "https://#{location}-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/#{location}/publishers/google/models/#{model}:predict"
  end

  defp make_request(url, body, token) do
    headers = [
      {"authorization", "Bearer #{token}"},
      {"content-type", "application/json"}
    ]

    url
    |> Req.post(json: body, headers: headers, receive_timeout: @timeout)
    |> handle_response()
  end

  defp handle_response({:ok, %{status: 200, body: body}}) do
    case body do
      %{"predictions" => [%{"bytesBase64Encoded" => image_data, "mimeType" => mime_type} | _]} ->
        {:ok, %{image_data: Base.decode64!(image_data), mime_type: mime_type}}

      %{"predictions" => [%{"bytesBase64Encoded" => image_data} | _]} ->
        {:ok, %{image_data: Base.decode64!(image_data), mime_type: "image/png"}}

      _ ->
        Logger.error("Imagen: Unexpected response structure: #{inspect(body)}")
        {:error, "Unexpected response format"}
    end
  end

  defp handle_response({:ok, %{status: 400, body: body}}) do
    error_msg = extract_error_message(body)
    Logger.error("Imagen: Bad request - #{error_msg}")
    {:error, "Invalid request: #{error_msg}"}
  end

  defp handle_response({:ok, %{status: 401}}) do
    Logger.error("Imagen: Authentication failed")
    {:error, "Authentication failed - check credentials"}
  end

  defp handle_response({:ok, %{status: 403}}) do
    Logger.error("Imagen: Permission denied")
    {:error, "Permission denied - check service account permissions"}
  end

  defp handle_response({:ok, %{status: 429}}) do
    Logger.warning("Imagen: Rate limited")
    {:error, "Rate limited - please try again later"}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.error("Imagen: Unexpected status #{status}: #{inspect(body)}")
    {:error, "API error (status #{status})"}
  end

  defp handle_response({:error, %Req.TransportError{reason: :timeout}}) do
    Logger.error("Imagen: Request timeout")
    {:error, "Request timed out"}
  end

  defp handle_response({:error, reason}) do
    Logger.error("Imagen: Request failed - #{inspect(reason)}")
    {:error, "Failed to connect to Imagen API"}
  end

  defp extract_error_message(%{"error" => %{"message" => msg}}), do: msg
  defp extract_error_message(body), do: inspect(body)

  # Get access token using Google Application Default Credentials
  defp get_access_token do
    goth_name = get_config(:goth_name) || PhoenixBlog.Goth

    case Goth.fetch(goth_name) do
      {:ok, %{token: token}} -> {:ok, token}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_config(key) do
    Application.get_env(:phoenix_blog, key)
  end

  @doc """
  Checks if the Imagen API is configured.
  """
  def configured? do
    get_config(:google_cloud_project) != nil
  end
end
