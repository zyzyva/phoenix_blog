defmodule PhoenixBlog.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PhoenixBlogWeb.Telemetry,
      PhoenixBlog.Repo,
      {DNSCluster, query: Application.get_env(:phoenix_blog, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PhoenixBlog.PubSub},
      # Start a worker by calling: PhoenixBlog.Worker.start_link(arg)
      # {PhoenixBlog.Worker, arg},
      # Start to serve requests, typically the last entry
      PhoenixBlogWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhoenixBlog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhoenixBlogWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
