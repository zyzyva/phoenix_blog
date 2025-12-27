defmodule PhoenixBlog.Repo.Migrations.CreateContentGenerations do
  use Ecto.Migration

  def change do
    create table(:content_generations) do
      add :content_type, :string, null: false
      add :status, :string, default: "queued", null: false
      add :input_prompt, :text
      add :input_params, :map, default: %{}
      add :output_content, :text
      add :output_urls, {:array, :string}, default: []
      add :provider, :string
      add :model, :string
      add :cost, :decimal, precision: 10, scale: 6
      add :delivery_method, :string
      add :delivered_at, :utc_datetime
      add :error_message, :text

      add :user_id, references(:authors, on_delete: :delete_all), null: false
      add :insight_id, references(:insights, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:content_generations, [:user_id])
    create index(:content_generations, [:insight_id])
    create index(:content_generations, [:content_type])
    create index(:content_generations, [:status])
    create index(:content_generations, [:delivery_method])
  end
end
