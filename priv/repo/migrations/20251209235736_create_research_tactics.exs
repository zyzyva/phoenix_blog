defmodule PhoenixBlog.Repo.Migrations.CreateResearchTactics do
  use Ecto.Migration

  def change do
    create table(:research_tactics) do
      add :title, :string, null: false
      add :description, :text
      add :source_url, :string
      add :source_platform, :string, null: false
      add :source_author, :string
      add :status, :string, default: "saved", null: false

      # Categorization
      add :category, :string
      add :tags, {:array, :string}, default: []
      add :platforms, {:array, :string}, default: []

      # Testing
      add :test_plan, :text
      add :test_results, :text
      add :test_started_at, :utc_datetime
      add :test_completed_at, :utc_datetime

      # Metrics from testing
      add :metrics, :map, default: %{}

      # Engagement from source
      add :source_score, :integer
      add :source_comments, :integer

      # Notes
      add :notes, :text

      timestamps()
    end

    create index(:research_tactics, [:status])
    create index(:research_tactics, [:category])
    create index(:research_tactics, [:source_platform])
  end
end
