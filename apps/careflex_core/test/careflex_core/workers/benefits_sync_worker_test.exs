defmodule CareflexCore.Workers.BenefitsSyncWorkerTest do
  use CareflexCore.DataCase, async: true
  use Oban.Testing, repo: CareflexCore.Repo

  alias CareflexCore.Workers.BenefitsSyncWorker

  describe "perform/1 with patient_id" do
    test "syncs benefits for specific patient" do
      patient = insert(:patient)

      assert :ok = perform_job(BenefitsSyncWorker, %{"patient_id" => patient.id})
    end
  end

  describe "perform/1 without patient_id" do
    test "syncs all active patients" do
      insert_list(3, :patient, status: :active)
      insert(:patient, status: :inactive)

      assert {:ok, result} = perform_job(BenefitsSyncWorker, %{})

      # Should process 3 active patients
      assert result.total == 3
    end

    test "excludes soft-deleted patients" do
      insert(:patient, status: :active)
      insert(:patient, status: :active, deleted_at: DateTime.utc_now())

      assert {:ok, result} = perform_job(BenefitsSyncWorker, %{})

      assert result.total == 1
    end
  end
end
