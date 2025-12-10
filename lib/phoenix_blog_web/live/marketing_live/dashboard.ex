defmodule PhoenixBlogWeb.MarketingLive.Dashboard do
  @moduledoc """
  Marketing dashboard overview showing quick stats and upcoming posts.
  """
  use PhoenixBlogWeb, :live_view

  alias PhoenixBlog.Social

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"] || 1

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:page_title, "Marketing Dashboard")
      |> load_dashboard_data()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Marketing Dashboard</h1>
        <p class="mt-2 text-gray-600">Manage your social media presence</p>
      </div>

      <!-- Quick Stats -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <.stat_card title="Connected Accounts" value={@account_count} icon="🔗" />
        <.stat_card title="Scheduled Posts" value={@scheduled_count} icon="📅" />
        <.stat_card title="Published This Week" value={@published_count} icon="✅" />
        <.stat_card title="Total Engagements" value={format_number(@total_engagements)} icon="💬" />
      </div>

      <!-- Quick Actions -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold mb-4">Quick Actions</h2>
          <div class="space-y-3">
            <.link
              navigate={~p"/marketing/posts/new"}
              class="block w-full text-center bg-blue-600 text-white py-2 px-4 rounded-lg hover:bg-blue-700"
            >
              Create New Post
            </.link>
            <.link
              navigate={~p"/marketing/accounts"}
              class="block w-full text-center bg-gray-100 text-gray-700 py-2 px-4 rounded-lg hover:bg-gray-200"
            >
              Manage Accounts
            </.link>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold mb-4">Connected Platforms</h2>
          <div class="space-y-2">
            <%= if @accounts == [] do %>
              <p class="text-gray-500 text-sm">No accounts connected yet.</p>
              <.link navigate={~p"/marketing/accounts"} class="text-blue-600 text-sm hover:underline">
                Connect your first account →
              </.link>
            <% else %>
              <%= for account <- @accounts do %>
                <div class="flex items-center justify-between py-2">
                  <div class="flex items-center gap-2">
                    <span class="text-xl"><%= platform_icon(account.platform) %></span>
                    <span class="font-medium"><%= account.platform_username %></span>
                  </div>
                  <span class="text-sm text-green-600">Connected</span>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Upcoming Posts -->
      <div class="bg-white rounded-lg shadow p-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-lg font-semibold">Upcoming Posts</h2>
          <.link navigate={~p"/marketing/calendar"} class="text-blue-600 text-sm hover:underline">
            View Calendar →
          </.link>
        </div>
        <%= if @upcoming_posts == [] do %>
          <p class="text-gray-500 text-sm">No scheduled posts.</p>
        <% else %>
          <div class="space-y-3">
            <%= for post <- @upcoming_posts do %>
              <div class="border-l-4 border-blue-500 pl-4 py-2">
                <p class="text-sm text-gray-900 line-clamp-2"><%= post.content_text %></p>
                <p class="text-xs text-gray-500 mt-1">
                  Scheduled for <%= format_datetime(post.scheduled_for) %>
                </p>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp load_dashboard_data(socket) do
    user_id = socket.assigns.user_id

    accounts = Social.list_accounts(user_id)
    upcoming_posts = Social.list_upcoming_posts(user_id, 5)
    post_counts = Social.count_posts_by_status(user_id)
    analytics = Social.aggregate_analytics(user_id, days: 7)

    socket
    |> assign(:accounts, accounts)
    |> assign(:account_count, length(accounts))
    |> assign(:upcoming_posts, upcoming_posts)
    |> assign(:scheduled_count, Map.get(post_counts, "scheduled", 0))
    |> assign(:published_count, Map.get(post_counts, "published", 0))
    |> assign(:total_engagements, analytics.total_engagements || 0)
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm text-gray-500"><%= @title %></p>
          <p class="text-2xl font-bold text-gray-900"><%= @value %></p>
        </div>
        <span class="text-3xl"><%= @icon %></span>
      </div>
    </div>
    """
  end

  defp platform_icon("twitter"), do: "𝕏"
  defp platform_icon("linkedin"), do: "in"
  defp platform_icon("reddit"), do: "📱"
  defp platform_icon("facebook"), do: "f"
  defp platform_icon("instagram"), do: "📷"
  defp platform_icon(_), do: "🔗"

  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: to_string(num)

  defp format_datetime(nil), do: "Not scheduled"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d at %I:%M %p")
  end
end
