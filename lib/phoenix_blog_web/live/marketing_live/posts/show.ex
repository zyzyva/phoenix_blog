defmodule PhoenixBlogWeb.MarketingLive.Posts.Show do
  @moduledoc """
  View a single post with its status and analytics.
  """
  use PhoenixBlogWeb, :live_view

  alias PhoenixBlog.Social

  @impl true
  def mount(%{"id" => id}, session, socket) do
    user_id = session["user_id"] || 1
    post = Social.get_post!(id)

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:post, post)
      |> assign(:page_title, "Post Details")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <.link navigate={~p"/marketing/posts"} class="text-blue-600 hover:underline text-sm">
          ← Back to Posts
        </.link>
        <h1 class="text-3xl font-bold text-gray-900 mt-2">Post Details</h1>
      </div>

      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <div class="flex justify-between items-start mb-4">
          <span class={"px-3 py-1 rounded-full text-sm #{status_class(@post.status)}"}>
            <%= status_label(@post.status) %>
          </span>
          <span class="text-sm text-gray-500">
            Created <%= format_datetime(@post.inserted_at) %>
          </span>
        </div>

        <div class="prose max-w-none">
          <p class="whitespace-pre-wrap"><%= @post.content_text %></p>
        </div>

        <%= if @post.scheduled_for do %>
          <div class="mt-4 p-3 bg-blue-50 rounded-lg">
            <p class="text-sm text-blue-800">
              Scheduled for <%= format_datetime(@post.scheduled_for) %>
            </p>
          </div>
        <% end %>
      </div>

      <!-- Platform Status -->
      <div class="bg-white rounded-lg shadow p-6">
        <h2 class="text-lg font-semibold mb-4">Platform Status</h2>
        <%= if @post.post_platforms == [] do %>
          <p class="text-gray-500">No platforms selected for this post.</p>
        <% else %>
          <div class="space-y-3">
            <%= for pp <- @post.post_platforms do %>
              <div class="flex items-center justify-between p-3 border rounded-lg">
                <div class="flex items-center gap-3">
                  <span class="text-xl"><%= platform_icon(pp.social_account.platform) %></span>
                  <div>
                    <p class="font-medium"><%= pp.social_account.platform_username %></p>
                    <p class="text-sm text-gray-500"><%= pp.status %></p>
                  </div>
                </div>
                <%= if pp.platform_url do %>
                  <a
                    href={pp.platform_url}
                    target="_blank"
                    class="text-blue-600 hover:underline text-sm"
                  >
                    View Post →
                  </a>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp status_class("draft"), do: "bg-gray-100 text-gray-700"
  defp status_class("scheduled"), do: "bg-blue-100 text-blue-700"
  defp status_class("publishing"), do: "bg-yellow-100 text-yellow-700"
  defp status_class("published"), do: "bg-green-100 text-green-700"
  defp status_class("failed"), do: "bg-red-100 text-red-700"
  defp status_class(_), do: "bg-gray-100 text-gray-700"

  defp status_label("draft"), do: "Draft"
  defp status_label("scheduled"), do: "Scheduled"
  defp status_label("publishing"), do: "Publishing..."
  defp status_label("published"), do: "Published"
  defp status_label("failed"), do: "Failed"
  defp status_label(s), do: s

  defp platform_icon("twitter"), do: "𝕏"
  defp platform_icon("linkedin"), do: "in"
  defp platform_icon("reddit"), do: "📱"
  defp platform_icon(_), do: "🔗"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end
end
