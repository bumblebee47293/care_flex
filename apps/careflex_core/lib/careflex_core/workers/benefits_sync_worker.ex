defmodule CareflexCore.Workers.BenefitsSyncWorker do
  @moduledoc """
  Oban worker for synchronizing benefits data with external systems.

  Runs daily via cron to keep benefits data up-to-date.
  Handles API failures gracefully with retries.
  """

  use Oban.Worker,
    queue: :integrations,
    max_attempts: 5

  import Ecto.Query
  alias CareflexCore.{Repo, Benefits}
  alias CareflexCore.Care.Patient

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    case args do
      %{"patient_id" => patient_id} ->
        # Sync specific patient
        sync_patient_benefits(patient_id)

      %{} ->
        # Sync all active patients
        sync_all_patients()
    end
  end

  defp sync_patient_benefits(patient_id) do
    case Benefits.sync_external_benefits(patient_id) do
      {:ok, _results} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp sync_all_patients do
    # Get all active patients
    patient_ids =
      Patient
      |> where([p], p.status == :active)
      |> where([p], is_nil(p.deleted_at))
      |> select([p], p.id)
      |> Repo.all()

    # Sync each patient
    results =
      Enum.map(patient_ids, fn patient_id ->
        sync_patient_benefits(patient_id)
      end)

    successful = Enum.count(results, &(&1 == :ok))
    failed = Enum.count(results, &match?({:error, _}, &1))

    {:ok, %{total: length(results), successful: successful, failed: failed}}
  end
end
