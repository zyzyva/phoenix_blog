defmodule PhoenixBlog.Repo.Migrations.CreateResearchJobs do
  use Ecto.Migration

  def change do
    create table(:research_jobs) do
      add :job_type, :string, null: false
      add :status, :string, default: "pending", null: false
      add :external_job_id, :string
      add :input_params, :map, default: %{}
      add :results, :map, default: %{}
      add :error_message, :text
      add :cost, :decimal, precision: 10, scale: 6
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      add :user_id, references(:authors, on_delete: :delete_all), null: false
      add :competitor_id, references(:competitors, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:research_jobs, [:user_id])
    create index(:research_jobs, [:competitor_id])
    create index(:research_jobs, [:status])
    create index(:research_jobs, [:job_type])
    create index(:research_jobs, [:external_job_id])
  end
end
