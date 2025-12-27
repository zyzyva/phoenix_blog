defmodule PhoenixBlog.Repo.Migrations.CreateCostTracking do
  use Ecto.Migration

  def change do
    create table(:cost_tracking) do
      add :service, :string, null: false
      add :operation, :string, null: false
      add :input_tokens, :integer
      add :output_tokens, :integer
      add :units, :decimal, precision: 10, scale: 4
      add :cost, :decimal, precision: 10, scale: 6, null: false
      add :request_id, :string
      add :metadata, :map, default: %{}

      add :user_id, references(:authors, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:cost_tracking, [:user_id])
    create index(:cost_tracking, [:service])
    create index(:cost_tracking, [:inserted_at])
    create index(:cost_tracking, [:user_id, :service, :inserted_at])
  end
end
