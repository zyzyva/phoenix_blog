defmodule PhoenixBlog.Repo.Migrations.CreateInsights do
  use Ecto.Migration

  def change do
    create table(:insights) do
      add :insight_type, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :evidence_ids, {:array, :integer}, default: []
      add :confidence_score, :decimal, precision: 3, scale: 2
      add :tags, {:array, :string}, default: []
      add :status, :string, default: "draft", null: false
      add :used_count, :integer, default: 0

      add :user_id, references(:authors, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:insights, [:user_id])
    create index(:insights, [:insight_type])
    create index(:insights, [:status])
    create index(:insights, [:confidence_score])
  end
end
