defmodule PhoenixBlog.AI.GeminiClient do
  @moduledoc """
  Google AI Studio client for Gemini image generation.

  Uses Gemini 3 Pro Image (internally called "Nano Banana Pro") for high-quality
  image generation with excellent text rendering capabilities.

  ## Configuration

  Requires the following environment variable:
  - `GOOGLE_AI_API_KEY` - Your Google AI Studio API key

  Get your API key at: https://aistudio.google.com/apikey

  Configure in your app:

      config :phoenix_blog,
        google_ai_api_key: System.get_env("GOOGLE_AI_API_KEY")

  ## Model

  Uses `gemini-2.0-flash-preview-image-generation` (Gemini 2.0 Flash with image output).
  This is the publicly available model as of Dec 2024.

  Note: When `gemini-3-pro-image-preview` becomes available, update @default_model.
  """

  require Logger

  @base_url "https://generativelanguage.googleapis.com/v1beta"
  @default_model "gemini-2.0-flash-preview-image-generation"
  @timeout 60_000

  @doc """
  Generates an image based on the given prompt.

  ## Options

  - `:aspect_ratio` - Image aspect ratio (not directly supported, use prompt guidance)
  - `:model` - Override the default model

  ## Returns

  - `{:ok, %{image_data: binary, mime_type: string}}` - The generated image
  - `{:error, reason}` - If generation fails
  """
  def generate_image(prompt, opts \\ []) do
    if configured?() do
      do_generate(prompt, opts)
    else
      {:error, "Google AI API key not configured. Set GOOGLE_AI_API_KEY."}
    end
  end

  @doc """
  Generates an image optimized for a specific platform.

  Automatically adds platform-specific guidance to the prompt.

  ## Platforms

  - `:instagram_feed` - 4:5 ratio, bold colors, scroll-stopping
  - `:instagram_stories` - 9:16 vertical, center content
  - `:youtube_thumbnail` - 16:9, high contrast, bold
  - `:linkedin` - 1.91:1, professional aesthetic
  - `:twitter` - 16:9, dark mode optimized
  """
  def generate_for_platform(prompt, platform, opts \\ []) do
    enhanced_prompt = add_platform_guidance(prompt, platform)
    generate_image(enhanced_prompt, opts)
  end

  @doc """
  Checks if the Gemini API is configured.
  """
  def configured? do
    get_api_key() != nil
  end

  # ============================================================================
  # Private - Generation
  # ============================================================================

  defp do_generate(prompt, opts) do
    model = Keyword.get(opts, :model, @default_model)
    api_key = get_api_key()

    url = "#{@base_url}/models/#{model}:generateContent?key=#{api_key}"

    body = %{
      contents: [
        %{
          parts: [
            %{text: prompt}
          ]
        }
      ],
      generationConfig: %{
        responseModalities: ["TEXT", "IMAGE"]
      }
    }

    make_request(url, body)
  end

  defp make_request(url, body) do
    headers = [
      {"content-type", "application/json"}
    ]

    url
    |> Req.post(json: body, headers: headers, receive_timeout: @timeout)
    |> handle_response()
  end

  defp handle_response({:ok, %{status: 200, body: body}}) do
    extract_image_from_response(body)
  end

  defp handle_response({:ok, %{status: 400, body: body}}) do
    error_msg = extract_error_message(body)
    Logger.error("Gemini: Bad request - #{error_msg}")
    {:error, "Invalid request: #{error_msg}"}
  end

  defp handle_response({:ok, %{status: 401}}) do
    Logger.error("Gemini: Invalid API key")
    {:error, "Invalid API key"}
  end

  defp handle_response({:ok, %{status: 429}}) do
    Logger.warning("Gemini: Rate limited")
    {:error, "Rate limited - please try again later"}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.error("Gemini: Unexpected status #{status}: #{inspect(body)}")
    {:error, "API error (status #{status})"}
  end

  defp handle_response({:error, %Req.TransportError{reason: :timeout}}) do
    Logger.error("Gemini: Request timeout")
    {:error, "Request timed out"}
  end

  defp handle_response({:error, reason}) do
    Logger.error("Gemini: Request failed - #{inspect(reason)}")
    {:error, "Failed to connect to Gemini API"}
  end

  # ============================================================================
  # Private - Response Parsing
  # ============================================================================

  defp extract_image_from_response(%{"candidates" => [candidate | _]}) do
    parts = get_in(candidate, ["content", "parts"]) || []

    case find_image_part(parts) do
      nil ->
        Logger.error("Gemini: No image in response")
        {:error, "No image generated"}

      %{"inlineData" => %{"data" => base64_data, "mimeType" => mime_type}} ->
        {:ok, %{image_data: Base.decode64!(base64_data), mime_type: mime_type}}

      %{"inlineData" => %{"data" => base64_data}} ->
        {:ok, %{image_data: Base.decode64!(base64_data), mime_type: "image/png"}}
    end
  end

  defp extract_image_from_response(body) do
    Logger.error("Gemini: Unexpected response structure: #{inspect(body)}")
    {:error, "Unexpected response format"}
  end

  defp find_image_part(parts) do
    Enum.find(parts, fn
      %{"inlineData" => _} -> true
      _ -> false
    end)
  end

  defp extract_error_message(%{"error" => %{"message" => msg}}), do: msg
  defp extract_error_message(body), do: inspect(body)

  # ============================================================================
  # Private - Platform Optimization
  # ============================================================================

  defp add_platform_guidance(prompt, :instagram_feed) do
    """
    #{prompt}

    Optimize for Instagram feed post (4:5 vertical ratio):
    - Bold, vibrant colors that pop in feed
    - Strong focal point, scroll-stopping composition
    - Clean space for potential text overlay
    """
  end

  defp add_platform_guidance(prompt, :instagram_stories) do
    """
    #{prompt}

    Optimize for Instagram Stories (9:16 vertical ratio):
    - Content centered in middle third (avoid top/bottom)
    - Full vertical composition
    - Mobile-first viewing
    """
  end

  defp add_platform_guidance(prompt, :youtube_thumbnail) do
    """
    #{prompt}

    Optimize for YouTube thumbnail (16:9 horizontal ratio):
    - High contrast, bold colors (yellow performs well)
    - Clear focal point, simple composition
    - Space for text on left or right third
    - Dramatic lighting, attention-grabbing
    """
  end

  defp add_platform_guidance(prompt, :linkedin) do
    """
    #{prompt}

    Optimize for LinkedIn (1.91:1 horizontal ratio):
    - Professional, sophisticated aesthetic
    - Clean, corporate-appropriate design
    - Thought leadership visual style
    """
  end

  defp add_platform_guidance(prompt, :twitter) do
    """
    #{prompt}

    Optimize for Twitter/X (16:9 horizontal ratio):
    - High contrast for dark mode viewing
    - Bold, punchy visual style
    - Clear at small preview size
    """
  end

  defp add_platform_guidance(prompt, _platform), do: prompt

  # ============================================================================
  # Private - Config
  # ============================================================================

  defp get_api_key do
    Application.get_env(:phoenix_blog, :google_ai_api_key)
  end
end
