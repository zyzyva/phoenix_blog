defmodule PhoenixBlog.Repo.Migrations.CreateWebhooks do
  use Ecto.Migration

  def change do
    create table(:webhooks) do
      add :name, :string, null: false
      add :url, :string, null: false
      add :secret, :binary, null: false
      add :events, {:array, :string}, default: []
      add :status, :string, default: "active", null: false
      add :last_triggered_at, :utc_datetime
      add :last_error, :text
      add :failure_count, :integer, default: 0

      add :user_id, references(:authors, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:webhooks, [:user_id])
    create index(:webhooks, [:status])
  end
end
