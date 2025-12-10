defmodule PhoenixBlog.Social.Workers.TokenRefreshWorker do
  @moduledoc """
  Cron worker that refreshes expiring OAuth tokens.
  Runs daily at 3 AM.
  """
  use Oban.Worker, queue: :default

  alias PhoenixBlog.Social
  alias PhoenixBlog.Social.OAuth

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    # Find accounts with tokens expiring within 7 days
    accounts = Social.list_expiring_accounts(7)

    Enum.each(accounts, fn account ->
      refresh_account_token(account)
    end)

    :ok
  end

  defp refresh_account_token(account) do
    if account.refresh_token do
      case OAuth.refresh_token(account.platform, account.refresh_token) do
        {:ok, tokens} ->
          expires_at =
            if tokens.expires_in do
              DateTime.utc_now()
              |> DateTime.add(tokens.expires_in, :second)
              |> DateTime.truncate(:second)
            end

          Social.update_account_tokens(account, %{
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token || account.refresh_token,
            token_expires_at: expires_at,
            status: "active"
          })

          Logger.info("Refreshed token for #{account.platform} account #{account.id}")

        {:error, reason} ->
          Logger.warning(
            "Failed to refresh token for #{account.platform} account #{account.id}: #{reason}"
          )

          # Mark as expired so user knows to reconnect
          Social.update_account_tokens(account, %{status: "expired"})
      end
    else
      Logger.info("No refresh token for #{account.platform} account #{account.id}")
    end
  end
end
