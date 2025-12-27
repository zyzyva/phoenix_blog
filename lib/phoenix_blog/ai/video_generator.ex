defmodule PhoenixBlog.AI.VideoGenerator do
  @moduledoc """
  Unified video generation interface.

  Primary backend: Hugging Face Inference Providers (routes to Fal AI, Replicate, Novita, etc.)

  ## Supported Providers (via HuggingFace)

  - `fal-ai` - Fast, good quality (Mochi, SVD)
  - `replicate` - Wide model selection
  - `novita` - Video generation
  - `wavespeed` - Video generation

  ## Usage

      # Simple generation (auto-selects provider)
      VideoGenerator.generate("a cat walking through a garden")

      # Fastest provider
      VideoGenerator.generate("a cat walking", strategy: :fastest)

      # Specific provider
      VideoGenerator.generate("a cat walking", provider: "fal-ai")

      # Image-to-video
      VideoGenerator.generate_from_image(image_url, "slow zoom out")

      # Compare providers
      VideoGenerator.compare("a sunset timelapse", providers: ["fal-ai", "replicate"])
  """

  require Logger

  alias PhoenixBlog.AI.HuggingFaceClient

  @type strategy :: :auto | :fastest | :cheapest
  @type video_type :: :product_reveal | :hero_banner | :social_ad | :brand_cinematic | :ugc_style

  # ============================================================================
  # Text-to-Video
  # ============================================================================

  @doc """
  Generates a video from a text prompt.

  ## Options

  - `:strategy` - Provider selection: `:auto`, `:fastest`, `:cheapest`
  - `:provider` - Specific HF provider: "fal-ai", "replicate", etc.
  - `:model` - Specific model (e.g., "genmo/mochi-1-preview")
  - `:type` - Video type for prompt optimization

  ## Returns

  - `{:ok, %{video_url: string, provider: string, generation_time_ms: integer}}`
  - `{:error, reason}`
  """
  def generate(prompt, opts \\ []) do
    video_type = Keyword.get(opts, :type)
    enhanced_prompt = maybe_enhance_prompt(prompt, video_type)

    case HuggingFaceClient.text_to_video(enhanced_prompt, opts) do
      {:ok, result} -> {:ok, Map.put(result, :backend, :huggingface)}
      error -> error
    end
  end

  @doc """
  Generates a video optimized for a specific use case.

  ## Types

  - `:product_reveal` - Product photography with motion
  - `:hero_banner` - Website hero with subtle animation
  - `:social_ad` - Attention-grabbing social media ad
  - `:brand_cinematic` - Cinematic brand content
  - `:ugc_style` - User-generated content aesthetic
  """
  def generate_for_type(prompt, type, opts \\ []) do
    generate(prompt, Keyword.put(opts, :type, type))
  end

  # ============================================================================
  # Image-to-Video
  # ============================================================================

  @doc """
  Generates a video from an existing image (I2V).

  Better for:
  - Product photography that needs subtle motion
  - Maintaining exact visual fidelity
  - Hero images that need animation

  ## Options

  - `:motion_prompt` - Description of desired motion
  - `:provider` - Specific provider
  - `:model` - Specific I2V model

  ## Returns

  - `{:ok, %{video_url: string}}`
  - `{:error, reason}`
  """
  def generate_from_image(image_url, motion_prompt \\ "subtle motion", opts \\ []) do
    case HuggingFaceClient.image_to_video(image_url, Keyword.put(opts, :motion_prompt, motion_prompt)) do
      {:ok, result} -> {:ok, Map.put(result, :backend, :huggingface)}
      error -> error
    end
  end

  # ============================================================================
  # Comparison
  # ============================================================================

  @doc """
  Generates videos from multiple providers for comparison.

  ## Options

  - `:providers` - List of HuggingFace providers to compare

  ## Returns

  List of `{provider, result}` tuples with timing data.
  """
  def compare(prompt, opts \\ []) do
    providers = Keyword.get(opts, :providers, ["fal-ai", "replicate"])
    clean_opts = Keyword.delete(opts, :providers)

    providers
    |> Task.async_stream(
      fn provider ->
        result = HuggingFaceClient.text_to_video(prompt, Keyword.put(clean_opts, :provider, provider))
        {provider, result}
      end,
      timeout: 180_000,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, :timeout} -> {"timeout", {:error, "Generation timed out"}}
    end)
  end

  # ============================================================================
  # Provider Info
  # ============================================================================

  @doc """
  Returns list of available providers for video generation.
  """
  def available_providers do
    HuggingFaceClient.list_providers(:text_to_video)
  end

  @doc """
  Returns list of available models.
  """
  def available_models do
    HuggingFaceClient.list_models(:text_to_video)
  end

  @doc """
  Returns the recommended provider for a given video type.
  """
  def recommend_provider(type) do
    case type do
      :product_reveal -> "fal-ai"
      :hero_banner -> "fal-ai"
      :social_ad -> "fal-ai"
      :brand_cinematic -> "replicate"
      :ugc_style -> "fal-ai"
      _ -> "fal-ai"
    end
  end

  @doc """
  Returns model capabilities for comparison.
  """
  def model_capabilities do
    %{
      "genmo/mochi-1-preview" => %{
        provider: "fal-ai",
        max_duration: 5,
        strengths: ["fast", "good motion"],
        best_for: [:social_ad, :ugc_style]
      },
      "fal-ai/fast-svd-lcm" => %{
        provider: "fal-ai",
        mode: :i2v,
        strengths: ["image-to-video", "fast"],
        best_for: [:product_reveal, :hero_banner]
      },
      "fal-ai/hunyuan-video" => %{
        provider: "fal-ai",
        max_duration: 6,
        strengths: ["high quality", "longer clips"],
        best_for: [:brand_cinematic]
      }
    }
  end

  @doc """
  Checks if video generation is configured.
  """
  def configured? do
    HuggingFaceClient.configured?()
  end

  # ============================================================================
  # Private - Prompt Enhancement
  # ============================================================================

  defp maybe_enhance_prompt(prompt, nil), do: prompt

  defp maybe_enhance_prompt(prompt, :product_reveal) do
    "#{prompt}, smooth product reveal, professional lighting, subtle motion, commercial quality"
  end

  defp maybe_enhance_prompt(prompt, :hero_banner) do
    "#{prompt}, gentle ambient motion, seamless loop potential, website hero aesthetic"
  end

  defp maybe_enhance_prompt(prompt, :social_ad) do
    "#{prompt}, attention-grabbing motion, dynamic energy, social media ad quality"
  end

  defp maybe_enhance_prompt(prompt, :brand_cinematic) do
    "#{prompt}, cinematic quality, dramatic lighting, professional film aesthetic"
  end

  defp maybe_enhance_prompt(prompt, :ugc_style) do
    "#{prompt}, authentic natural motion, casual aesthetic, user-generated content style"
  end

  defp maybe_enhance_prompt(prompt, _), do: prompt
end
