defmodule PhoenixBlog.Delivery do
  @moduledoc """
  Context for managing content delivery via webhooks.

  Provides webhook management and delivery tracking.
  """

  import Ecto.Query, warn: false
  alias PhoenixBlog.Repo
  alias PhoenixBlog.Delivery.Webhook

  @doc """
  Lists all webhooks for a user.
  """
  def list_webhooks(user_id, opts \\ []) do
    status = Keyword.get(opts, :status)

    Webhook
    |> where([w], w.user_id == ^user_id)
    |> maybe_filter_status(status)
    |> order_by([w], asc: w.name)
    |> Repo.all()
  end

  @doc """
  Lists active webhooks for a user.
  """
  def list_active_webhooks(user_id) do
    list_webhooks(user_id, status: "active")
  end

  @doc """
  Lists webhooks subscribed to a specific event.
  """
  def list_webhooks_for_event(user_id, event) do
    Webhook
    |> where([w], w.user_id == ^user_id)
    |> where([w], w.status == "active")
    |> where([w], ^event in w.events)
    |> Repo.all()
  end

  @doc """
  Gets a single webhook.
  """
  def get_webhook!(id), do: Repo.get!(Webhook, id)

  @doc """
  Gets a webhook by ID, scoped to a user.
  """
  def get_webhook!(user_id, id) do
    Webhook
    |> where([w], w.user_id == ^user_id and w.id == ^id)
    |> Repo.one!()
  end

  @doc """
  Creates a webhook with auto-generated secret.
  """
  def create_webhook(attrs) do
    attrs_with_secret =
      if Map.has_key?(attrs, :secret) or Map.has_key?(attrs, "secret") do
        attrs
      else
        Map.put(attrs, :secret, Webhook.generate_secret())
      end

    %Webhook{}
    |> Webhook.changeset(attrs_with_secret)
    |> Repo.insert()
  end

  @doc """
  Updates a webhook.
  """
  def update_webhook(%Webhook{} = webhook, attrs) do
    webhook
    |> Webhook.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Pauses a webhook.
  """
  def pause_webhook(%Webhook{} = webhook) do
    update_webhook(webhook, %{status: "paused"})
  end

  @doc """
  Activates a webhook.
  """
  def activate_webhook(%Webhook{} = webhook) do
    update_webhook(webhook, %{status: "active"})
  end

  @doc """
  Records a successful webhook delivery.
  """
  def record_success(%Webhook{} = webhook) do
    webhook
    |> Webhook.trigger_changeset(true)
    |> Repo.update()
  end

  @doc """
  Records a failed webhook delivery.
  """
  def record_failure(%Webhook{} = webhook, error_message) do
    webhook
    |> Webhook.trigger_changeset(false, error_message)
    |> Repo.update()
  end

  @doc """
  Regenerates the secret for a webhook.
  """
  def regenerate_secret(%Webhook{} = webhook) do
    update_webhook(webhook, %{secret: Webhook.generate_secret()})
  end

  @doc """
  Deletes a webhook.
  """
  def delete_webhook(%Webhook{} = webhook) do
    Repo.delete(webhook)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking webhook changes.
  """
  def change_webhook(%Webhook{} = webhook, attrs \\ %{}) do
    Webhook.changeset(webhook, attrs)
  end

  @doc """
  Returns counts of webhooks by status for a user.
  """
  def count_by_status(user_id) do
    Webhook
    |> where([w], w.user_id == ^user_id)
    |> group_by([w], w.status)
    |> select([w], {w.status, count(w.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns webhooks that have failed recently.
  """
  def list_failing_webhooks(user_id) do
    Webhook
    |> where([w], w.user_id == ^user_id)
    |> where([w], w.failure_count > 0)
    |> order_by([w], desc: w.failure_count)
    |> Repo.all()
  end

  @doc """
  Signs a payload for webhook delivery.
  """
  def sign_payload(%Webhook{secret: secret}, payload) when is_binary(payload) do
    Webhook.sign_payload(secret, payload)
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: where(query, [w], w.status == ^status)
end
