defmodule PhoenixBlog.AI.ClaudeClient do
  @moduledoc """
  Claude API client for AI-powered blog content generation.

  Uses the Anthropic Messages API to generate blog posts from topics and templates.

  ## Configuration

  Set the `ANTHROPIC_API_KEY` environment variable.
  Configure in your app:

      config :phoenix_blog, :anthropic_api_key, System.get_env("ANTHROPIC_API_KEY")
  """

  require Logger

  @api_url "https://api.anthropic.com/v1/messages"
  @default_model "claude-sonnet-4-5-20250929"
  @default_max_tokens 4000
  @timeout 120_000

  @doc """
  Generates a blog post from a topic using the specified template.

  Returns the generated content as markdown along with extracted metadata.

  ## Options

  - `:tone` - Writing tone (default: "professional")
  - `:length` - Target length: "short", "medium", "long" (default: "medium")
  - `:audience` - Target audience description
  - `:keywords` - List of keywords to incorporate
  - `:features` - List of formatted feature descriptions to highlight

  ## Returns

  - `{:ok, %{content: markdown, title: string, excerpt: string, meta_description: string}}`
  - `{:error, reason}`
  """
  def generate_blog_post(topic, template_type, opts \\ []) do
    if configured?() do
      alias PhoenixBlog.AI.BlogTemplates
      template = BlogTemplates.get_template(template_type)

      if template do
        do_generate(topic, template, opts)
      else
        {:error, "Unknown template type: #{template_type}"}
      end
    else
      {:error, "Anthropic API key not configured"}
    end
  end

  defp do_generate(topic, template, opts) do
    messages = build_messages(topic, template, opts)

    case make_request(messages, template.system_prompt) do
      {:ok, content} -> parse_blog_response(content)
      {:error, _} = error -> error
    end
  end

  defp build_messages(topic, template, opts) do
    tone = Keyword.get(opts, :tone, "professional")
    length = Keyword.get(opts, :length, "medium")
    audience = Keyword.get(opts, :audience, "general business professionals")
    keywords = Keyword.get(opts, :keywords, [])
    features = Keyword.get(opts, :features, [])

    length_guidance =
      case length do
        "short" -> "approximately 500-700 words"
        "medium" -> "approximately 1000-1500 words"
        "long" -> "approximately 2000-2500 words"
        _ -> "approximately 1000-1500 words"
      end

    keywords_text =
      if keywords != [] do
        "Naturally incorporate these keywords where appropriate: #{Enum.join(keywords, ", ")}."
      else
        ""
      end

    features_text =
      if features != [] do
        """
        PRODUCT FEATURES TO HIGHLIGHT:
        Naturally weave in mentions of these features where relevant to the topic:

        #{Enum.join(features, "\n---\n")}

        IMPORTANT INSTRUCTIONS FOR FEATURES:
        - Don't be overly promotional - integrate features as helpful solutions to problems discussed in the content
        - If a feature includes a "Screenshot" section with markdown image syntax, INSERT that exact markdown image into your blog content at the most relevant point when discussing that feature
        - Place screenshots after introducing the feature, with a brief caption or context
        - Link to the feature URL when mentioning it (use markdown link syntax)
        """
      else
        ""
      end

    user_prompt = """
    Write a blog post about: #{topic}

    Target audience: #{audience}
    Tone: #{tone}
    Length: #{length_guidance}
    #{keywords_text}
    #{features_text}

    #{template.structure_guidance}

    IMPORTANT: Your response must be in the following format:

    ---TITLE---
    [The blog post title]

    ---EXCERPT---
    [A compelling 1-2 sentence excerpt/summary for previews, max 150 characters]

    ---META_DESCRIPTION---
    [SEO meta description, max 155 characters]

    ---CONTENT---
    [The full blog post content in markdown format]
    """

    [%{role: "user", content: user_prompt}]
  end

  defp make_request(messages, system_prompt) do
    api_key = get_config(:anthropic_api_key)
    model = get_config(:anthropic_model) || @default_model
    max_tokens = get_config(:anthropic_max_tokens) || @default_max_tokens

    body = %{
      model: model,
      max_tokens: max_tokens,
      system: system_prompt,
      messages: messages
    }

    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]

    @api_url
    |> Req.post(json: body, headers: headers, receive_timeout: @timeout)
    |> handle_response()
  end

  defp handle_response({:ok, %{status: 200, body: body}}) do
    case body do
      %{"content" => [%{"text" => text} | _]} ->
        {:ok, text}

      _ ->
        Logger.error("Claude API: Unexpected response structure: #{inspect(body)}")
        {:error, "Unexpected response format from Claude"}
    end
  end

  defp handle_response({:ok, %{status: 400, body: body}}) do
    error_msg = get_in(body, ["error", "message"]) || "Bad request"
    Logger.error("Claude API: Bad request - #{error_msg}")
    {:error, "Invalid request: #{error_msg}"}
  end

  defp handle_response({:ok, %{status: 401}}) do
    Logger.error("Claude API: Authentication failed - invalid API key")
    {:error, "Authentication failed - check API key"}
  end

  defp handle_response({:ok, %{status: 429, body: body}}) do
    error_msg = get_in(body, ["error", "message"]) || "Rate limited"
    Logger.warning("Claude API: Rate limited - #{error_msg}")
    {:error, "Rate limited - please try again later"}
  end

  defp handle_response({:ok, %{status: 500}}) do
    Logger.error("Claude API: Server error")
    {:error, "Claude API server error - please try again"}
  end

  defp handle_response({:ok, %{status: 529}}) do
    Logger.warning("Claude API: Overloaded")
    {:error, "Claude API is overloaded - please try again later"}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.error("Claude API: Unexpected status #{status}: #{inspect(body)}")
    {:error, "Unexpected API error (status #{status})"}
  end

  defp handle_response({:error, %Req.TransportError{reason: :timeout}}) do
    Logger.error("Claude API: Request timeout")
    {:error, "Request timed out - the content may be too complex"}
  end

  defp handle_response({:error, reason}) do
    Logger.error("Claude API: Request failed - #{inspect(reason)}")
    {:error, "Failed to connect to Claude API"}
  end

  defp parse_blog_response(content) do
    title = extract_section(content, "TITLE")
    excerpt = extract_section(content, "EXCERPT")
    meta_description = extract_section(content, "META_DESCRIPTION")
    blog_content = extract_section(content, "CONTENT")

    if blog_content && String.length(blog_content) > 100 do
      {:ok,
       %{
         title: title || "Untitled",
         excerpt: excerpt || String.slice(blog_content, 0, 150),
         meta_description: meta_description || excerpt || String.slice(blog_content, 0, 155),
         content: blog_content
       }}
    else
      Logger.warning("Claude API: Response not in expected format, using raw content")

      {:ok,
       %{
         title: "Generated Post",
         excerpt: String.slice(content, 0, 150),
         meta_description: String.slice(content, 0, 155),
         content: content
       }}
    end
  end

  defp extract_section(content, section_name) do
    pattern = ~r/---#{section_name}---\s*\n(.*?)(?=\n---[A-Z_]+---|$)/s

    case Regex.run(pattern, content) do
      [_, captured] -> String.trim(captured)
      nil -> nil
    end
  end

  defp get_config(key) do
    Application.get_env(:phoenix_blog, key)
  end

  @doc """
  Checks if the Claude API is configured.
  """
  def configured? do
    get_config(:anthropic_api_key) != nil
  end
end
