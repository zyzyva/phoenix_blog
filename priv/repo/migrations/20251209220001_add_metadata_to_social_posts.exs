defmodule PhoenixBlog.Repo.Migrations.AddMetadataToSocialPosts do
  use Ecto.Migration

  def change do
    alter table(:social_posts) do
      add :metadata, :map, default: %{}
    end
  end
end
