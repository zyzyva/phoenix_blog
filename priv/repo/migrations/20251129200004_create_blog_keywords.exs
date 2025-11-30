defmodule PhoenixBlog.Repo.Migrations.CreateBlogKeywords do
  use Ecto.Migration

  def change do
    create table(:blog_keywords) do
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

    create unique_index(:blog_keywords, [:keyword])
    create index(:blog_keywords, [:category])
    create index(:blog_keywords, [:intent])
    create index(:blog_keywords, [:audience])
    create index(:blog_keywords, [:blog_score])
    create index(:blog_keywords, [:monthly_searches])
  end
end
