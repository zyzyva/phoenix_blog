defmodule PhoenixBlogWeb.MarketingLive.Analytics do
  @moduledoc """
  Unified analytics dashboard for social media performance.
  """
  use PhoenixBlogWeb, :live_view

  alias PhoenixBlog.Social

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"] || 1
    analytics = Social.aggregate_analytics(user_id, days: 30)

    {:ok,
     socket
     |> assign(:page_title, "Analytics")
     |> assign(:user_id, user_id)
     |> assign(:analytics, analytics)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <.link navigate={~p"/marketing"} class="text-blue-600 hover:underline text-sm">
          ← Back to Dashboard
        </.link>
        <h1 class="text-3xl font-bold text-gray-900 mt-2">Analytics</h1>
        <p class="text-gray-600 mt-1">Last 30 days</p>
      </div>

      <!-- Stats Grid -->
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 mb-8">
        <.stat_card title="Impressions" value={@analytics.total_impressions} />
        <.stat_card title="Engagements" value={@analytics.total_engagements} />
        <.stat_card title="Likes" value={@analytics.total_likes} />
        <.stat_card title="Comments" value={@analytics.total_comments} />
        <.stat_card title="Shares" value={@analytics.total_shares} />
        <.stat_card title="Clicks" value={@analytics.total_clicks} />
      </div>

      <div class="bg-white rounded-lg shadow p-6">
        <p class="text-gray-500 text-center py-8">
          Detailed analytics and charts coming soon.
        </p>
      </div>
    </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-4">
      <p class="text-sm text-gray-500"><%= @title %></p>
      <p class="text-2xl font-bold text-gray-900"><%= format_number(@value) %></p>
    </div>
    """
  end

  defp format_number(nil), do: "0"
  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: to_string(num)
end
