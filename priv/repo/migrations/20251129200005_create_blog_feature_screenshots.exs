defmodule PhoenixBlog.Repo.Migrations.CreateFeatureScreenshots do
  use Ecto.Migration

  def change do
    create table(:feature_screenshots) do
      add :feature_key, :string, null: false
      add :position, :integer, default: 0, null: false
      add :url, :string, null: false
      add :storage_key, :string, null: false
      add :alt_text, :string
      add :caption, :string
      add :step_description, :string

      timestamps(type: :utc_datetime)
    end

    create index(:feature_screenshots, [:feature_key])
    create index(:feature_screenshots, [:feature_key, :position])
  end
end
