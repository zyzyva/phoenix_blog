defmodule PhoenixBlog.AI.ImageGenerator do
  @moduledoc """
  Unified image generation interface.

  Primary backend: Hugging Face Inference Providers (routes to Fal AI, Replicate, etc.)
  Fallback: Direct provider clients (Gemini, Imagen)

  ## Usage

      # Simple generation (uses HuggingFace -> auto-selects provider)
      ImageGenerator.generate("product photo of headphones")

      # Fastest provider
      ImageGenerator.generate("product photo", strategy: :fastest)

      # Cheapest provider
      ImageGenerator.generate("product photo", strategy: :cheapest)

      # Specific provider through HuggingFace
      ImageGenerator.generate("product photo", provider: "fal-ai")

      # Direct backend (bypasses HuggingFace)
      ImageGenerator.generate("product photo", backend: :gemini)

      # Platform-optimized
      ImageGenerator.generate_for_platform("product photo", :instagram_feed)

      # Compare providers
      ImageGenerator.compare("product photo", providers: ["fal-ai", "replicate"])
  """

  require Logger

  alias PhoenixBlog.AI.{HuggingFaceClient, GeminiClient, ImagenClient}

  @type backend :: :huggingface | :gemini | :imagen
  @type strategy :: :auto | :fastest | :cheapest
  @type platform :: :instagram_feed | :instagram_stories | :youtube_thumbnail | :linkedin | :twitter | :square

  # ============================================================================
  # Primary Generation
  # ============================================================================

  @doc """
  Generates an image using the specified backend or HuggingFace (default).

  ## Options

  - `:backend` - Direct backend: `:huggingface` (default), `:gemini`, `:imagen`
  - `:strategy` - Provider selection: `:auto`, `:fastest`, `:cheapest`
  - `:provider` - Specific HF provider: "fal-ai", "replicate", "together", etc.
  - `:model` - Specific model (e.g., "black-forest-labs/FLUX.1-dev")

  ## Returns

  - `{:ok, %{image_data: binary, mime_type: string, backend: atom, ...}}`
  - `{:error, reason}`
  """
  def generate(prompt, opts \\ []) do
    backend = Keyword.get(opts, :backend, :huggingface)
    dispatch_generate(backend, prompt, opts)
  end

  @doc """
  Generates an image optimized for a specific platform.

  Automatically sets dimensions and can add platform-specific prompt enhancements.

  ## Platforms

  - `:instagram_feed` - 4:5 vertical (1080x1350)
  - `:instagram_stories` - 9:16 vertical (1080x1920)
  - `:youtube_thumbnail` - 16:9 horizontal (1280x720)
  - `:linkedin` - 1.91:1 horizontal (1200x628)
  - `:twitter` - 16:9 horizontal (1200x675)
  - `:square` - 1:1 (1024x1024)
  """
  def generate_for_platform(prompt, platform, opts \\ []) do
    backend = Keyword.get(opts, :backend, :huggingface)

    case backend do
      :huggingface ->
        HuggingFaceClient.text_to_image_for_platform(prompt, platform, opts)

      :gemini ->
        enhanced_prompt = add_platform_guidance(prompt, platform)
        GeminiClient.generate_image(enhanced_prompt, opts)

      :imagen ->
        {width, height} = platform_dimensions(platform)
        aspect_ratio = dimensions_to_aspect_ratio(width, height)
        ImagenClient.generate_image(prompt, Keyword.put(opts, :aspect_ratio, aspect_ratio))
    end
  end

  # ============================================================================
  # Comparison
  # ============================================================================

  @doc """
  Generates images from multiple providers for comparison.

  ## Options

  - `:providers` - List of HuggingFace providers to compare
  - `:backends` - List of direct backends to compare

  ## Returns

  List of `{provider_or_backend, result}` tuples with timing data.
  """
  def compare(prompt, opts \\ []) do
    providers = Keyword.get(opts, :providers, [])
    backends = Keyword.get(opts, :backends, [])
    clean_opts = opts |> Keyword.delete(:providers) |> Keyword.delete(:backends)

    # Compare HuggingFace providers
    provider_results =
      providers
      |> Task.async_stream(
        fn provider ->
          result = HuggingFaceClient.text_to_image(prompt, Keyword.put(clean_opts, :provider, provider))
          {provider, result}
        end,
        timeout: 120_000,
        on_timeout: :kill_task
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, :timeout} -> {"timeout", {:error, "Generation timed out"}}
      end)

    # Compare direct backends
    backend_results =
      backends
      |> Task.async_stream(
        fn backend ->
          result = dispatch_generate(backend, prompt, clean_opts)
          {backend, result}
        end,
        timeout: 120_000,
        on_timeout: :kill_task
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, :timeout} -> {:timeout, {:error, "Generation timed out"}}
      end)

    provider_results ++ backend_results
  end

  # ============================================================================
  # Provider Info
  # ============================================================================

  @doc """
  Returns list of available HuggingFace providers for image generation.
  """
  def available_providers do
    HuggingFaceClient.list_providers(:text_to_image)
  end

  @doc """
  Returns list of available models.
  """
  def available_models do
    HuggingFaceClient.list_models(:text_to_image)
  end

  @doc """
  Returns list of configured backends.
  """
  def configured_backends do
    []
    |> maybe_add_backend(:huggingface, HuggingFaceClient.configured?())
    |> maybe_add_backend(:gemini, GeminiClient.configured?())
    |> maybe_add_backend(:imagen, ImagenClient.configured?())
  end

  # ============================================================================
  # Private - Dispatch
  # ============================================================================

  defp dispatch_generate(:huggingface, prompt, opts) do
    case HuggingFaceClient.text_to_image(prompt, opts) do
      {:ok, result} -> {:ok, Map.put(result, :backend, :huggingface)}
      error -> error
    end
  end

  defp dispatch_generate(:gemini, prompt, opts) do
    case GeminiClient.generate_image(prompt, opts) do
      {:ok, result} -> {:ok, Map.put(result, :backend, :gemini)}
      error -> error
    end
  end

  defp dispatch_generate(:imagen, prompt, opts) do
    case ImagenClient.generate_image(prompt, opts) do
      {:ok, result} -> {:ok, Map.put(result, :backend, :imagen)}
      error -> error
    end
  end

  defp dispatch_generate(backend, _prompt, _opts) do
    {:error, "Unknown backend: #{backend}"}
  end

  # ============================================================================
  # Private - Helpers
  # ============================================================================

  defp maybe_add_backend(list, backend, true), do: [backend | list]
  defp maybe_add_backend(list, _backend, false), do: list

  defp platform_dimensions(:instagram_feed), do: {1080, 1350}
  defp platform_dimensions(:instagram_stories), do: {1080, 1920}
  defp platform_dimensions(:youtube_thumbnail), do: {1280, 720}
  defp platform_dimensions(:linkedin), do: {1200, 628}
  defp platform_dimensions(:twitter), do: {1200, 675}
  defp platform_dimensions(:square), do: {1024, 1024}
  defp platform_dimensions(_), do: {1024, 1024}

  defp dimensions_to_aspect_ratio(1080, 1350), do: "4:5"
  defp dimensions_to_aspect_ratio(1080, 1920), do: "9:16"
  defp dimensions_to_aspect_ratio(1280, 720), do: "16:9"
  defp dimensions_to_aspect_ratio(1200, 628), do: "16:9"
  defp dimensions_to_aspect_ratio(1200, 675), do: "16:9"
  defp dimensions_to_aspect_ratio(1024, 1024), do: "1:1"
  defp dimensions_to_aspect_ratio(_, _), do: "1:1"

  defp add_platform_guidance(prompt, :instagram_feed) do
    "#{prompt}, optimized for Instagram feed (4:5 vertical), bold vibrant colors, scroll-stopping"
  end

  defp add_platform_guidance(prompt, :instagram_stories) do
    "#{prompt}, optimized for Instagram Stories (9:16 vertical), content centered in middle third"
  end

  defp add_platform_guidance(prompt, :youtube_thumbnail) do
    "#{prompt}, optimized for YouTube thumbnail (16:9), high contrast, bold colors, dramatic"
  end

  defp add_platform_guidance(prompt, :linkedin) do
    "#{prompt}, optimized for LinkedIn (professional), sophisticated, clean design"
  end

  defp add_platform_guidance(prompt, :twitter) do
    "#{prompt}, optimized for Twitter/X (16:9), high contrast for dark mode"
  end

  defp add_platform_guidance(prompt, _), do: prompt
end
