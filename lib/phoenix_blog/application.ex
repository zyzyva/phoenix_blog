defmodule PhoenixBlog.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        PhoenixBlogWeb.Telemetry,
        PhoenixBlog.Repo,
        {DNSCluster, query: Application.get_env(:phoenix_blog, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: PhoenixBlog.PubSub}
      ] ++
        goth_child_spec() ++
        [
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

  # Start Goth for Google Cloud auth if credentials are configured
  defp goth_child_spec do
    creds_path = System.get_env("GOOGLE_APPLICATION_CREDENTIALS")

    if creds_path && File.exists?(creds_path) do
      credentials = creds_path |> File.read!() |> JSON.decode!()

      [
        {Goth,
         name: PhoenixBlog.Goth,
         source:
           {:service_account, credentials,
            scopes: ["https://www.googleapis.com/auth/cloud-platform"]}}
      ]
    else
      []
    end
  end
end
