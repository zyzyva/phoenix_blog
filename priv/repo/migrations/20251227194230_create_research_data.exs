defmodule PhoenixBlog.Repo.Migrations.CreateResearchData do
  use Ecto.Migration

  def change do
    create table(:research_data) do
      add :source_type, :string, null: false
      add :content, :text
      add :metrics, :map, default: %{}
      add :sentiment, :string
      add :themes, {:array, :string}, default: []
      add :source_url, :string
      add :source_author, :string
      add :source_date, :utc_datetime
      add :raw_data, :map, default: %{}

      add :user_id, references(:authors, on_delete: :delete_all), null: false
      add :research_job_id, references(:research_jobs, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:research_data, [:user_id])
    create index(:research_data, [:research_job_id])
    create index(:research_data, [:source_type])
    create index(:research_data, [:sentiment])
  end
end
