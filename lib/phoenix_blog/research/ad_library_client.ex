defmodule PhoenixBlog.Research.AdLibraryClient do
  @moduledoc """
  Meta Ad Library API client for competitive ad research.

  Searches Facebook and Instagram ads to understand competitor messaging,
  creative approaches, and what's currently running (duration = performance proxy).

  ## Configuration

  Requires Meta Marketing API access:
  - `META_ACCESS_TOKEN` - Long-lived access token with ads_read permission

  Get access at: https://developers.facebook.com/tools/explorer/

  Configure in your app:

      config :phoenix_blog,
        meta_access_token: System.get_env("META_ACCESS_TOKEN")

  ## Key Insight

  Ads that have been running longer are likely performing well.
  Use `ad_delivery_date_min` in results to identify proven creative.

  ## Usage

      # Search competitor ads
      AdLibraryClient.search_ads("competitor brand name")

      # Get ads by page ID
      AdLibraryClient.get_page_ads("123456789")

      # Search by category
      AdLibraryClient.search_ads("fitness app", ad_type: "POLITICAL_AND_ISSUE_ADS")
  """

  require Logger

  @base_url "https://graph.facebook.com/v21.0"
  @timeout 30_000

  @doc """
  Searches the Meta Ad Library for ads matching the query.

  ## Options

  - `:ad_reached_countries` - Countries where ads were shown (default: ["US"])
  - `:ad_type` - Type of ads: "ALL", "POLITICAL_AND_ISSUE_ADS" (default: "ALL")
  - `:ad_active_status` - "ALL", "ACTIVE", "INACTIVE" (default: "ACTIVE")
  - `:limit` - Number of results (default: 25, max: 100)
  - `:media_type` - Filter by media: "ALL", "IMAGE", "VIDEO" (default: "ALL")

  ## Returns

  - `{:ok, %{ads: list, paging: map}}` - List of ads with metadata
  - `{:error, reason}` - If search fails
  """
  def search_ads(query, opts \\ []) do
    if configured?() do
      do_search(query, opts)
    else
      {:error, "Meta access token not configured. Set META_ACCESS_TOKEN."}
    end
  end

  @doc """
  Gets all active ads for a specific Facebook Page.

  More reliable than search when you know the exact competitor page.

  ## Options

  Same as `search_ads/2`

  ## Returns

  - `{:ok, %{ads: list, page_name: string}}` - Ads for the page
  - `{:error, reason}` - If request fails
  """
  def get_page_ads(page_id, opts \\ []) do
    if configured?() do
      do_get_page_ads(page_id, opts)
    else
      {:error, "Meta access token not configured."}
    end
  end

  @doc """
  Gets ad spend and reach estimates for a page's ads.

  Note: Spend data is only available for political/issue ads in most regions.
  """
  def get_page_ad_spend(page_id, opts \\ []) do
    search_ads("", Keyword.merge(opts, search_page_ids: [page_id], fields: spend_fields()))
  end

  @doc """
  Finds long-running ads (likely high performers).

  Ads running for 30+ days are typically profitable.

  ## Options

  - `:min_days` - Minimum days running (default: 30)
  - Other options same as `search_ads/2`
  """
  def find_proven_ads(query, opts \\ []) do
    min_days = Keyword.get(opts, :min_days, 30)
    cutoff_date = Date.utc_today() |> Date.add(-min_days) |> Date.to_iso8601()

    case search_ads(query, Keyword.put(opts, :ad_delivery_date_max, cutoff_date)) do
      {:ok, %{ads: ads, paging: paging}} ->
        proven = Enum.filter(ads, &ad_still_running?/1)

        {:ok,
         %{
           ads: proven,
           paging: paging,
           count: length(proven),
           filter: "running_#{min_days}+_days"
         }}

      error ->
        error
    end
  end

  @doc """
  Analyzes creative patterns across a set of ads.

  Returns insights about:
  - Common messaging themes
  - Visual patterns (video vs image ratio)
  - CTA usage
  """
  def analyze_creative_patterns(ads) when is_list(ads) do
    %{
      total_ads: length(ads),
      media_breakdown: count_media_types(ads),
      avg_days_running: calculate_avg_duration(ads),
      cta_patterns: extract_cta_patterns(ads),
      top_performers: Enum.take(sort_by_duration(ads), 5)
    }
  end

  @doc """
  Checks if the Meta Ad Library API is configured.
  """
  def configured? do
    get_access_token() != nil
  end

  # ============================================================================
  # Private - API Calls
  # ============================================================================

  defp do_search(query, opts) do
    countries = Keyword.get(opts, :ad_reached_countries, ["US"])
    ad_type = Keyword.get(opts, :ad_type, "ALL")
    active_status = Keyword.get(opts, :ad_active_status, "ACTIVE")
    limit = Keyword.get(opts, :limit, 25)
    media_type = Keyword.get(opts, :media_type, "ALL")

    params = %{
      access_token: get_access_token(),
      search_terms: query,
      ad_reached_countries: Enum.join(countries, ","),
      ad_type: ad_type,
      ad_active_status: active_status,
      limit: min(limit, 100),
      media_type: media_type,
      fields: default_fields()
    }

    params =
      opts
      |> Keyword.get(:search_page_ids)
      |> case do
        nil -> params
        ids -> Map.put(params, :search_page_ids, Enum.join(ids, ","))
      end

    url = "#{@base_url}/ads_archive"

    url
    |> Req.get(params: params, receive_timeout: @timeout)
    |> handle_response()
  end

  defp do_get_page_ads(page_id, opts) do
    search_ads("", Keyword.put(opts, :search_page_ids, [page_id]))
  end

  # ============================================================================
  # Private - Response Handling
  # ============================================================================

  defp handle_response({:ok, %{status: 200, body: body}}) do
    ads = Map.get(body, "data", [])
    paging = Map.get(body, "paging", %{})

    parsed_ads = Enum.map(ads, &parse_ad/1)

    {:ok, %{ads: parsed_ads, paging: paging, count: length(parsed_ads)}}
  end

  defp handle_response({:ok, %{status: 400, body: body}}) do
    error_msg = get_in(body, ["error", "message"]) || inspect(body)
    Logger.error("AdLibrary: Bad request - #{error_msg}")
    {:error, "Invalid request: #{error_msg}"}
  end

  defp handle_response({:ok, %{status: 401}}) do
    Logger.error("AdLibrary: Invalid access token")
    {:error, "Invalid or expired access token"}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.error("AdLibrary: Unexpected status #{status}: #{inspect(body)}")
    {:error, "API error (status #{status})"}
  end

  defp handle_response({:error, reason}) do
    Logger.error("AdLibrary: Request failed - #{inspect(reason)}")
    {:error, "Failed to connect to Meta Ad Library"}
  end

  # ============================================================================
  # Private - Parsing
  # ============================================================================

  defp parse_ad(raw) do
    %{
      id: raw["id"],
      page_id: raw["page_id"],
      page_name: raw["page_name"],
      ad_creative_body: raw["ad_creative_bodies"] |> List.first(),
      ad_creative_link_title: raw["ad_creative_link_titles"] |> List.first(),
      ad_creative_link_caption: raw["ad_creative_link_captions"] |> List.first(),
      ad_delivery_start: parse_date(raw["ad_delivery_start_time"]),
      ad_delivery_stop: parse_date(raw["ad_delivery_stop_time"]),
      days_running: calculate_days_running(raw),
      is_active: raw["ad_delivery_stop_time"] == nil,
      languages: raw["languages"],
      publisher_platforms: raw["publisher_platforms"],
      estimated_audience_size: raw["estimated_audience_size"],
      spend: parse_spend(raw["spend"]),
      impressions: parse_impressions(raw["impressions"])
    }
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_spend(nil), do: nil

  defp parse_spend(%{"lower_bound" => lower, "upper_bound" => upper}) do
    %{lower: lower, upper: upper}
  end

  defp parse_spend(_), do: nil

  defp parse_impressions(nil), do: nil

  defp parse_impressions(%{"lower_bound" => lower, "upper_bound" => upper}) do
    %{lower: lower, upper: upper}
  end

  defp parse_impressions(_), do: nil

  defp calculate_days_running(%{"ad_delivery_start_time" => start_time})
       when not is_nil(start_time) do
    case Date.from_iso8601(start_time) do
      {:ok, start_date} -> Date.diff(Date.utc_today(), start_date)
      _ -> nil
    end
  end

  defp calculate_days_running(_), do: nil

  # ============================================================================
  # Private - Analysis Helpers
  # ============================================================================

  defp ad_still_running?(%{is_active: true}), do: true
  defp ad_still_running?(_), do: false

  defp count_media_types(ads) do
    # This would need media_type in the response - simplified for now
    %{total: length(ads)}
  end

  defp calculate_avg_duration(ads) do
    durations =
      ads
      |> Enum.map(& &1.days_running)
      |> Enum.reject(&is_nil/1)

    case durations do
      [] -> 0
      list -> Enum.sum(list) / length(list) |> round()
    end
  end

  defp extract_cta_patterns(ads) do
    ads
    |> Enum.map(& &1.ad_creative_link_title)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> -count end)
    |> Enum.take(10)
    |> Map.new()
  end

  defp sort_by_duration(ads) do
    Enum.sort_by(ads, & &1.days_running, :desc)
  end

  # ============================================================================
  # Private - Config
  # ============================================================================

  defp get_access_token do
    Application.get_env(:phoenix_blog, :meta_access_token)
  end

  defp default_fields do
    [
      "id",
      "page_id",
      "page_name",
      "ad_creative_bodies",
      "ad_creative_link_titles",
      "ad_creative_link_captions",
      "ad_delivery_start_time",
      "ad_delivery_stop_time",
      "languages",
      "publisher_platforms"
    ]
    |> Enum.join(",")
  end

  defp spend_fields do
    default_fields() <> ",spend,impressions,estimated_audience_size"
  end
end
