defmodule Beef.Repo.Migrations.GoogleLogin do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :googleId, :string, null: true, default: nil
      add :googleAccessToken, :string, null: true, default: nil
    end

    create unique_index(:users, [:googleId])
  end
end
