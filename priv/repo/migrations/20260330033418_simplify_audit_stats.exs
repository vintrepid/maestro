defmodule Maestro.Repo.Migrations.SimplifyAuditStats do
  use Ecto.Migration

  def change do
    alter table(:audits) do
      add :total_modules, :integer, default: 0

      remove :total_pages, :integer, default: 0
      remove :avg_score, :integer, default: 0
      remove :total_checks, :integer, default: 0
      remove :total_pass, :integer, default: 0
      remove :total_fail, :integer, default: 0
      remove :rules_checked, :integer, default: 0
      remove :rules_skipped_per_page, :integer, default: 0
    end
  end
end
