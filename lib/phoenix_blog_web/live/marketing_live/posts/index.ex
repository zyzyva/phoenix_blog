defmodule PhoenixBlogWeb.MarketingLive.Posts.Index do
  @moduledoc """
  List and manage social media posts.
  """
  use PhoenixBlogWeb, :live_view

  alias PhoenixBlog.Social

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"] || 1

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:page_title, "Posts")
      |> assign(:filter, "all")
      |> load_posts()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="flex justify-between items-center mb-8">
        <div>
          <.link navigate={~p"/marketing"} class="text-blue-600 hover:underline text-sm">
            ← Back to Dashboard
          </.link>
          <h1 class="text-3xl font-bold text-gray-900 mt-2">Posts</h1>
        </div>
        <.link
          navigate={~p"/marketing/posts/new"}
          class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
        >
          Create Post
        </.link>
      </div>

      <!-- Filters -->
      <div class="bg-white rounded-lg shadow mb-6">
        <div class="flex gap-1 p-2">
          <%= for {label, value} <- [{"All", "all"}, {"Drafts", "draft"}, {"Scheduled", "scheduled"}, {"Published", "published"}, {"Failed", "failed"}] do %>
            <button
              phx-click="filter"
              phx-value-status={value}
              class={"px-4 py-2 rounded-lg text-sm #{if @filter == value, do: "bg-blue-100 text-blue-700", else: "text-gray-600 hover:bg-gray-100"}"}
            >
              <%= label %>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Posts List -->
      <div class="bg-white rounded-lg shadow">
        <%= if @posts == [] do %>
          <div class="p-8 text-center text-gray-500">
            <p>No posts found.</p>
            <.link navigate={~p"/marketing/posts/new"} class="text-blue-600 hover:underline mt-2 inline-block">
              Create your first post →
            </.link>
          </div>
        <% else %>
          <div class="divide-y">
            <%= for post <- @posts do %>
              <.link navigate={~p"/marketing/posts/#{post.id}"} class="block p-4 hover:bg-gray-50">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <div class="flex items-center gap-2 mb-1">
                      <%= if post.ai_generated do %>
                        <span class="text-xs bg-purple-100 text-purple-700 px-2 py-0.5 rounded">
                          AI Generated
                        </span>
                      <% end %>
                      <%= if github_source(post) do %>
                        <span class="text-xs bg-gray-100 text-gray-700 px-2 py-0.5 rounded">
                          <%= github_source(post) %>
                        </span>
                      <% end %>
                    </div>
                    <p class="text-gray-900 line-clamp-2"><%= post.content_text %></p>
                    <div class="flex gap-4 mt-2 text-sm text-gray-500">
                      <span><%= status_badge(post.status) %></span>
                      <span><%= format_date(post.inserted_at) %></span>
                    </div>
                  </div>
                  <%= if post.status == "draft" do %>
                    <div class="flex gap-2 ml-4">
                      <button
                        phx-click="quick_publish"
                        phx-value-id={post.id}
                        class="text-xs bg-green-100 text-green-700 px-3 py-1 rounded hover:bg-green-200"
                      >
                        Publish
                      </button>
                    </div>
                  <% end %>
                </div>
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:filter, status)
     |> load_posts()}
  end

  defp load_posts(socket) do
    user_id = socket.assigns.user_id
    filter = socket.assigns.filter

    opts = if filter == "all", do: [], else: [status: filter]
    posts = Social.list_posts(user_id, opts)

    assign(socket, :posts, posts)
  end

  defp status_badge("draft"), do: "📝 Draft"
  defp status_badge("scheduled"), do: "📅 Scheduled"
  defp status_badge("publishing"), do: "⏳ Publishing"
  defp status_badge("published"), do: "✅ Published"
  defp status_badge("failed"), do: "❌ Failed"
  defp status_badge(s), do: s

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp github_source(post) do
    case post.metadata do
      %{"github_repo" => repo} -> "from #{repo}"
      _ -> nil
    end
  end
end
