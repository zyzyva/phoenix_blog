defmodule PhoenixBlogWeb.MarketingLive.Research do
  @moduledoc """
  LiveView for marketing research - discovering and testing tactics.
  """

  use PhoenixBlogWeb, :live_view

  alias PhoenixBlog.Research

  @impl true
  def mount(_params, _session, socket) do
    tactics = Research.list_tactics(limit: 50)
    stats = Research.count_by_status()

    socket =
      socket
      |> assign(:page_title, "Marketing Research")
      |> assign(:tactics, tactics)
      |> assign(:stats, stats)
      |> assign(:reddit_posts, [])
      |> assign(:loading_reddit, false)
      |> assign(:selected_subreddit, nil)
      |> assign(:filter_status, nil)
      |> assign(:show_tactic_form, false)
      |> assign(:editing_tactic, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    status = params["status"]
    tactics = Research.list_tactics(status: status)

    {:noreply, assign(socket, tactics: tactics, filter_status: status)}
  end

  @impl true
  def handle_event("fetch_reddit", %{"subreddit" => subreddit}, socket) do
    socket = assign(socket, loading_reddit: true, selected_subreddit: subreddit)
    send(self(), {:fetch_reddit, subreddit})
    {:noreply, socket}
  end

  @impl true
  def handle_event("fetch_all_insights", _, socket) do
    socket = assign(socket, loading_reddit: true, selected_subreddit: "all")
    send(self(), :fetch_all_insights)
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_tactic", %{"post_index" => index_str}, socket) do
    index = String.to_integer(index_str)
    post = Enum.at(socket.assigns.reddit_posts, index)

    case Research.create_tactic_from_reddit(post) do
      {:ok, tactic} ->
        tactics = [tactic | socket.assigns.tactics]
        stats = Research.count_by_status()

        socket =
          socket
          |> assign(:tactics, tactics)
          |> assign(:stats, stats)
          |> put_flash(:info, "Tactic saved!")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save tactic")}
    end
  end

  @impl true
  def handle_event("start_test", %{"id" => id, "test_plan" => test_plan}, socket) do
    tactic = Research.get_tactic!(id)

    case Research.start_testing(tactic, test_plan) do
      {:ok, updated} ->
        tactics = update_tactic_in_list(socket.assigns.tactics, updated)
        stats = Research.count_by_status()

        socket =
          socket
          |> assign(:tactics, tactics)
          |> assign(:stats, stats)
          |> put_flash(:info, "Testing started!")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start test")}
    end
  end

  @impl true
  def handle_event("complete_test", %{"id" => id, "status" => status, "results" => results}, socket) do
    tactic = Research.get_tactic!(id)

    case Research.complete_test(tactic, status, results) do
      {:ok, updated} ->
        tactics = update_tactic_in_list(socket.assigns.tactics, updated)
        stats = Research.count_by_status()

        socket =
          socket
          |> assign(:tactics, tactics)
          |> assign(:stats, stats)
          |> put_flash(:info, "Test completed!")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to complete test")}
    end
  end

  @impl true
  def handle_event("archive", %{"id" => id}, socket) do
    tactic = Research.get_tactic!(id)

    case Research.archive_tactic(tactic) do
      {:ok, updated} ->
        tactics = update_tactic_in_list(socket.assigns.tactics, updated)
        stats = Research.count_by_status()

        {:noreply, assign(socket, tactics: tactics, stats: stats)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to archive")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    tactic = Research.get_tactic!(id)

    case Research.delete_tactic(tactic) do
      {:ok, _} ->
        tactics = Enum.reject(socket.assigns.tactics, &(&1.id == tactic.id))
        stats = Research.count_by_status()

        {:noreply, assign(socket, tactics: tactics, stats: stats)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete")}
    end
  end

  @impl true
  def handle_info({:fetch_reddit, subreddit}, socket) do
    case Research.fetch_subreddit_top(subreddit, time: "week", limit: 25) do
      {:ok, posts} ->
        socket =
          socket
          |> assign(:reddit_posts, posts)
          |> assign(:loading_reddit, false)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:loading_reddit, false)
          |> put_flash(:error, "Failed to fetch: #{reason}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:fetch_all_insights, socket) do
    case Research.fetch_reddit_insights(time: "week", limit: 10) do
      {:ok, posts} ->
        socket =
          socket
          |> assign(:reddit_posts, posts)
          |> assign(:loading_reddit, false)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:loading_reddit, false)
          |> put_flash(:error, "Failed to fetch: #{reason}")

        {:noreply, socket}
    end
  end

  defp update_tactic_in_list(tactics, updated) do
    Enum.map(tactics, fn t ->
      if t.id == updated.id, do: updated, else: t
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold mb-6">Marketing Research</h1>

      <!-- Stats -->
      <div class="grid grid-cols-2 md:grid-cols-5 gap-4 mb-8">
        <div class="bg-white p-4 rounded-lg shadow">
          <div class="text-2xl font-bold"><%= @stats["saved"] || 0 %></div>
          <div class="text-gray-600 text-sm">Saved</div>
        </div>
        <div class="bg-yellow-50 p-4 rounded-lg shadow">
          <div class="text-2xl font-bold text-yellow-700"><%= @stats["testing"] || 0 %></div>
          <div class="text-gray-600 text-sm">Testing</div>
        </div>
        <div class="bg-green-50 p-4 rounded-lg shadow">
          <div class="text-2xl font-bold text-green-700"><%= @stats["validated"] || 0 %></div>
          <div class="text-gray-600 text-sm">Validated</div>
        </div>
        <div class="bg-red-50 p-4 rounded-lg shadow">
          <div class="text-2xl font-bold text-red-700"><%= @stats["debunked"] || 0 %></div>
          <div class="text-gray-600 text-sm">Debunked</div>
        </div>
        <div class="bg-gray-50 p-4 rounded-lg shadow">
          <div class="text-2xl font-bold text-gray-500"><%= @stats["archived"] || 0 %></div>
          <div class="text-gray-600 text-sm">Archived</div>
        </div>
      </div>

      <div class="grid md:grid-cols-2 gap-8">
        <!-- Reddit Discovery -->
        <div>
          <h2 class="text-xl font-semibold mb-4">Discover from Reddit</h2>

          <div class="flex flex-wrap gap-2 mb-4">
            <button
              phx-click="fetch_all_insights"
              class="px-3 py-1 bg-orange-500 text-white rounded hover:bg-orange-600"
              disabled={@loading_reddit}
            >
              All Subreddits
            </button>
            <%= for sub <- Research.monitored_subreddits() do %>
              <button
                phx-click="fetch_reddit"
                phx-value-subreddit={sub}
                class={"px-3 py-1 rounded #{if @selected_subreddit == sub, do: "bg-orange-500 text-white", else: "bg-gray-200 hover:bg-gray-300"}"}
                disabled={@loading_reddit}
              >
                r/<%= sub %>
              </button>
            <% end %>
          </div>

          <%= if @loading_reddit do %>
            <div class="text-center py-8 text-gray-500">Loading...</div>
          <% else %>
            <div class="space-y-3 max-h-[600px] overflow-y-auto">
              <%= for {post, index} <- Enum.with_index(@reddit_posts) do %>
                <div class="bg-white p-4 rounded-lg shadow">
                  <div class="flex justify-between items-start">
                    <div class="flex-1">
                      <a href={post.permalink} target="_blank" class="font-medium hover:text-blue-600">
                        <%= post.title %>
                      </a>
                      <div class="text-sm text-gray-500 mt-1">
                        <%= if post[:subreddit] do %>r/<%= post.subreddit %> · <% end %>
                        <%= post.score %> points · <%= post.num_comments %> comments
                      </div>
                    </div>
                    <button
                      phx-click="save_tactic"
                      phx-value-post_index={index}
                      class="ml-2 px-3 py-1 bg-blue-500 text-white text-sm rounded hover:bg-blue-600"
                    >
                      Save
                    </button>
                  </div>
                </div>
              <% end %>

              <%= if @reddit_posts == [] and @selected_subreddit do %>
                <div class="text-center py-8 text-gray-500">No posts found</div>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Saved Tactics -->
        <div>
          <h2 class="text-xl font-semibold mb-4">Saved Tactics</h2>

          <!-- Filter tabs -->
          <div class="flex gap-2 mb-4">
            <.link
              patch={~p"/marketing/research"}
              class={"px-3 py-1 rounded #{if @filter_status == nil, do: "bg-gray-800 text-white", else: "bg-gray-200 hover:bg-gray-300"}"}
            >
              All
            </.link>
            <.link
              patch={~p"/marketing/research?status=saved"}
              class={"px-3 py-1 rounded #{if @filter_status == "saved", do: "bg-gray-800 text-white", else: "bg-gray-200 hover:bg-gray-300"}"}
            >
              Saved
            </.link>
            <.link
              patch={~p"/marketing/research?status=testing"}
              class={"px-3 py-1 rounded #{if @filter_status == "testing", do: "bg-yellow-500 text-white", else: "bg-gray-200 hover:bg-gray-300"}"}
            >
              Testing
            </.link>
            <.link
              patch={~p"/marketing/research?status=validated"}
              class={"px-3 py-1 rounded #{if @filter_status == "validated", do: "bg-green-500 text-white", else: "bg-gray-200 hover:bg-gray-300"}"}
            >
              Validated
            </.link>
            <.link
              patch={~p"/marketing/research?status=debunked"}
              class={"px-3 py-1 rounded #{if @filter_status == "debunked", do: "bg-red-500 text-white", else: "bg-gray-200 hover:bg-gray-300"}"}
            >
              Debunked
            </.link>
          </div>

          <div class="space-y-3 max-h-[600px] overflow-y-auto">
            <%= for tactic <- @tactics do %>
              <div class={"bg-white p-4 rounded-lg shadow #{status_border(tactic.status)}"}>
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <div class="flex items-center gap-2">
                      <span class={"px-2 py-0.5 text-xs rounded #{status_badge(tactic.status)}"}><%= tactic.status %></span>
                      <%= if tactic.category do %>
                        <span class="px-2 py-0.5 text-xs bg-gray-100 rounded"><%= tactic.category %></span>
                      <% end %>
                    </div>
                    <div class="font-medium mt-1"><%= tactic.title %></div>
                    <%= if tactic.source_url do %>
                      <a href={tactic.source_url} target="_blank" class="text-sm text-blue-500 hover:underline">
                        <%= tactic.source_platform %>
                      </a>
                    <% end %>
                    <%= if tactic.test_results do %>
                      <div class="mt-2 text-sm text-gray-600 bg-gray-50 p-2 rounded">
                        <strong>Results:</strong> <%= tactic.test_results %>
                      </div>
                    <% end %>
                  </div>
                  <div class="flex gap-1">
                    <%= if tactic.status == "saved" do %>
                      <button
                        phx-click="archive"
                        phx-value-id={tactic.id}
                        class="px-2 py-1 text-xs bg-gray-200 rounded hover:bg-gray-300"
                      >
                        Archive
                      </button>
                    <% end %>
                    <button
                      phx-click="delete"
                      phx-value-id={tactic.id}
                      data-confirm="Delete this tactic?"
                      class="px-2 py-1 text-xs bg-red-100 text-red-700 rounded hover:bg-red-200"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if @tactics == [] do %>
              <div class="text-center py-8 text-gray-500">
                No tactics found. Discover some from Reddit!
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp status_badge("saved"), do: "bg-gray-100 text-gray-700"
  defp status_badge("testing"), do: "bg-yellow-100 text-yellow-700"
  defp status_badge("validated"), do: "bg-green-100 text-green-700"
  defp status_badge("debunked"), do: "bg-red-100 text-red-700"
  defp status_badge("archived"), do: "bg-gray-100 text-gray-500"
  defp status_badge(_), do: "bg-gray-100"

  defp status_border("testing"), do: "border-l-4 border-yellow-400"
  defp status_border("validated"), do: "border-l-4 border-green-400"
  defp status_border("debunked"), do: "border-l-4 border-red-400"
  defp status_border(_), do: ""
end
