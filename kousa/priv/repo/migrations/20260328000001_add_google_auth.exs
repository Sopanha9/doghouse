defmodule Beef.Repo.Migrations.AddGoogleAuth do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :googleId, :string
      add :googleAccessToken, :string
    end

    create unique_index(:users, [:googleId])
  end
end
