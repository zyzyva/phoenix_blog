defmodule PhoenixBlog.Delivery.Webhook do
  @moduledoc """
  Schema for webhook configurations.

  Stores user-defined webhooks for receiving generated content
  with HMAC-SHA256 signing for security.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @status_values ~w(active paused disabled)
  @event_types ~w(generation.completed generation.failed insight.created research.completed)

  schema "webhooks" do
    field :name, :string
    field :url, :string
    field :secret, :binary
    field :events, {:array, :string}, default: []
    field :status, :string, default: "active"
    field :last_triggered_at, :utc_datetime
    field :last_error, :string
    field :failure_count, :integer, default: 0

    belongs_to :user, PhoenixBlog.Blog.Author, foreign_key: :user_id

    timestamps(type: :utc_datetime)
  end

  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [:name, :url, :secret, :events, :status, :user_id])
    |> validate_required([:name, :url, :secret, :user_id])
    |> validate_inclusion(:status, @status_values)
    |> validate_events()
    |> validate_url()
    |> foreign_key_constraint(:user_id)
  end

  def trigger_changeset(webhook, success \\ true, error \\ nil)

  def trigger_changeset(webhook, true, _error) do
    webhook
    |> change(%{
      last_triggered_at: DateTime.utc_now() |> DateTime.truncate(:second),
      failure_count: 0,
      last_error: nil
    })
  end

  def trigger_changeset(webhook, false, error) do
    new_count = webhook.failure_count + 1
    status = if new_count >= 5, do: "disabled", else: webhook.status

    webhook
    |> change(%{
      last_triggered_at: DateTime.utc_now() |> DateTime.truncate(:second),
      failure_count: new_count,
      last_error: error,
      status: status
    })
  end

  def status_values, do: @status_values
  def event_types, do: @event_types

  def active?(%__MODULE__{status: "active"}), do: true
  def active?(_), do: false

  def subscribes_to?(%__MODULE__{events: events}, event) do
    event in events
  end

  def generate_secret do
    :crypto.strong_rand_bytes(32)
  end

  def sign_payload(secret, payload) when is_binary(payload) do
    :crypto.mac(:hmac, :sha256, secret, payload)
    |> Base.encode16(case: :lower)
  end

  defp validate_events(changeset) do
    validate_change(changeset, :events, fn _, events ->
      invalid = Enum.reject(events, &(&1 in @event_types))

      if invalid == [] do
        []
      else
        [{:events, "contains invalid events: #{Enum.join(invalid, ", ")}"}]
      end
    end)
  end

  defp validate_url(changeset) do
    validate_change(changeset, :url, fn _, url ->
      uri = URI.parse(url)

      if uri.scheme in ["http", "https"] and uri.host != nil do
        []
      else
        [{:url, "must be a valid HTTP/HTTPS URL"}]
      end
    end)
  end
end
