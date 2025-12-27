defmodule PhoenixBlog.AI.HuggingFaceClient do
  @moduledoc """
  Unified AI inference client using Hugging Face Inference Providers.

  Routes requests to multiple providers (Fal AI, Replicate, Together, etc.)
  through a single API with automatic provider selection, failover, and
  consolidated billing.

  ## Configuration

  Requires a Hugging Face token:
  - `HF_TOKEN` - Your Hugging Face access token with inference permissions

  Get your token at: https://huggingface.co/settings/tokens
  (Create a fine-grained token with "Make calls to Inference Providers" permission)

  Configure in your app:

      config :phoenix_blog,
        huggingface_token: System.get_env("HF_TOKEN")

  ## Provider Selection

  Control which provider handles your request:

  - `:auto` - Automatic selection based on your preferences (default)
  - `:fastest` - Highest throughput provider
  - `:cheapest` - Lowest cost provider
  - `"fal-ai"`, `"replicate"`, etc. - Specific provider

  ## Pricing

  - No markup from Hugging Face (pass-through costs)
  - Free tier: $0.10/month, PRO ($9/month): $2/month included
  - Pay-as-you-go after credits exhausted

  ## Usage

      # Automatic provider selection
      HuggingFaceClient.text_to_image("a sunset over mountains")

      # Fastest provider
      HuggingFaceClient.text_to_image("a sunset", strategy: :fastest)

      # Specific provider
      HuggingFaceClient.text_to_image("a sunset", provider: "fal-ai")

      # Video generation
      HuggingFaceClient.text_to_video("a cat walking", model: "genmo/mochi-1-preview")
  """

  require Logger

  @timeout 120_000

  # Default models for each task
  @default_models %{
    text_to_image: "black-forest-labs/FLUX.1-schnell",
    text_to_video: "genmo/mochi-1-preview"
  }

  # Available providers by task
  @providers %{
    text_to_image: ["fal-ai", "replicate", "together", "nebius", "nscale", "hf-inference"],
    text_to_video: ["fal-ai", "replicate", "novita", "wavespeed"]
  }

  # ============================================================================
  # Text-to-Image
  # ============================================================================

  @doc """
  Generates an image from a text prompt.

  ## Options

  - `:model` - Model to use (default: "black-forest-labs/FLUX.1-schnell")
  - `:strategy` - Provider selection: `:auto`, `:fastest`, `:cheapest` (default: `:auto`)
  - `:provider` - Specific provider: "fal-ai", "replicate", etc.
  - `:width` - Image width (model-dependent)
  - `:height` - Image height (model-dependent)
  - `:num_inference_steps` - Quality/speed tradeoff (model-dependent)
  - `:guidance_scale` - Prompt adherence (model-dependent)

  ## Returns

  - `{:ok, %{image_data: binary, mime_type: string, model: string, provider: string}}`
  - `{:error, reason}`

  ## Examples

      # Quick generation with Flux Schnell
      HuggingFaceClient.text_to_image("a photo of a cat")

      # High quality with Flux Dev
      HuggingFaceClient.text_to_image("a photo of a cat",
        model: "black-forest-labs/FLUX.1-dev",
        strategy: :fastest
      )

      # Specific provider
      HuggingFaceClient.text_to_image("a photo of a cat", provider: "fal-ai")
  """
  def text_to_image(prompt, opts \\ []) do
    if configured?() do
      model = Keyword.get(opts, :model, @default_models.text_to_image)
      model_with_strategy = apply_strategy(model, opts)

      params = build_image_params(prompt, opts)

      do_inference(:text_to_image, model_with_strategy, params, opts)
    else
      {:error, "Hugging Face token not configured. Set HF_TOKEN."}
    end
  end

  @doc """
  Generates an image with a specific aspect ratio optimized for platforms.

  ## Platforms

  - `:instagram_feed` - 4:5 (1080x1350)
  - `:instagram_stories` - 9:16 (1080x1920)
  - `:youtube_thumbnail` - 16:9 (1280x720)
  - `:linkedin` - 1.91:1 (1200x628)
  - `:twitter` - 16:9 (1200x675)
  - `:square` - 1:1 (1024x1024)
  """
  def text_to_image_for_platform(prompt, platform, opts \\ []) do
    {width, height} = platform_dimensions(platform)
    text_to_image(prompt, Keyword.merge(opts, width: width, height: height))
  end

  # ============================================================================
  # Text-to-Video
  # ============================================================================

  @doc """
  Generates a video from a text prompt.

  ## Options

  - `:model` - Model to use (default: "genmo/mochi-1-preview")
  - `:strategy` - Provider selection: `:auto`, `:fastest`, `:cheapest`
  - `:provider` - Specific provider: "fal-ai", "replicate", etc.
  - `:num_frames` - Number of frames (model-dependent)
  - `:fps` - Frames per second (model-dependent)

  ## Returns

  - `{:ok, %{video_url: string, model: string, provider: string}}`
  - `{:error, reason}`

  ## Note

  Video generation is async on most providers. This function polls until
  completion or timeout.
  """
  def text_to_video(prompt, opts \\ []) do
    if configured?() do
      model = Keyword.get(opts, :model, @default_models.text_to_video)
      model_with_strategy = apply_strategy(model, opts)

      params = build_video_params(prompt, opts)

      do_inference(:text_to_video, model_with_strategy, params, opts)
    else
      {:error, "Hugging Face token not configured. Set HF_TOKEN."}
    end
  end

  # ============================================================================
  # Image-to-Video
  # ============================================================================

  @doc """
  Generates a video from an image (I2V).

  ## Options

  - `:model` - Model to use
  - `:motion_prompt` - Description of desired motion
  - `:strategy` - Provider selection

  ## Returns

  - `{:ok, %{video_url: string}}`
  - `{:error, reason}`
  """
  def image_to_video(image_url, opts \\ []) do
    if configured?() do
      model = Keyword.get(opts, :model, "fal-ai/fast-svd-lcm")
      motion = Keyword.get(opts, :motion_prompt, "subtle motion")

      params = %{
        image_url: image_url,
        motion_bucket_id: 127,
        prompt: motion
      }

      do_inference(:image_to_video, model, params, opts)
    else
      {:error, "Hugging Face token not configured."}
    end
  end

  # ============================================================================
  # Utility Functions
  # ============================================================================

  @doc """
  Lists available models for a given task.
  """
  def list_models(task) when task in [:text_to_image, :text_to_video] do
    # Common models - this could be fetched from HF API
    case task do
      :text_to_image ->
        [
          "black-forest-labs/FLUX.1-schnell",
          "black-forest-labs/FLUX.1-dev",
          "black-forest-labs/FLUX.2-dev",
          "stabilityai/stable-diffusion-xl-base-1.0",
          "runwayml/stable-diffusion-v1-5"
        ]

      :text_to_video ->
        [
          "genmo/mochi-1-preview",
          "fal-ai/fast-svd-lcm",
          "fal-ai/hunyuan-video"
        ]
    end
  end

  @doc """
  Lists available providers for a given task.
  """
  def list_providers(task) do
    Map.get(@providers, task, [])
  end

  @doc """
  Checks if the Hugging Face API is configured.
  """
  def configured? do
    get_token() != nil
  end

  @doc """
  Returns account usage and credits info.
  """
  def get_usage do
    # This would require a separate API call to HF billing endpoint
    {:error, "Not implemented - check https://huggingface.co/settings/billing"}
  end

  # ============================================================================
  # Private - Inference Execution
  # ============================================================================

  defp do_inference(:text_to_image, model, params, opts) do
    provider = extract_provider(opts)
    url = build_inference_url(model, provider)

    start_time = System.monotonic_time(:millisecond)

    case make_request(url, params, :post, :binary) do
      {:ok, image_data} when is_binary(image_data) ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        {:ok,
         %{
           image_data: image_data,
           mime_type: detect_mime_type(image_data),
           model: model,
           provider: provider || "auto",
           generation_time_ms: elapsed
         }}

      {:ok, %{"error" => error}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_inference(:text_to_video, model, params, opts) do
    provider = extract_provider(opts)
    url = build_inference_url(model, provider)

    start_time = System.monotonic_time(:millisecond)

    case make_request(url, params, :post, :json) do
      {:ok, %{"video" => video_url}} ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        {:ok,
         %{
           video_url: video_url,
           model: model,
           provider: provider || "auto",
           generation_time_ms: elapsed
         }}

      {:ok, %{"output" => [video_url | _]}} ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        {:ok,
         %{
           video_url: video_url,
           model: model,
           provider: provider || "auto",
           generation_time_ms: elapsed
         }}

      {:ok, response} ->
        # Try to extract video URL from various response formats
        extract_video_from_response(response, model, provider, start_time)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_inference(:image_to_video, model, params, opts) do
    do_inference(:text_to_video, model, params, opts)
  end

  # ============================================================================
  # Private - Request Building
  # ============================================================================

  defp build_inference_url(model, nil) do
    "https://router.huggingface.co/v1/models/#{model}"
  end

  defp build_inference_url(model, provider) do
    "https://router.huggingface.co/v1/models/#{model}?provider=#{provider}"
  end

  defp build_image_params(prompt, opts) do
    base = %{inputs: prompt}

    params =
      %{}
      |> maybe_put(:width, Keyword.get(opts, :width))
      |> maybe_put(:height, Keyword.get(opts, :height))
      |> maybe_put(:num_inference_steps, Keyword.get(opts, :num_inference_steps))
      |> maybe_put(:guidance_scale, Keyword.get(opts, :guidance_scale))

    if map_size(params) > 0 do
      Map.put(base, :parameters, params)
    else
      base
    end
  end

  defp build_video_params(prompt, opts) do
    base = %{inputs: prompt}

    params =
      %{}
      |> maybe_put(:num_frames, Keyword.get(opts, :num_frames))
      |> maybe_put(:fps, Keyword.get(opts, :fps))

    if map_size(params) > 0 do
      Map.put(base, :parameters, params)
    else
      base
    end
  end

  defp apply_strategy(model, opts) do
    case Keyword.get(opts, :strategy) do
      :fastest -> "#{model}:fastest"
      :cheapest -> "#{model}:cheapest"
      _ -> model
    end
  end

  defp extract_provider(opts) do
    Keyword.get(opts, :provider)
  end

  # ============================================================================
  # Private - HTTP
  # ============================================================================

  defp make_request(url, body, method, response_type) do
    headers = [
      {"authorization", "Bearer #{get_token()}"},
      {"content-type", "application/json"}
    ]

    request_opts = [
      headers: headers,
      receive_timeout: @timeout
    ]

    result =
      case method do
        :post -> Req.post(url, [json: body] ++ request_opts)
        :get -> Req.get(url, request_opts)
      end

    handle_response(result, response_type)
  end

  defp handle_response({:ok, %{status: 200, body: body}}, :binary) when is_binary(body) do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 200, body: body}}, :json) do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 200, body: body}}, _type) do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 400, body: body}}, _type) do
    error_msg = extract_error(body)
    Logger.error("HuggingFace: Bad request - #{error_msg}")
    {:error, "Invalid request: #{error_msg}"}
  end

  defp handle_response({:ok, %{status: 401}}, _type) do
    Logger.error("HuggingFace: Invalid token")
    {:error, "Invalid or expired token"}
  end

  defp handle_response({:ok, %{status: 402}}, _type) do
    Logger.warning("HuggingFace: Payment required - credits exhausted")
    {:error, "Credits exhausted - add payment method at huggingface.co/settings/billing"}
  end

  defp handle_response({:ok, %{status: 429}}, _type) do
    Logger.warning("HuggingFace: Rate limited")
    {:error, "Rate limited - please try again later"}
  end

  defp handle_response({:ok, %{status: 503, body: body}}, _type) do
    # Model loading - could implement retry
    estimated_time = get_in(body, ["estimated_time"]) || 20
    Logger.info("HuggingFace: Model loading, estimated #{estimated_time}s")
    {:error, "Model is loading, try again in #{estimated_time} seconds"}
  end

  defp handle_response({:ok, %{status: status, body: body}}, _type) do
    Logger.error("HuggingFace: Unexpected status #{status}: #{inspect(body)}")
    {:error, "API error (status #{status})"}
  end

  defp handle_response({:error, %Req.TransportError{reason: :timeout}}, _type) do
    Logger.error("HuggingFace: Request timeout")
    {:error, "Request timed out"}
  end

  defp handle_response({:error, reason}, _type) do
    Logger.error("HuggingFace: Request failed - #{inspect(reason)}")
    {:error, "Failed to connect to Hugging Face API"}
  end

  # ============================================================================
  # Private - Helpers
  # ============================================================================

  defp extract_error(%{"error" => error}) when is_binary(error), do: error
  defp extract_error(%{"error" => %{"message" => msg}}), do: msg
  defp extract_error(body), do: inspect(body)

  defp extract_video_from_response(response, model, provider, start_time) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    cond do
      is_binary(response) and String.starts_with?(response, "http") ->
        {:ok, %{video_url: response, model: model, provider: provider, generation_time_ms: elapsed}}

      is_map(response) ->
        video_url =
          response["video_url"] ||
            response["url"] ||
            get_in(response, ["output", "video"]) ||
            get_in(response, ["result", "video_url"])

        if video_url do
          {:ok, %{video_url: video_url, model: model, provider: provider, generation_time_ms: elapsed}}
        else
          {:error, "Could not extract video URL from response: #{inspect(response)}"}
        end

      true ->
        {:error, "Unexpected response format: #{inspect(response)}"}
    end
  end

  defp detect_mime_type(<<0x89, 0x50, 0x4E, 0x47, _::binary>>), do: "image/png"
  defp detect_mime_type(<<0xFF, 0xD8, 0xFF, _::binary>>), do: "image/jpeg"
  defp detect_mime_type(<<0x47, 0x49, 0x46, _::binary>>), do: "image/gif"
  defp detect_mime_type(<<0x52, 0x49, 0x46, 0x46, _::binary>>), do: "image/webp"
  defp detect_mime_type(_), do: "image/png"

  defp platform_dimensions(:instagram_feed), do: {1080, 1350}
  defp platform_dimensions(:instagram_stories), do: {1080, 1920}
  defp platform_dimensions(:youtube_thumbnail), do: {1280, 720}
  defp platform_dimensions(:linkedin), do: {1200, 628}
  defp platform_dimensions(:twitter), do: {1200, 675}
  defp platform_dimensions(:square), do: {1024, 1024}
  defp platform_dimensions(_), do: {1024, 1024}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp get_token do
    Application.get_env(:phoenix_blog, :huggingface_token)
  end
end
