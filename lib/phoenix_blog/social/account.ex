defmodule PhoenixBlog.Social.Account do
  @moduledoc """
  Schema for connected social media accounts.

  Stores OAuth tokens and platform-specific metadata for each connected account.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @platforms ~w(twitter linkedin reddit facebook instagram)
  @status_values ~w(active expired revoked)

  schema "social_accounts" do
    field :platform, :string
    field :platform_user_id, :string
    field :platform_username, :string
    field :access_token, :binary
    field :refresh_token, :binary
    field :token_expires_at, :utc_datetime
    field :scopes, {:array, :string}, default: []
    field :status, :string, default: "active"
    field :metadata, :map, default: %{}

    belongs_to :user, PhoenixBlog.Blog.Author, foreign_key: :user_id
    has_many :post_platforms, PhoenixBlog.Social.PostPlatform, foreign_key: :social_account_id

    timestamps(type: :utc_datetime)
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :platform,
      :platform_user_id,
      :platform_username,
      :access_token,
      :refresh_token,
      :token_expires_at,
      :scopes,
      :status,
      :metadata,
      :user_id
    ])
    |> validate_required([:platform, :platform_user_id, :access_token, :user_id])
    |> validate_inclusion(:platform, @platforms)
    |> validate_inclusion(:status, @status_values)
    |> unique_constraint([:platform, :platform_user_id])
    |> foreign_key_constraint(:user_id)
  end

  def token_changeset(account, attrs) do
    account
    |> cast(attrs, [:access_token, :refresh_token, :token_expires_at, :status])
    |> validate_required([:access_token])
  end

  def platforms, do: @platforms
  def status_values, do: @status_values

  def token_expired?(%__MODULE__{token_expires_at: nil}), do: false

  def token_expired?(%__MODULE__{token_expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end
end
