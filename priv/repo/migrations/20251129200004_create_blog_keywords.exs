defmodule PhoenixBlog.Repo.Migrations.CreateKeywords do
  use Ecto.Migration

  def change do
    create table(:keywords) do
      add :keyword, :string, null: false
      add :monthly_searches, :integer, default: 0
      add :competition, :string
      add :competition_index, :integer
      add :three_month_change, :string
      add :yoy_change, :string
      add :top_bid_low, :decimal, precision: 10, scale: 2
      add :top_bid_high, :decimal, precision: 10, scale: 2

      # Categorization
      add :category, :string
      add :intent, :string
      add :is_question, :boolean, default: false
      add :is_branded, :boolean, default: false

      # Audience and blog optimization
      add :audience, :string
      add :blog_score, :integer, default: 0

      # For content planning
      add :suggested_topics, {:array, :string}, default: []
      add :notes, :text

      timestamps()
    end

    create unique_index(:keywords, [:keyword])
    create index(:keywords, [:category])
    create index(:keywords, [:intent])
    create index(:keywords, [:audience])
    create index(:keywords, [:blog_score])
    create index(:keywords, [:monthly_searches])
  end
end
