defmodule PhoenixBlog.Research.ApifyClient do
  @moduledoc """
  Apify API client for social media scraping and web data extraction.

  Apify provides pre-built "Actors" that handle the complexity of scraping
  sites like Facebook, Instagram, TikTok, etc. - including anti-bot bypassing,
  proxy rotation, and CAPTCHA solving.

  ## Configuration

  Requires an Apify API token:
  - `APIFY_API_TOKEN` - Your Apify API token

  Get your token at: https://console.apify.com/account/integrations

  Configure in your app:

      config :phoenix_blog,
        apify_api_token: System.get_env("APIFY_API_TOKEN")

  ## Key Actors for Competitor Research

  | Actor ID | Purpose |
  |----------|---------|
  | `apify/facebook-posts-scraper` | Competitor FB posts |
  | `apify/facebook-comments-scraper` | Comments on FB posts |
  | `apify/facebook-reviews-scraper` | FB page reviews |
  | `apify/instagram-scraper` | IG posts and profiles |
  | `apify/instagram-comment-scraper` | Comments on IG posts |
  | `apify/tiktok-scraper` | TikTok videos and profiles |

  ## Usage

      # Run an actor and wait for results
      ApifyClient.run_and_wait("apify/instagram-comment-scraper", %{
        "directUrls" => ["https://instagram.com/p/xyz"]
      })

      # Run async (for long-running scrapes)
      {:ok, run} = ApifyClient.run_actor("apify/facebook-posts-scraper", %{
        "startUrls" => [%{"url" => "https://facebook.com/competitor"}]
      })

      # Check status later
      {:ok, run} = ApifyClient.get_run(run["id"])

      # Get results when done
      {:ok, items} = ApifyClient.get_dataset_items(run["defaultDatasetId"])
  """

  require Logger

  @base_url "https://api.apify.com/v2"
  @timeout 30_000
  @poll_interval 5_000
  @max_wait_time 300_000  # 5 minutes max for sync operations

  # ============================================================================
  # Actor Execution
  # ============================================================================

  @doc """
  Runs an actor and waits for completion (up to 5 minutes).

  For quick scrapes. Returns dataset items directly.

  ## Options

  - `:timeout` - Max wait time in ms (default: 300_000 / 5 min)
  - `:format` - Output format: :json, :csv, :xlsx (default: :json)

  ## Returns

  - `{:ok, items}` - List of scraped items
  - `{:error, reason}` - If run fails or times out
  """
  def run_and_wait(actor_id, input, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @max_wait_time)

    case run_actor(actor_id, input) do
      {:ok, %{"id" => run_id, "defaultDatasetId" => dataset_id}} ->
        wait_for_run(run_id, dataset_id, timeout)

      {:ok, run} ->
        # Handle different response shapes
        run_id = run["id"]
        dataset_id = run["defaultDatasetId"]
        wait_for_run(run_id, dataset_id, timeout)

      error ->
        error
    end
  end

  @doc """
  Runs an actor synchronously and returns results directly.

  Only works for runs under 5 minutes. Simpler but less control.

  ## Returns

  - `{:ok, items}` - List of scraped items
  - `{:error, reason}` - If run fails
  """
  def run_sync(actor_id, input) do
    url = "#{@base_url}/acts/#{actor_id}/run-sync-get-dataset-items"

    make_request(:post, url, input, receive_timeout: @max_wait_time)
  end

  @doc """
  Starts an actor run asynchronously.

  Use this for long-running scrapes. Poll with `get_run/1` to check status.

  ## Returns

  - `{:ok, %{"id" => run_id, "defaultDatasetId" => dataset_id, ...}}`
  - `{:error, reason}`
  """
  def run_actor(actor_id, input) do
    url = "#{@base_url}/acts/#{actor_id}/runs"

    make_request(:post, url, input)
  end

  @doc """
  Gets the status of a run.

  ## Returns

  - `{:ok, %{"status" => "RUNNING" | "SUCCEEDED" | "FAILED", ...}}`
  """
  def get_run(run_id) do
    url = "#{@base_url}/actor-runs/#{run_id}"

    make_request(:get, url)
  end

  @doc """
  Aborts a running actor.
  """
  def abort_run(run_id) do
    url = "#{@base_url}/actor-runs/#{run_id}/abort"

    make_request(:post, url, %{})
  end

  # ============================================================================
  # Dataset Operations
  # ============================================================================

  @doc """
  Gets items from a dataset.

  ## Options

  - `:format` - Output format (default: :json)
  - `:limit` - Max items to return
  - `:offset` - Skip first N items
  - `:clean` - Return only non-empty items (default: true)

  ## Returns

  - `{:ok, [items]}` - List of scraped data
  """
  def get_dataset_items(dataset_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset)
    clean = Keyword.get(opts, :clean, true)

    params =
      %{}
      |> maybe_put("limit", limit)
      |> maybe_put("offset", offset)
      |> maybe_put("clean", clean)

    url = "#{@base_url}/datasets/#{dataset_id}/items"

    make_request(:get, url, nil, params: params)
  end

  # ============================================================================
  # Social Media Convenience Functions
  # ============================================================================

  @doc """
  Scrapes comments from Instagram posts.

  ## Options

  - `:limit` - Max comments per post (default: 100)
  - `:sort` - Sort order: "newest" or "oldest"

  ## Returns

  - `{:ok, [%{text: string, username: string, timestamp: string, ...}]}`
  """
  def scrape_instagram_comments(post_urls, opts \\ []) when is_list(post_urls) do
    limit = Keyword.get(opts, :limit, 100)

    input = %{
      "directUrls" => post_urls,
      "resultsLimit" => limit
    }

    run_and_wait("apify/instagram-comment-scraper", input, opts)
  end

  @doc """
  Scrapes posts from Instagram profiles or hashtags.

  ## Options

  - `:limit` - Max posts to scrape (default: 50)
  - `:type` - "posts", "reels", or "all" (default: "posts")

  ## Returns

  - `{:ok, [%{caption: string, likes: int, comments: int, ...}]}`
  """
  def scrape_instagram_posts(urls, opts \\ []) when is_list(urls) do
    limit = Keyword.get(opts, :limit, 50)

    input = %{
      "directUrls" => urls,
      "resultsLimit" => limit
    }

    run_and_wait("apify/instagram-scraper", input, opts)
  end

  @doc """
  Scrapes comments from Facebook posts.

  ## Options

  - `:limit` - Max comments per post (default: 100)

  ## Returns

  - `{:ok, [%{text: string, author: string, reactions: int, ...}]}`
  """
  def scrape_facebook_comments(post_urls, opts \\ []) when is_list(post_urls) do
    limit = Keyword.get(opts, :limit, 100)

    input = %{
      "startUrls" => Enum.map(post_urls, &%{"url" => &1}),
      "maxComments" => limit
    }

    run_and_wait("apify/facebook-comments-scraper", input, opts)
  end

  @doc """
  Scrapes posts from Facebook pages.

  ## Options

  - `:limit` - Max posts to scrape (default: 50)

  ## Returns

  - `{:ok, [%{text: string, likes: int, shares: int, comments: int, ...}]}`
  """
  def scrape_facebook_posts(page_urls, opts \\ []) when is_list(page_urls) do
    limit = Keyword.get(opts, :limit, 50)

    input = %{
      "startUrls" => Enum.map(page_urls, &%{"url" => &1}),
      "maxPosts" => limit
    }

    run_and_wait("apify/facebook-posts-scraper", input, opts)
  end

  @doc """
  Scrapes reviews from Facebook pages.

  ## Options

  - `:limit` - Max reviews to scrape (default: 100)

  ## Returns

  - `{:ok, [%{text: string, rating: int, author: string, ...}]}`
  """
  def scrape_facebook_reviews(page_urls, opts \\ []) when is_list(page_urls) do
    limit = Keyword.get(opts, :limit, 100)

    input = %{
      "startUrls" => Enum.map(page_urls, &%{"url" => &1}),
      "maxReviews" => limit
    }

    run_and_wait("apify/facebook-reviews-scraper", input, opts)
  end

  @doc """
  Scrapes TikTok videos and profiles.

  ## Options

  - `:limit` - Max videos to scrape (default: 50)

  ## Returns

  - `{:ok, [%{text: string, likes: int, shares: int, ...}]}`
  """
  def scrape_tiktok(urls, opts \\ []) when is_list(urls) do
    limit = Keyword.get(opts, :limit, 50)

    input = %{
      "startUrls" => Enum.map(urls, &%{"url" => &1}),
      "resultsPerPage" => limit
    }

    run_and_wait("apify/tiktok-scraper", input, opts)
  end

  # ============================================================================
  # Account Info
  # ============================================================================

  @doc """
  Gets current account usage and limits.
  """
  def get_user_info do
    url = "#{@base_url}/users/me"

    make_request(:get, url)
  end

  @doc """
  Checks if the Apify API is configured.
  """
  def configured? do
    get_token() != nil
  end

  # ============================================================================
  # Private - Polling
  # ============================================================================

  defp wait_for_run(run_id, dataset_id, timeout) do
    start_time = System.monotonic_time(:millisecond)
    do_wait_for_run(run_id, dataset_id, start_time, timeout)
  end

  defp do_wait_for_run(run_id, dataset_id, start_time, timeout) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed > timeout do
      {:error, "Run timed out after #{div(timeout, 1000)} seconds"}
    else
      case get_run(run_id) do
        {:ok, %{"status" => "SUCCEEDED"}} ->
          get_dataset_items(dataset_id)

        {:ok, %{"status" => "FAILED", "statusMessage" => message}} ->
          {:error, "Run failed: #{message}"}

        {:ok, %{"status" => "ABORTED"}} ->
          {:error, "Run was aborted"}

        {:ok, %{"status" => status}} when status in ["RUNNING", "READY"] ->
          Process.sleep(@poll_interval)
          do_wait_for_run(run_id, dataset_id, start_time, timeout)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # ============================================================================
  # Private - HTTP
  # ============================================================================

  defp make_request(method, url, body \\ nil, opts \\ []) do
    token = get_token()

    unless token do
      {:error, "Apify API token not configured. Set APIFY_API_TOKEN."}
    else
      params = Keyword.get(opts, :params, %{})
      params = Map.put(params, "token", token)
      receive_timeout = Keyword.get(opts, :receive_timeout, @timeout)

      request_opts = [
        params: params,
        receive_timeout: receive_timeout
      ]

      result =
        case method do
          :get ->
            Req.get(url, request_opts)

          :post ->
            Req.post(url, [json: body] ++ request_opts)
        end

      handle_response(result)
    end
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 400, body: body}}) do
    error_msg = extract_error(body)
    Logger.error("Apify: Bad request - #{error_msg}")
    {:error, "Invalid request: #{error_msg}"}
  end

  defp handle_response({:ok, %{status: 401}}) do
    Logger.error("Apify: Invalid API token")
    {:error, "Invalid API token"}
  end

  defp handle_response({:ok, %{status: 402}}) do
    Logger.warning("Apify: Payment required - out of credits")
    {:error, "Out of credits - add funds at console.apify.com"}
  end

  defp handle_response({:ok, %{status: 404}}) do
    {:error, "Actor or resource not found"}
  end

  defp handle_response({:ok, %{status: 429}}) do
    Logger.warning("Apify: Rate limited")
    {:error, "Rate limited - please try again later"}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.error("Apify: Unexpected status #{status}: #{inspect(body)}")
    {:error, "API error (status #{status})"}
  end

  defp handle_response({:error, %Req.TransportError{reason: :timeout}}) do
    Logger.error("Apify: Request timeout")
    {:error, "Request timed out"}
  end

  defp handle_response({:error, reason}) do
    Logger.error("Apify: Request failed - #{inspect(reason)}")
    {:error, "Failed to connect to Apify API"}
  end

  # ============================================================================
  # Private - Helpers
  # ============================================================================

  defp extract_error(%{"error" => %{"message" => msg}}), do: msg
  defp extract_error(%{"error" => error}) when is_binary(error), do: error
  defp extract_error(body), do: inspect(body)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp get_token do
    Application.get_env(:phoenix_blog, :apify_api_token)
  end
end
