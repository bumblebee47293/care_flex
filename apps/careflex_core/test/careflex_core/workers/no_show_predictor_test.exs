defmodule CareflexCore.Workers.NoShowPredictorTest do
  use CareflexCore.DataCase, async: true
  use Oban.Testing, repo: CareflexCore.Repo

  alias CareflexCore.Workers.NoShowPredictor
  alias CareflexCore.Scheduling.Appointment

  describe "perform/1" do
    test "processes upcoming appointments" do
      patient = insert(:patient)

      # Create appointments in next 7 days
      future_time = DateTime.utc_now() |> DateTime.add(3, :day)
      appt1 = insert(:appointment, patient_id: patient.id, scheduled_at: future_time)
      appt2 = insert(:appointment, patient_id: patient.id, scheduled_at: DateTime.add(future_time, 1, :day))

      assert {:ok, result} = perform_job(NoShowPredictor, %{})

      assert result.processed >= 2
      assert result.successful >= 2

      # Verify risk scores were updated
      updated1 = Repo.get!(Appointment, appt1.id)
      updated2 = Repo.get!(Appointment, appt2.id)

      assert updated1.no_show_risk_score != nil
      assert updated2.no_show_risk_score != nil
    end

    test "skips past appointments" do
      patient = insert(:patient)

      # Past appointment
      past_time = DateTime.utc_now() |> DateTime.add(-1, :day)
      insert(:appointment, patient_id: patient.id, scheduled_at: past_time)

      assert {:ok, result} = perform_job(NoShowPredictor, %{})

      # Should not process past appointments
      assert result.processed == 0
    end

    test "skips appointments beyond 7 days" do
      patient = insert(:patient)

      # Far future appointment (8 days)
      far_future = DateTime.utc_now() |> DateTime.add(8, :day)
      insert(:appointment, patient_id: patient.id, scheduled_at: far_future)

      assert {:ok, result} = perform_job(NoShowPredictor, %{})

      assert result.processed == 0
    end

    test "only processes scheduled and confirmed appointments" do
      patient = insert(:patient)
      future_time = DateTime.utc_now() |> DateTime.add(2, :day)

      insert(:appointment, patient_id: patient.id, scheduled_at: future_time, status: :scheduled)
      insert(:cancelled_appointment, patient_id: patient.id, scheduled_at: future_time)
      insert(:appointment, patient_id: patient.id, scheduled_at: future_time, status: :completed)

      assert {:ok, result} = perform_job(NoShowPredictor, %{})

      # Only 1 scheduled appointment should be processed
      assert result.processed == 1
    end
  end
end
