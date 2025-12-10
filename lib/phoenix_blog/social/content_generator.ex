defmodule PhoenixBlog.Social.ContentGenerator do
  @moduledoc """
  Generates social media content from GitHub events using Claude.

  Takes PR merges, releases, and other events and creates platform-specific
  draft posts for review before publishing.
  """

  require Logger

  alias PhoenixBlog.Social

  @doc """
  Generates social media post drafts from a GitHub event.

  ## Options
  - `:platforms` - List of platforms to generate for (default: all)

  Returns {:ok, result} or {:error, reason}
  """
  def generate_from_github_event(feature_info, opts \\ []) do
    platforms = Keyword.get(opts, :platforms, ["twitter", "linkedin", "reddit"])

    with {:ok, content_variations} <- generate_content(feature_info, platforms),
         {:ok, post} <- create_draft_post(feature_info, content_variations) do
      Logger.info("Generated draft post #{post.id} from #{feature_info.type}")
      {:ok, %{post_id: post.id, platforms: Map.keys(content_variations)}}
    end
  end

  defp generate_content(feature_info, platforms) do
    result =
      if claude_configured?() do
        generate_with_claude(feature_info)
      else
        # Fallback to simple template-based generation
        {:ok, generate_simple(feature_info)}
      end

    # Filter to only requested platforms
    case result do
      {:ok, variations} ->
        filtered = Map.take(variations, platforms)
        {:ok, filtered}

      error ->
        error
    end
  end

  defp generate_with_claude(feature_info) do
    prompt = build_prompt(feature_info)

    case call_claude(prompt) do
      {:ok, response} ->
        {:ok, parse_claude_response(response)}

      {:error, reason} ->
        Logger.warning("Claude generation failed, using fallback: #{reason}")
        {:ok, generate_simple(feature_info)}
    end
  end

  defp build_prompt(feature_info) do
    event_type = if feature_info.type == :release, do: "release", else: "feature"

    """
    You are a social media manager for a software product. Generate engaging posts
    for different platforms based on this #{event_type}:

    **Title:** #{feature_info.title}

    **Description:**
    #{feature_info.body}

    **Repository:** #{feature_info.repo}
    **Link:** #{feature_info.url}

    Generate posts for each platform in this exact format:

    ---TWITTER---
    [Tweet text, max 280 chars, include link, use 1-2 relevant emojis]

    ---LINKEDIN---
    [Professional post, 1-3 paragraphs, highlight business value, include link]

    ---REDDIT---
    [Casual, community-friendly title and description, focus on what problem it solves]

    Guidelines:
    - Focus on the USER BENEFIT, not the technical implementation
    - Be concise and punchy for Twitter
    - Be more detailed and professional for LinkedIn
    - Be authentic and helpful for Reddit (avoid marketing speak)
    - Include the link naturally
    - Don't be overly salesy or use excessive emojis
    """
  end

  defp call_claude(prompt) do
    api_key = Application.get_env(:phoenix_blog, :anthropic_api_key)

    body = %{
      model: "claude-sonnet-4-20250514",
      max_tokens: 1500,
      messages: [%{role: "user", content: prompt}]
    }

    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]

    case Req.post("https://api.anthropic.com/v1/messages",
           json: body,
           headers: headers,
           receive_timeout: 60_000
         ) do
      {:ok, %{status: 200, body: %{"content" => [%{"text" => text} | _]}}} ->
        {:ok, text}

      {:ok, %{status: status, body: body}} ->
        {:error, "Claude API error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp parse_claude_response(response) do
    %{
      "twitter" => extract_section(response, "TWITTER"),
      "linkedin" => extract_section(response, "LINKEDIN"),
      "reddit" => extract_section(response, "REDDIT")
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp extract_section(content, section_name) do
    pattern = ~r/---#{section_name}---\s*\n(.*?)(?=\n---[A-Z]+---|$)/s

    case Regex.run(pattern, content) do
      [_, captured] -> String.trim(captured)
      nil -> nil
    end
  end

  # Simple fallback when Claude is not available
  defp generate_simple(feature_info) do
    title = feature_info.title
    url = feature_info.url

    twitter_text =
      if String.length(title) > 200 do
        String.slice(title, 0, 200) <> "... #{url}"
      else
        "#{title} #{url}"
      end

    %{
      "twitter" => twitter_text,
      "linkedin" => """
      New update: #{title}

      #{String.slice(feature_info.body || "", 0, 500)}

      Learn more: #{url}
      """,
      "reddit" => title
    }
  end

  defp create_draft_post(feature_info, content_variations) do
    # Use the Twitter version as the main content (most constrained)
    main_content = content_variations["twitter"] || Map.values(content_variations) |> List.first()

    # For now, use a default user_id (in production, this would come from config)
    user_id = get_default_user_id()

    Social.create_post(user_id, %{
      content_text: main_content,
      status: "draft",
      ai_generated: true,
      ai_prompt: "Generated from GitHub #{feature_info.type}: #{feature_info.title}",
      link_url: feature_info.url,
      metadata: %{
        github_event: feature_info.type,
        github_repo: feature_info.repo,
        platform_variations: content_variations
      }
    })
  end

  defp claude_configured? do
    Application.get_env(:phoenix_blog, :anthropic_api_key) != nil
  end

  defp get_default_user_id do
    # In production, you'd want to configure this per-repo
    # For now, default to user 1
    1
  end
end
