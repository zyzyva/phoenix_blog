defmodule PhoenixBlog.Content.Features do
  @moduledoc """
  Loads and provides access to product feature definitions.

  Features are defined in a JSON file and can be updated without code changes.
  The file is loaded at runtime and cached.

  ## Feature Structure

  Each feature has:
  - `name` - Display name (e.g., "QR Code Generator")
  - `label` - Short label for UI (e.g., "Create free QR codes")
  - `url` - Link to the feature
  - `url_note` - Additional context about the URL (e.g., "requires free account")
  - `pricing` - Pricing info (e.g., "Free", "Premium only")
  - `description` - Full description for content generation
  - `use_cases` - List of example use cases
  - `cta` - Suggested call-to-action text

  ## Configuration

  Configure the path to your features file:

      config :phoenix_blog, :features_file, "priv/content/features.json"
  """

  @default_features_file "priv/content/features.json"

  @doc """
  Returns all features as a map keyed by feature ID.
  """
  def all do
    load_features()
  end

  @doc """
  Returns a list of {label, key, short_description} tuples for form options.
  """
  def options do
    load_features()
    |> Enum.map(fn {key, feature} ->
      {feature["name"], key, feature["label"]}
    end)
    |> Enum.sort_by(fn {name, _key, _label} -> name end)
  end

  @doc """
  Returns the full details for a single feature by key.
  """
  def get(key) do
    Map.get(load_features(), key)
  end

  @doc """
  Formats feature details for AI prompt generation.

  Returns a formatted string with all relevant details for the AI to use
  when generating content that mentions this feature. Includes screenshots
  from the database showing the feature workflow.
  """
  def format_for_prompt(key) do
    case get(key) do
      nil ->
        nil

      feature ->
        url_text =
          if feature["url_note"] do
            "#{feature["url"]} (#{feature["url_note"]})"
          else
            feature["url"]
          end

        use_cases_text =
          feature["use_cases"]
          |> Enum.map(&("  * " <> &1))
          |> Enum.join("\n")

        # Load screenshots from database
        screenshots = PhoenixBlog.Content.FeatureScreenshots.list_screenshots(key)
        screenshots_text = format_screenshots_for_prompt(screenshots)

        """
        **#{feature["name"]}**
        URL: #{url_text}
        Pricing: #{feature["pricing"]}
        #{feature["description"]}
        Use cases:
        #{use_cases_text}
        Suggested CTA: #{feature["cta"]}
        #{screenshots_text}
        """
    end
  end

  defp format_screenshots_for_prompt([]), do: ""

  defp format_screenshots_for_prompt(screenshots) do
    screenshot_lines =
      screenshots
      |> Enum.with_index(1)
      |> Enum.map(fn {screenshot, step_num} ->
        step_label =
          if screenshot.step_description do
            "Step #{step_num}: #{screenshot.step_description}"
          else
            "Step #{step_num}"
          end

        caption = screenshot.caption || screenshot.alt_text

        """
        #{step_label}
        ![#{screenshot.alt_text}](#{screenshot.url})
        *#{caption}*
        """
      end)
      |> Enum.join("\n")

    """

    SCREENSHOTS (include these in the blog to show the workflow):
    #{screenshot_lines}
    """
  end

  @doc """
  Formats multiple features for AI prompt generation.
  """
  def format_many_for_prompt(keys) when is_list(keys) do
    keys
    |> Enum.map(&format_for_prompt/1)
    |> Enum.reject(&is_nil/1)
  end

  def format_many_for_prompt(_), do: []

  @doc """
  Reloads features from disk. Useful if the file has been updated.
  """
  def reload do
    :persistent_term.erase({__MODULE__, :features})
    load_features()
  end

  # Load features from JSON file, caching in persistent_term
  defp load_features do
    case :persistent_term.get({__MODULE__, :features}, nil) do
      nil ->
        features = do_load_features()
        :persistent_term.put({__MODULE__, :features}, features)
        features

      features ->
        features
    end
  end

  defp do_load_features do
    features_file = Application.get_env(:phoenix_blog, :features_file, @default_features_file)
    path = Application.app_dir(:phoenix_blog, features_file)

    case File.read(path) do
      {:ok, content} ->
        case JSON.decode(content) do
          {:ok, features} ->
            features

          {:error, reason} ->
            require Logger
            Logger.error("Failed to parse features.json: #{inspect(reason)}")
            %{}
        end

      {:error, reason} ->
        require Logger
        Logger.warning("Failed to read features.json: #{inspect(reason)}")
        %{}
    end
  end
end
