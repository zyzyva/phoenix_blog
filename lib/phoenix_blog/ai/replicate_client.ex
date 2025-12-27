defmodule PhoenixBlog.AI.ReplicateClient do
  @moduledoc """
  Replicate API client for image and video generation.

  Provides access to various AI models hosted on Replicate, including:
  - Flux (fast, high-quality images)
  - SDXL (Stable Diffusion XL)
  - Various specialized models

  ## Configuration

  Requires the following environment variable:
  - `REPLICATE_API_TOKEN` - Your Replicate API token

  Get your token at: https://replicate.com/account/api-tokens

  Configure in your app:

      config :phoenix_blog,
        replicate_api_token: System.get_env("REPLICATE_API_TOKEN")

  ## Models

  Default models by use case:
  - Image generation: `black-forest-labs/flux-schnell` (fast) or `flux-dev` (quality)
  - Product photos: `black-forest-labs/flux-dev`
  - Lip sync: `cjwbw/sadtalker` or `wavymulder/wav2lip`
  """

  require Logger

  @base_url "https://api.replicate.com/v1"
  @timeout 120_000
  @poll_interval 1_000

  # Model versions - update these as new versions are released
  @models %{
    flux_schnell: "black-forest-labs/flux-schnell",
    flux_dev: "black-forest-labs/flux-dev",
    sdxl: "stability-ai/sdxl",
    sadtalker: "cjwbw/sadtalker"
  }

  @doc """
  Generates an image using the specified model.

  ## Options

  - `:model` - Model to use (default: :flux_schnell)
  - `:aspect_ratio` - Image aspect ratio (model-dependent)
  - `:num_outputs` - Number of images to generate (default: 1)
  - `:wait` - Whether to wait for completion (default: true)

  ## Returns

  - `{:ok, %{image_data: binary, mime_type: string, urls: list}}` - The generated image(s)
  - `{:error, reason}` - If generation fails
  """
  def generate_image(prompt, opts \\ []) do
    if configured?() do
      model = Keyword.get(opts, :model, :flux_schnell)
      wait = Keyword.get(opts, :wait, true)

      case create_prediction(model, prompt, opts) do
        {:ok, prediction} when wait -> wait_for_prediction(prediction)
        {:ok, prediction} -> {:ok, prediction}
        error -> error
      end
    else
      {:error, "Replicate API token not configured. Set REPLICATE_API_TOKEN."}
    end
  end

  @doc """
  Generates a lip-synced video from an image and audio.

  Uses SadTalker or similar model to animate a face image with audio.

  ## Options

  - `:model` - Model to use (default: :sadtalker)
  - `:preprocess` - Face preprocessing: "crop", "resize", "full" (default: "crop")

  ## Returns

  - `{:ok, %{video_url: string}}` - URL to the generated video
  - `{:error, reason}` - If generation fails
  """
  def generate_lip_sync(image_url, audio_url, opts \\ []) do
    if configured?() do
      model = Keyword.get(opts, :model, :sadtalker)
      preprocess = Keyword.get(opts, :preprocess, "crop")

      input = %{
        source_image: image_url,
        driven_audio: audio_url,
        preprocess: preprocess
      }

      case create_prediction_raw(get_model_id(model), input) do
        {:ok, prediction} -> wait_for_prediction(prediction)
        error -> error
      end
    else
      {:error, "Replicate API token not configured."}
    end
  end

  @doc """
  Gets the status of a prediction.
  """
  def get_prediction(prediction_id) do
    url = "#{@base_url}/predictions/#{prediction_id}"

    url
    |> Req.get(headers: auth_headers(), receive_timeout: @timeout)
    |> handle_response()
  end

  @doc """
  Cancels a running prediction.
  """
  def cancel_prediction(prediction_id) do
    url = "#{@base_url}/predictions/#{prediction_id}/cancel"

    url
    |> Req.post(headers: auth_headers(), receive_timeout: @timeout)
    |> handle_response()
  end

  @doc """
  Checks if the Replicate API is configured.
  """
  def configured? do
    get_api_token() != nil
  end

  @doc """
  Lists available model presets.
  """
  def available_models, do: Map.keys(@models)

  # ============================================================================
  # Private - Prediction Creation
  # ============================================================================

  defp create_prediction(model_key, prompt, opts) do
    model_id = get_model_id(model_key)
    aspect_ratio = Keyword.get(opts, :aspect_ratio, "1:1")
    num_outputs = Keyword.get(opts, :num_outputs, 1)

    input =
      case model_key do
        m when m in [:flux_schnell, :flux_dev] ->
          %{
            prompt: prompt,
            aspect_ratio: aspect_ratio,
            num_outputs: num_outputs,
            output_format: "png"
          }

        :sdxl ->
          %{
            prompt: prompt,
            width: aspect_to_width(aspect_ratio),
            height: aspect_to_height(aspect_ratio),
            num_outputs: num_outputs
          }

        _ ->
          %{prompt: prompt}
      end

    create_prediction_raw(model_id, input)
  end

  defp create_prediction_raw(model_id, input) do
    url = "#{@base_url}/models/#{model_id}/predictions"

    body = %{input: input}

    url
    |> Req.post(json: body, headers: auth_headers(), receive_timeout: @timeout)
    |> handle_response()
  end

  # ============================================================================
  # Private - Polling
  # ============================================================================

  defp wait_for_prediction(%{"id" => id, "status" => status} = _prediction)
       when status in ["starting", "processing"] do
    Process.sleep(@poll_interval)

    case get_prediction(id) do
      {:ok, updated} -> wait_for_prediction(updated)
      error -> error
    end
  end

  defp wait_for_prediction(%{"status" => "succeeded", "output" => output}) do
    fetch_and_return_images(output)
  end

  defp wait_for_prediction(%{"status" => "failed", "error" => error}) do
    Logger.error("Replicate: Prediction failed - #{error}")
    {:error, error}
  end

  defp wait_for_prediction(%{"status" => "canceled"}) do
    {:error, "Prediction was canceled"}
  end

  defp wait_for_prediction(prediction) do
    Logger.error("Replicate: Unexpected prediction state: #{inspect(prediction)}")
    {:error, "Unexpected prediction state"}
  end

  # ============================================================================
  # Private - Response Handling
  # ============================================================================

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 401}}) do
    Logger.error("Replicate: Invalid API token")
    {:error, "Invalid API token"}
  end

  defp handle_response({:ok, %{status: 422, body: body}}) do
    error_msg = get_in(body, ["detail"]) || inspect(body)
    Logger.error("Replicate: Validation error - #{error_msg}")
    {:error, "Validation error: #{error_msg}"}
  end

  defp handle_response({:ok, %{status: 429}}) do
    Logger.warning("Replicate: Rate limited")
    {:error, "Rate limited - please try again later"}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.error("Replicate: Unexpected status #{status}: #{inspect(body)}")
    {:error, "API error (status #{status})"}
  end

  defp handle_response({:error, %Req.TransportError{reason: :timeout}}) do
    Logger.error("Replicate: Request timeout")
    {:error, "Request timed out"}
  end

  defp handle_response({:error, reason}) do
    Logger.error("Replicate: Request failed - #{inspect(reason)}")
    {:error, "Failed to connect to Replicate API"}
  end

  # ============================================================================
  # Private - Image Fetching
  # ============================================================================

  defp fetch_and_return_images(urls) when is_list(urls) do
    case urls do
      [url | _] when is_binary(url) ->
        fetch_image(url)

      _ ->
        {:ok, %{urls: urls, image_data: nil, mime_type: nil}}
    end
  end

  defp fetch_and_return_images(url) when is_binary(url) do
    fetch_image(url)
  end

  defp fetch_and_return_images(output) do
    {:ok, %{output: output, image_data: nil, mime_type: nil}}
  end

  defp fetch_image(url) do
    case Req.get(url, receive_timeout: @timeout) do
      {:ok, %{status: 200, body: body, headers: headers}} ->
        mime_type =
          headers
          |> Enum.find_value("image/png", fn
            {"content-type", value} -> value
            _ -> nil
          end)

        {:ok, %{image_data: body, mime_type: mime_type, url: url}}

      {:ok, %{status: status}} ->
        {:error, "Failed to fetch image (status #{status})"}

      {:error, reason} ->
        {:error, "Failed to fetch image: #{inspect(reason)}"}
    end
  end

  # ============================================================================
  # Private - Helpers
  # ============================================================================

  defp get_model_id(key) when is_atom(key), do: Map.get(@models, key, @models.flux_schnell)
  defp get_model_id(model_id) when is_binary(model_id), do: model_id

  defp auth_headers do
    [
      {"authorization", "Bearer #{get_api_token()}"},
      {"content-type", "application/json"}
    ]
  end

  defp get_api_token do
    Application.get_env(:phoenix_blog, :replicate_api_token)
  end

  # Aspect ratio to dimensions (for models that need explicit dimensions)
  defp aspect_to_width("1:1"), do: 1024
  defp aspect_to_width("4:5"), do: 896
  defp aspect_to_width("16:9"), do: 1344
  defp aspect_to_width("9:16"), do: 768
  defp aspect_to_width(_), do: 1024

  defp aspect_to_height("1:1"), do: 1024
  defp aspect_to_height("4:5"), do: 1120
  defp aspect_to_height("16:9"), do: 768
  defp aspect_to_height("9:16"), do: 1344
  defp aspect_to_height(_), do: 1024
end
