defmodule PhoenixBlogWeb.MarketingLive.Calendar do
  @moduledoc """
  Visual calendar view for scheduled posts.
  """
  use PhoenixBlogWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Content Calendar")
     |> assign(:current_month, Date.utc_today())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <.link navigate={~p"/marketing"} class="text-blue-600 hover:underline text-sm">
          ← Back to Dashboard
        </.link>
        <h1 class="text-3xl font-bold text-gray-900 mt-2">Content Calendar</h1>
      </div>

      <div class="bg-white rounded-lg shadow p-6">
        <p class="text-gray-500 text-center py-8">
          Calendar view coming soon. Use the posts list to see scheduled content.
        </p>
        <div class="text-center">
          <.link
            navigate={~p"/marketing/posts"}
            class="text-blue-600 hover:underline"
          >
            View Posts →
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
