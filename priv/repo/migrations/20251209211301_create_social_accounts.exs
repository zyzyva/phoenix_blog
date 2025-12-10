defmodule PhoenixBlog.Repo.Migrations.CreateSocialAccounts do
  use Ecto.Migration

  def change do
    create table(:social_accounts) do
      add :platform, :string, null: false
      add :platform_user_id, :string, null: false
      add :platform_username, :string
      add :access_token, :binary, null: false
      add :refresh_token, :binary
      add :token_expires_at, :utc_datetime
      add :scopes, {:array, :string}, default: []
      add :status, :string, default: "active", null: false
      add :metadata, :map, default: %{}

      add :user_id, references(:authors, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:social_accounts, [:user_id])
    create index(:social_accounts, [:platform])
    create index(:social_accounts, [:status])
    create unique_index(:social_accounts, [:platform, :platform_user_id])
  end
end
