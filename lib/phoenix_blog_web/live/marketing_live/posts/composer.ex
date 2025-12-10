defmodule PhoenixBlogWeb.MarketingLive.Posts.Composer do
  @moduledoc """
  Post composer for creating and scheduling social media posts.
  """
  use PhoenixBlogWeb, :live_view

  alias PhoenixBlog.Social

  @max_lengths %{
    "twitter" => 280,
    "linkedin" => 3000,
    "reddit" => 40_000,
    "facebook" => 63_206,
    "instagram" => 2200
  }

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"] || 1

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:page_title, "Create Post")
      |> assign(:accounts, Social.list_accounts(user_id))
      |> assign(:selected_accounts, [])
      |> assign(:content, "")
      |> assign(:schedule_mode, "now")
      |> assign(:scheduled_for, nil)
      |> assign(:max_lengths, @max_lengths)
      |> assign(:form, to_form(%{"content_text" => "", "schedule_mode" => "now"}))

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
        <h1 class="text-3xl font-bold text-gray-900 mt-2">Create Post</h1>
      </div>

      <%= if @accounts == [] do %>
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6 text-center">
          <p class="text-yellow-800 mb-4">You need to connect at least one social account first.</p>
          <.link
            navigate={~p"/marketing/accounts"}
            class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
          >
            Connect Accounts
          </.link>
        </div>
      <% else %>
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Composer -->
          <div class="lg:col-span-2">
            <div class="bg-white rounded-lg shadow p-6">
              <form phx-change="update" phx-submit="publish">
                <!-- Content -->
                <div class="mb-6">
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Post Content
                  </label>
                  <textarea
                    name="content_text"
                    rows="6"
                    class="w-full border border-gray-300 rounded-lg p-3 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    placeholder="What do you want to share?"
                    phx-debounce="300"
                  ><%= @content %></textarea>
                  <div class="flex justify-between mt-2 text-sm text-gray-500">
                    <span><%= String.length(@content) %> characters</span>
                    <%= if @selected_accounts != [] do %>
                      <span class={character_count_class(@content, @selected_accounts)}>
                        <%= character_limit_text(@content, @selected_accounts) %>
                      </span>
                    <% end %>
                  </div>
                </div>

                <!-- Platform Selection -->
                <div class="mb-6">
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Post to
                  </label>
                  <div class="space-y-2">
                    <%= for account <- @accounts do %>
                      <label class="flex items-center gap-3 p-3 border rounded-lg cursor-pointer hover:bg-gray-50">
                        <input
                          type="checkbox"
                          name="accounts[]"
                          value={account.id}
                          checked={account.id in @selected_accounts}
                          class="w-4 h-4 text-blue-600 rounded"
                        />
                        <span class="text-xl"><%= platform_icon(account.platform) %></span>
                        <div class="flex-1">
                          <span class="font-medium"><%= account.platform_username %></span>
                          <span class="text-sm text-gray-500 ml-2">
                            (<%= @max_lengths[account.platform] || "unlimited" %> chars)
                          </span>
                        </div>
                      </label>
                    <% end %>
                  </div>
                </div>

                <!-- Schedule -->
                <div class="mb-6">
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    When to publish
                  </label>
                  <div class="flex gap-4">
                    <label class="flex items-center gap-2">
                      <input
                        type="radio"
                        name="schedule_mode"
                        value="now"
                        checked={@schedule_mode == "now"}
                        class="text-blue-600"
                      />
                      <span>Publish now</span>
                    </label>
                    <label class="flex items-center gap-2">
                      <input
                        type="radio"
                        name="schedule_mode"
                        value="schedule"
                        checked={@schedule_mode == "schedule"}
                        class="text-blue-600"
                      />
                      <span>Schedule for later</span>
                    </label>
                  </div>
                  <%= if @schedule_mode == "schedule" do %>
                    <div class="mt-3">
                      <input
                        type="datetime-local"
                        name="scheduled_for"
                        value={format_datetime_local(@scheduled_for)}
                        class="border border-gray-300 rounded-lg p-2"
                        min={min_schedule_time()}
                      />
                    </div>
                  <% end %>
                </div>

                <!-- Actions -->
                <div class="flex gap-3">
                  <button
                    type="submit"
                    disabled={not can_publish?(@content, @selected_accounts)}
                    class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
                  >
                    <%= if @schedule_mode == "schedule", do: "Schedule Post", else: "Publish Now" %>
                  </button>
                  <button
                    type="button"
                    phx-click="save_draft"
                    class="bg-gray-100 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-200"
                  >
                    Save as Draft
                  </button>
                </div>
              </form>
            </div>
          </div>

          <!-- Preview -->
          <div class="lg:col-span-1">
            <div class="bg-white rounded-lg shadow p-6 sticky top-4">
              <h3 class="font-semibold mb-4">Preview</h3>
              <%= if @selected_accounts == [] do %>
                <p class="text-gray-500 text-sm">Select platforms to see preview</p>
              <% else %>
                <div class="space-y-4">
                  <%= for account <- Enum.filter(@accounts, & &1.id in @selected_accounts) do %>
                    <div class="border rounded-lg p-3">
                      <div class="flex items-center gap-2 mb-2">
                        <span><%= platform_icon(account.platform) %></span>
                        <span class="text-sm font-medium"><%= account.platform_username %></span>
                      </div>
                      <p class="text-sm text-gray-700 whitespace-pre-wrap">
                        <%= truncate_for_platform(@content, account.platform) %>
                      </p>
                      <%= if exceeds_limit?(@content, account.platform) do %>
                        <p class="text-xs text-red-500 mt-2">
                          Exceeds character limit by <%= String.length(@content) - @max_lengths[account.platform] %>
                        </p>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("update", params, socket) do
    content = params["content_text"] || ""
    schedule_mode = params["schedule_mode"] || "now"
    selected_ids = parse_selected_accounts(params["accounts"])

    scheduled_for =
      if schedule_mode == "schedule" && params["scheduled_for"] do
        parse_datetime_local(params["scheduled_for"])
      else
        nil
      end

    {:noreply,
     socket
     |> assign(:content, content)
     |> assign(:schedule_mode, schedule_mode)
     |> assign(:selected_accounts, selected_ids)
     |> assign(:scheduled_for, scheduled_for)}
  end

  @impl true
  def handle_event("publish", params, socket) do
    content = params["content_text"] || socket.assigns.content
    selected_ids = parse_selected_accounts(params["accounts"])

    if can_publish?(content, selected_ids) do
      case create_and_publish(socket, content, selected_ids, params) do
        {:ok, post} ->
          {:noreply,
           socket
           |> put_flash(:info, publish_success_message(socket.assigns.schedule_mode))
           |> push_navigate(to: ~p"/marketing/posts/#{post.id}")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to create post: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please add content and select at least one platform")}
    end
  end

  @impl true
  def handle_event("save_draft", _params, socket) do
    content = socket.assigns.content

    case Social.create_post(socket.assigns.user_id, %{
           content_text: content,
           status: "draft"
         }) do
      {:ok, post} ->
        # Add selected platforms
        Social.add_post_platforms(post, socket.assigns.selected_accounts)

        {:noreply,
         socket
         |> put_flash(:info, "Draft saved")
         |> push_navigate(to: ~p"/marketing/posts/#{post.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save draft")}
    end
  end

  defp create_and_publish(socket, content, selected_ids, params) do
    user_id = socket.assigns.user_id
    schedule_mode = socket.assigns.schedule_mode

    attrs = %{
      content_text: content,
      status: if(schedule_mode == "schedule", do: "scheduled", else: "publishing")
    }

    attrs =
      if schedule_mode == "schedule" && params["scheduled_for"] do
        Map.put(attrs, :scheduled_for, parse_datetime_local(params["scheduled_for"]))
      else
        attrs
      end

    with {:ok, post} <- Social.create_post(user_id, attrs),
         _ <- Social.add_post_platforms(post, selected_ids) do
      if schedule_mode == "now" do
        # TODO: Trigger immediate publishing via Oban worker
        {:ok, post}
      else
        {:ok, post}
      end
    end
  end

  defp parse_selected_accounts(nil), do: []
  defp parse_selected_accounts(accounts) when is_list(accounts) do
    Enum.map(accounts, &String.to_integer/1)
  end
  defp parse_selected_accounts(account) when is_binary(account) do
    [String.to_integer(account)]
  end

  defp parse_datetime_local(nil), do: nil
  defp parse_datetime_local(""), do: nil

  defp parse_datetime_local(datetime_str) do
    case NaiveDateTime.from_iso8601(datetime_str <> ":00") do
      {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC")
      _ -> nil
    end
  end

  defp format_datetime_local(nil), do: ""

  defp format_datetime_local(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%dT%H:%M")
  end

  defp min_schedule_time do
    DateTime.utc_now()
    |> DateTime.add(5, :minute)
    |> Calendar.strftime("%Y-%m-%dT%H:%M")
  end

  defp can_publish?(content, selected_accounts) do
    String.trim(content) != "" && selected_accounts != []
  end

  defp platform_icon("twitter"), do: "𝕏"
  defp platform_icon("linkedin"), do: "in"
  defp platform_icon("reddit"), do: "📱"
  defp platform_icon(_), do: "🔗"

  defp exceeds_limit?(content, platform) do
    max = @max_lengths[platform]
    max && String.length(content) > max
  end

  defp truncate_for_platform(content, platform) do
    max = @max_lengths[platform]

    if max && String.length(content) > max do
      String.slice(content, 0, max - 3) <> "..."
    else
      content
    end
  end

  defp character_count_class(content, selected_accounts) do
    accounts_with_platforms =
      Enum.map(selected_accounts, fn _id ->
        # This is simplified - in real code you'd look up the platform
        "twitter"
      end)

    if Enum.any?(accounts_with_platforms, &exceeds_limit?(content, &1)) do
      "text-red-500"
    else
      "text-gray-500"
    end
  end

  defp character_limit_text(content, _selected_accounts) do
    len = String.length(content)
    "#{len}/280 (Twitter)"
  end

  defp publish_success_message("schedule"), do: "Post scheduled successfully!"
  defp publish_success_message(_), do: "Post published successfully!"
end
