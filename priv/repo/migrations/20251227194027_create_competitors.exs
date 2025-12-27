defmodule PhoenixBlog.Repo.Migrations.CreateCompetitors do
  use Ecto.Migration

  def change do
    create table(:competitors) do
      add :name, :string, null: false
      add :website_urls, {:array, :string}, default: []
      add :social_urls, {:array, :string}, default: []
      add :ad_page_ids, {:array, :string}, default: []
      add :status, :string, default: "active", null: false
      add :metadata, :map, default: %{}

      add :user_id, references(:authors, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:competitors, [:user_id])
    create index(:competitors, [:status])
    create unique_index(:competitors, [:user_id, :name])
  end
end
