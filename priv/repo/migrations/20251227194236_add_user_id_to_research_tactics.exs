defmodule PhoenixBlog.Repo.Migrations.AddUserIdToResearchTactics do
  use Ecto.Migration

  def change do
    alter table(:research_tactics) do
      add :user_id, references(:authors, on_delete: :delete_all)
    end

    create index(:research_tactics, [:user_id])
  end
end
