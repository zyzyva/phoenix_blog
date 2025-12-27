defmodule PhoenixBlog.Research.GraphClient do
  @moduledoc """
  Facebook Graph API client for competitor research.

  Fetches public page data, post comments, and engagement metrics
  to understand customer sentiment and objections.

  ## Configuration

  Requires Facebook Graph API access:
  - `META_ACCESS_TOKEN` - Access token with pages_read_engagement permission

  Configure in your app:

      config :phoenix_blog,
        meta_access_token: System.get_env("META_ACCESS_TOKEN")

  ## Key Use Cases

  1. **Comment Mining** - Find real objections and questions customers have
  2. **Sentiment Analysis** - Understand how people feel about competitors
  3. **Content Ideas** - See what questions people ask repeatedly

  ## Usage

      # Get page info
      GraphClient.get_page("competitor_page_id")

      # Get recent posts
      GraphClient.get_page_posts("page_id", limit: 25)

      # Get comments on a post
      GraphClient.get_post_comments("post_id")

      # Analyze comment sentiment
      GraphClient.analyze_comments("post_id")
  """

  require Logger

  @base_url "https://graph.facebook.com/v21.0"
  @timeout 30_000

  @doc """
  Gets public information about a Facebook Page.

  ## Returns

  - `{:ok, %{id: string, name: string, ...}}` - Page info
  - `{:error, reason}` - If request fails
  """
  def get_page(page_id) do
    if configured?() do
      fields = "id,name,about,category,fan_count,followers_count,website,link"
      make_request("/#{page_id}", fields: fields)
    else
      {:error, "Meta access token not configured."}
    end
  end

  @doc """
  Gets recent posts from a Facebook Page.

  ## Options

  - `:limit` - Number of posts (default: 25)
  - `:since` - Unix timestamp for oldest post
  - `:until` - Unix timestamp for newest post

  ## Returns

  - `{:ok, %{posts: list, paging: map}}` - List of posts
  - `{:error, reason}` - If request fails
  """
  def get_page_posts(page_id, opts \\ []) do
    if configured?() do
      limit = Keyword.get(opts, :limit, 25)

      fields =
        "id,message,created_time,shares,permalink_url," <>
          "attachments{media_type,url,title}"

      params = %{
        fields: fields,
        limit: limit
      }

      params = maybe_add_time_params(params, opts)

      make_request("/#{page_id}/posts", params)
      |> parse_posts_response()
    else
      {:error, "Meta access token not configured."}
    end
  end

  @doc """
  Gets comments on a specific post.

  ## Options

  - `:limit` - Number of comments (default: 100)
  - `:filter` - "toplevel" or "stream" (default: "toplevel")
  - `:order` - "chronological" or "reverse_chronological" (default: "reverse_chronological")

  ## Returns

  - `{:ok, %{comments: list, summary: map}}` - Comments with engagement summary
  - `{:error, reason}` - If request fails
  """
  def get_post_comments(post_id, opts \\ []) do
    if configured?() do
      limit = Keyword.get(opts, :limit, 100)
      filter = Keyword.get(opts, :filter, "toplevel")
      order = Keyword.get(opts, :order, "reverse_chronological")

      fields = "id,message,created_time,like_count,from{id,name}"

      params = %{
        fields: fields,
        limit: limit,
        filter: filter,
        order: order,
        summary: true
      }

      make_request("/#{post_id}/comments", params)
      |> parse_comments_response()
    else
      {:error, "Meta access token not configured."}
    end
  end

  @doc """
  Gets all comments from recent posts on a page.

  Useful for bulk sentiment analysis and objection mining.

  ## Options

  - `:post_limit` - Number of posts to fetch (default: 10)
  - `:comment_limit` - Comments per post (default: 50)
  """
  def get_page_comments(page_id, opts \\ []) do
    post_limit = Keyword.get(opts, :post_limit, 10)
    comment_limit = Keyword.get(opts, :comment_limit, 50)

    with {:ok, %{posts: posts}} <- get_page_posts(page_id, limit: post_limit) do
      comments =
        posts
        |> Enum.flat_map(fn post ->
          case get_post_comments(post.id, limit: comment_limit) do
            {:ok, %{comments: comments}} ->
              Enum.map(comments, &Map.put(&1, :post_id, post.id))

            _ ->
              []
          end
        end)

      {:ok, %{comments: comments, post_count: length(posts), comment_count: length(comments)}}
    end
  end

  @doc """
  Analyzes comments for common themes and sentiment.

  Returns:
  - Question patterns (things people ask)
  - Objection patterns (complaints, concerns)
  - Praise patterns (what people love)
  - Engagement stats
  """
  def analyze_comments(post_id_or_comments, opts \\ [])

  def analyze_comments(post_id, opts) when is_binary(post_id) do
    case get_post_comments(post_id, opts) do
      {:ok, %{comments: comments}} -> analyze_comments(comments, opts)
      error -> error
    end
  end

  def analyze_comments(comments, _opts) when is_list(comments) do
    messages = Enum.map(comments, & &1.message) |> Enum.reject(&is_nil/1)

    {:ok,
     %{
       total_comments: length(comments),
       questions: find_questions(messages),
       objections: find_objections(messages),
       praise: find_praise(messages),
       avg_likes: calculate_avg_likes(comments),
       top_comments: get_top_comments(comments, 5)
     }}
  end

  @doc """
  Searches for pages by name.

  Note: Limited to pages the token has access to or public pages.
  """
  def search_pages(query, opts \\ []) do
    if configured?() do
      limit = Keyword.get(opts, :limit, 25)

      params = %{
        q: query,
        type: "page",
        limit: limit,
        fields: "id,name,category,fan_count,link"
      }

      make_request("/search", params)
      |> parse_search_response()
    else
      {:error, "Meta access token not configured."}
    end
  end

  @doc """
  Checks if the Graph API is configured.
  """
  def configured? do
    get_access_token() != nil
  end

  # ============================================================================
  # Private - API Calls
  # ============================================================================

  defp make_request(endpoint, params) when is_map(params) do
    full_params = Map.put(params, :access_token, get_access_token())

    "#{@base_url}#{endpoint}"
    |> Req.get(params: full_params, receive_timeout: @timeout)
    |> handle_response()
  end

  defp make_request(endpoint, params) when is_list(params) do
    make_request(endpoint, Map.new(params))
  end

  defp maybe_add_time_params(params, opts) do
    params
    |> maybe_put(:since, Keyword.get(opts, :since))
    |> maybe_put(:until, Keyword.get(opts, :until))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # ============================================================================
  # Private - Response Handling
  # ============================================================================

  defp handle_response({:ok, %{status: 200, body: body}}) do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 400, body: body}}) do
    error_msg = get_in(body, ["error", "message"]) || inspect(body)
    Logger.error("GraphAPI: Bad request - #{error_msg}")
    {:error, "Invalid request: #{error_msg}"}
  end

  defp handle_response({:ok, %{status: 401}}) do
    Logger.error("GraphAPI: Invalid access token")
    {:error, "Invalid or expired access token"}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.error("GraphAPI: Unexpected status #{status}: #{inspect(body)}")
    {:error, "API error (status #{status})"}
  end

  defp handle_response({:error, reason}) do
    Logger.error("GraphAPI: Request failed - #{inspect(reason)}")
    {:error, "Failed to connect to Graph API"}
  end

  # ============================================================================
  # Private - Response Parsing
  # ============================================================================

  defp parse_posts_response({:ok, body}) do
    posts =
      body
      |> Map.get("data", [])
      |> Enum.map(&parse_post/1)

    {:ok, %{posts: posts, paging: Map.get(body, "paging", %{})}}
  end

  defp parse_posts_response(error), do: error

  defp parse_post(raw) do
    %{
      id: raw["id"],
      message: raw["message"],
      created_time: raw["created_time"],
      shares: get_in(raw, ["shares", "count"]) || 0,
      permalink_url: raw["permalink_url"],
      media_type: get_in(raw, ["attachments", "data", Access.at(0), "media_type"])
    }
  end

  defp parse_comments_response({:ok, body}) do
    comments =
      body
      |> Map.get("data", [])
      |> Enum.map(&parse_comment/1)

    summary = Map.get(body, "summary", %{})

    {:ok,
     %{
       comments: comments,
       total_count: summary["total_count"] || length(comments),
       paging: Map.get(body, "paging", %{})
     }}
  end

  defp parse_comments_response(error), do: error

  defp parse_comment(raw) do
    %{
      id: raw["id"],
      message: raw["message"],
      created_time: raw["created_time"],
      like_count: raw["like_count"] || 0,
      from_id: get_in(raw, ["from", "id"]),
      from_name: get_in(raw, ["from", "name"])
    }
  end

  defp parse_search_response({:ok, body}) do
    pages =
      body
      |> Map.get("data", [])
      |> Enum.map(fn raw ->
        %{
          id: raw["id"],
          name: raw["name"],
          category: raw["category"],
          fan_count: raw["fan_count"],
          link: raw["link"]
        }
      end)

    {:ok, %{pages: pages}}
  end

  defp parse_search_response(error), do: error

  # ============================================================================
  # Private - Analysis Helpers
  # ============================================================================

  defp find_questions(messages) do
    messages
    |> Enum.filter(&String.contains?(&1, "?"))
    |> Enum.take(20)
  end

  defp find_objections(messages) do
    negative_patterns = [
      "don't",
      "doesn't",
      "won't",
      "can't",
      "not working",
      "doesn't work",
      "terrible",
      "awful",
      "hate",
      "worst",
      "disappointed",
      "frustrat",
      "annoying",
      "problem",
      "issue",
      "bug",
      "broken"
    ]

    messages
    |> Enum.filter(fn msg ->
      lower = String.downcase(msg)
      Enum.any?(negative_patterns, &String.contains?(lower, &1))
    end)
    |> Enum.take(20)
  end

  defp find_praise(messages) do
    positive_patterns = [
      "love",
      "great",
      "amazing",
      "awesome",
      "best",
      "perfect",
      "excellent",
      "fantastic",
      "wonderful",
      "thank you",
      "thanks",
      "helped",
      "works great",
      "recommend"
    ]

    messages
    |> Enum.filter(fn msg ->
      lower = String.downcase(msg)
      Enum.any?(positive_patterns, &String.contains?(lower, &1))
    end)
    |> Enum.take(20)
  end

  defp calculate_avg_likes(comments) do
    likes = Enum.map(comments, & &1.like_count)

    case likes do
      [] -> 0
      list -> Enum.sum(list) / length(list) |> Float.round(1)
    end
  end

  defp get_top_comments(comments, n) do
    comments
    |> Enum.sort_by(& &1.like_count, :desc)
    |> Enum.take(n)
  end

  # ============================================================================
  # Private - Config
  # ============================================================================

  defp get_access_token do
    Application.get_env(:phoenix_blog, :meta_access_token)
  end
end
