defmodule PhoenixBlogWeb.MarketingLive.Accounts do
  @moduledoc """
  Manage connected social media accounts.
  """
  use PhoenixBlogWeb, :live_view

  alias PhoenixBlog.Social
  alias PhoenixBlog.Social.Clients.TwitterClient

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"] || 1

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:page_title, "Connected Accounts")
      |> assign(:platforms, build_platforms())
      |> load_accounts()

    {:ok, socket}
  end

  defp build_platforms do
    [
      %{
        id: "twitter",
        name: "X / Twitter",
        icon: "𝕏",
        description: "Post tweets, threads, and engage with your audience",
        configured: TwitterClient.configured?()
      },
      %{
        id: "linkedin",
        name: "LinkedIn",
        icon: "in",
        description: "Share professional content and company updates",
        configured: Application.get_env(:phoenix_blog, :linkedin_client_id) != nil
      },
      %{
        id: "reddit",
        name: "Reddit",
        icon: "📱",
        description: "Engage with communities and share content",
        configured: Application.get_env(:phoenix_blog, :reddit_client_id) != nil
      }
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <.link navigate={~p"/marketing"} class="text-blue-600 hover:underline text-sm">
          ← Back to Dashboard
        </.link>
        <h1 class="text-3xl font-bold text-gray-900 mt-2">Connected Accounts</h1>
        <p class="mt-2 text-gray-600">Connect your social media accounts to start posting</p>
      </div>

      <!-- Connected Accounts -->
      <%= if @accounts != [] do %>
        <div class="bg-white rounded-lg shadow mb-8">
          <div class="px-6 py-4 border-b">
            <h2 class="text-lg font-semibold">Your Accounts</h2>
          </div>
          <div class="divide-y">
            <%= for account <- @accounts do %>
              <div class="px-6 py-4 flex items-center justify-between">
                <div class="flex items-center gap-4">
                  <span class="text-2xl w-10 text-center">
                    <%= platform_icon(account.platform) %>
                  </span>
                  <div>
                    <p class="font-medium"><%= account.platform_username %></p>
                    <p class="text-sm text-gray-500"><%= platform_name(account.platform) %></p>
                  </div>
                </div>
                <div class="flex items-center gap-4">
                  <%= if account_status(account) == :active do %>
                    <span class="text-sm text-green-600 flex items-center gap-1">
                      <span class="w-2 h-2 bg-green-500 rounded-full"></span>
                      Connected
                    </span>
                  <% else %>
                    <span class="text-sm text-yellow-600 flex items-center gap-1">
                      <span class="w-2 h-2 bg-yellow-500 rounded-full"></span>
                      Token Expiring
                    </span>
                  <% end %>
                  <button
                    phx-click="disconnect"
                    phx-value-id={account.id}
                    data-confirm="Are you sure you want to disconnect this account?"
                    class="text-sm text-red-600 hover:text-red-700"
                  >
                    Disconnect
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Available Platforms -->
      <div class="bg-white rounded-lg shadow">
        <div class="px-6 py-4 border-b">
          <h2 class="text-lg font-semibold">Connect a Platform</h2>
        </div>
        <div class="divide-y">
          <%= for platform <- @platforms do %>
            <div class="px-6 py-4 flex items-center justify-between">
              <div class="flex items-center gap-4">
                <span class="text-2xl w-10 text-center"><%= platform.icon %></span>
                <div>
                  <p class="font-medium"><%= platform.name %></p>
                  <p class="text-sm text-gray-500"><%= platform.description %></p>
                </div>
              </div>
              <div>
                <%= if already_connected?(@accounts, platform.id) do %>
                  <span class="text-sm text-gray-400">Already connected</span>
                <% else %>
                  <%= if platform.configured do %>
                    <.link
                      href={~p"/auth/#{platform.id}/authorize"}
                      class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700"
                    >
                      Connect
                    </.link>
                  <% else %>
                    <span class="text-sm text-gray-400">Not configured</span>
                  <% end %>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Setup Instructions -->
      <div class="mt-8 bg-gray-50 rounded-lg p-6">
        <h3 class="font-semibold mb-2">Need to configure a platform?</h3>
        <p class="text-sm text-gray-600 mb-4">
          Set the following environment variables to enable each platform:
        </p>
        <div class="bg-white rounded p-4 font-mono text-xs overflow-x-auto">
          <p class="text-gray-500"># Twitter/X</p>
          <p>TWITTER_CLIENT_ID=your_client_id</p>
          <p>TWITTER_CLIENT_SECRET=your_secret</p>
          <p>TWITTER_CALLBACK_URL=https://yourapp.com/auth/twitter/callback</p>
          <p class="mt-2 text-gray-500"># LinkedIn</p>
          <p>LINKEDIN_CLIENT_ID=your_client_id</p>
          <p>LINKEDIN_CLIENT_SECRET=your_secret</p>
          <p>LINKEDIN_CALLBACK_URL=https://yourapp.com/auth/linkedin/callback</p>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("disconnect", %{"id" => id}, socket) do
    account = Social.get_account!(id)

    case Social.delete_account(account) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account disconnected")
         |> load_accounts()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to disconnect account")}
    end
  end

  defp load_accounts(socket) do
    accounts = Social.list_accounts(socket.assigns.user_id)
    assign(socket, :accounts, accounts)
  end

  defp platform_icon("twitter"), do: "𝕏"
  defp platform_icon("linkedin"), do: "in"
  defp platform_icon("reddit"), do: "📱"
  defp platform_icon(_), do: "🔗"

  defp platform_name("twitter"), do: "X / Twitter"
  defp platform_name("linkedin"), do: "LinkedIn"
  defp platform_name("reddit"), do: "Reddit"
  defp platform_name(p), do: String.capitalize(p)

  defp already_connected?(accounts, platform_id) do
    Enum.any?(accounts, &(&1.platform == platform_id))
  end

  defp account_status(account) do
    if Social.Account.token_expired?(account), do: :expired, else: :active
  end
end
