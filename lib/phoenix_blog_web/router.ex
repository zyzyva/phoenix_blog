defmodule PhoenixBlogWeb.Router do
  use PhoenixBlogWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhoenixBlogWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :github_webhook do
    plug :accepts, ["json"]
    plug PhoenixBlogWeb.Plugs.GitHubWebhookPlug
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug PhoenixBlogWeb.Plugs.ApiAuthPlug
  end

  scope "/", PhoenixBlogWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # OAuth callbacks for social media platforms
  scope "/auth", PhoenixBlogWeb do
    pipe_through :browser

    get "/:platform/authorize", OAuthController, :authorize
    get "/:platform/callback", OAuthController, :callback
  end

  # Marketing dashboard (requires authentication)
  scope "/marketing", PhoenixBlogWeb do
    pipe_through :browser

    live "/", MarketingLive.Dashboard, :index
    live "/accounts", MarketingLive.Accounts, :index
    live "/posts", MarketingLive.Posts.Index, :index
    live "/posts/new", MarketingLive.Posts.Composer, :new
    live "/posts/:id", MarketingLive.Posts.Show, :show
    live "/posts/:id/edit", MarketingLive.Posts.Composer, :edit
    live "/calendar", MarketingLive.Calendar, :index
    live "/analytics", MarketingLive.Analytics, :index
    live "/research", MarketingLive.Research, :index
  end

  # GitHub webhook endpoint
  scope "/api/github", PhoenixBlogWeb do
    pipe_through :github_webhook

    post "/webhook", GitHubWebhookController, :handle
  end

  # Marketing API endpoint (for GitHub Action)
  scope "/api/marketing", PhoenixBlogWeb do
    pipe_through :api_auth

    post "/generate", MarketingApiController, :generate
  end
end
