defmodule CareflexCore.SchedulingTest do
  use CareflexCore.DataCase, async: true

  alias CareflexCore.Scheduling
  alias CareflexCore.Scheduling.Appointment

  describe "schedule_appointment/2" do
    test "creates appointment with valid attributes" do
      patient = insert(:patient)

      attrs = %{
        patient_id: patient.id,
        care_service_type: :telehealth,
        scheduled_at: DateTime.utc_now() |> DateTime.add(48, :hour),
        duration_minutes: 30,
        provider_id: "PROV-456"
      }

      audit_context = %{user_role: :agent, action: "schedule_appointment"}

      assert {:ok, %Appointment{} = appointment} = Scheduling.schedule_appointment(attrs, audit_context)
      assert appointment.patient_id == patient.id
      assert appointment.care_service_type == :telehealth
      assert appointment.status == :scheduled
      assert appointment.duration_minutes == 30
    end

    test "detects scheduling conflicts" do
      patient = insert(:patient)
      scheduled_time = DateTime.utc_now() |> DateTime.add(24, :hour)

      # Create first appointment
      insert(:appointment,
        patient_id: patient.id,
        scheduled_at: scheduled_time,
        duration_minutes: 60
      )

      # Try to schedule overlapping appointment
      attrs = %{
        patient_id: patient.id,
        care_service_type: :home_visit,
        scheduled_at: DateTime.add(scheduled_time, 30, :minute),
        duration_minutes: 60
      }

      audit_context = %{user_role: :agent, action: "schedule_appointment"}

      assert {:error, :scheduling_conflict} = Scheduling.schedule_appointment(attrs, audit_context)
    end

    test "allows non-overlapping appointments" do
      patient = insert(:patient)
      first_time = DateTime.utc_now() |> DateTime.add(24, :hour)

      insert(:appointment,
        patient_id: patient.id,
        scheduled_at: first_time,
        duration_minutes: 60
      )

      # Schedule 2 hours later (no overlap)
      second_time = DateTime.add(first_time, 2, :hour)

      attrs = %{
        patient_id: patient.id,
        care_service_type: :home_visit,
        scheduled_at: second_time,
        duration_minutes: 60
      }

      audit_context = %{user_role: :agent, action: "schedule_appointment"}

      assert {:ok, _appointment} = Scheduling.schedule_appointment(attrs, audit_context)
    end

    test "calculates initial no-show risk score" do
      patient = insert(:patient)

      attrs = %{
        patient_id: patient.id,
        care_service_type: :wellness_check,
        scheduled_at: DateTime.utc_now() |> DateTime.add(72, :hour),
        duration_minutes: 45
      }

      audit_context = %{user_role: :agent, action: "schedule_appointment"}

      {:ok, appointment} = Scheduling.schedule_appointment(attrs, audit_context)

      assert appointment.no_show_risk_score != nil
      assert appointment.no_show_risk_score >= 0
      assert appointment.no_show_risk_score <= 100
    end
  end

  describe "reschedule_appointment/3" do
    test "updates appointment time" do
      appointment = insert(:appointment)
      new_time = DateTime.utc_now() |> DateTime.add(96, :hour)

      attrs = %{scheduled_at: new_time}
      audit_context = %{user_role: :agent, action: "reschedule_appointment"}

      assert {:ok, updated} = Scheduling.reschedule_appointment(appointment, attrs, audit_context)
      assert DateTime.compare(updated.scheduled_at, new_time) == :eq
    end

    test "checks for conflicts when rescheduling" do
      patient = insert(:patient)
      existing_time = DateTime.utc_now() |> DateTime.add(48, :hour)

      # Existing appointment
      insert(:appointment,
        patient_id: patient.id,
        scheduled_at: existing_time,
        duration_minutes: 60
      )

      # Appointment to reschedule
      appointment = insert(:appointment, patient_id: patient.id)

      attrs = %{scheduled_at: existing_time}
      audit_context = %{user_role: :agent, action: "reschedule_appointment"}

      assert {:error, changeset} = Scheduling.reschedule_appointment(appointment, attrs, audit_context)
      assert "overlaps with existing appointment" in errors_on(changeset).scheduled_at
    end
  end

  describe "cancel_appointment/3" do
    test "cancels appointment with reason" do
      appointment = insert(:appointment, status: :scheduled)

      attrs = %{cancellation_reason: "Patient illness"}
      audit_context = %{user_role: :patient, action: "cancel_appointment"}

      assert {:ok, cancelled} = Scheduling.cancel_appointment(appointment, attrs, audit_context)
      assert cancelled.status == :cancelled
      assert cancelled.cancellation_reason == "Patient illness"
      assert cancelled.cancelled_at != nil
    end

    test "cannot cancel already cancelled appointment" do
      appointment = insert(:cancelled_appointment)

      attrs = %{cancellation_reason: "Duplicate cancellation"}
      audit_context = %{user_role: :agent, action: "cancel_appointment"}

      assert {:error, changeset} = Scheduling.cancel_appointment(appointment, attrs, audit_context)
      assert "cannot cancel appointment with status" in errors_on(changeset).status
    end
  end

  describe "calculate_no_show_risk/1" do
    test "returns higher risk for patients with no-show history" do
      patient = insert(:patient)

      # Create history of no-shows
      insert_list(3, :appointment,
        patient_id: patient.id,
        status: :no_show,
        scheduled_at: DateTime.utc_now() |> DateTime.add(-7, :day)
      )

      appointment = insert(:appointment, patient_id: patient.id)

      risk_score = Scheduling.calculate_no_show_risk(appointment)

      assert risk_score > 50
    end

    test "returns lower risk for patients with good attendance" do
      patient = insert(:patient)

      # Create history of completed appointments
      insert_list(5, :appointment,
        patient_id: patient.id,
        status: :completed,
        scheduled_at: DateTime.utc_now() |> DateTime.add(-7, :day)
      )

      appointment = insert(:appointment, patient_id: patient.id)

      risk_score = Scheduling.calculate_no_show_risk(appointment)

      assert risk_score < 30
    end
  end

  describe "get_upcoming_appointments/2" do
    test "returns future appointments for patient" do
      patient = insert(:patient)
      future_time = DateTime.utc_now() |> DateTime.add(24, :hour)

      future_appt = insert(:appointment,
        patient_id: patient.id,
        scheduled_at: future_time
      )

      # Past appointment should not be included
      insert(:appointment,
        patient_id: patient.id,
        scheduled_at: DateTime.utc_now() |> DateTime.add(-24, :hour)
      )

      upcoming = Scheduling.get_upcoming_appointments(patient.id, "America/New_York")

      assert length(upcoming) == 1
      assert hd(upcoming).id == future_appt.id
    end

    test "excludes cancelled appointments" do
      patient = insert(:patient)

      insert(:appointment,
        patient_id: patient.id,
        scheduled_at: DateTime.utc_now() |> DateTime.add(24, :hour)
      )

      insert(:cancelled_appointment,
        patient_id: patient.id,
        scheduled_at: DateTime.utc_now() |> DateTime.add(48, :hour)
      )

      upcoming = Scheduling.get_upcoming_appointments(patient.id, "America/New_York")

      assert length(upcoming) == 1
    end
  end

  describe "update_risk_score/2" do
    test "updates appointment risk score" do
      appointment = insert(:appointment, no_show_risk_score: 25)

      assert {:ok, updated} = Scheduling.update_risk_score(appointment, 75)
      assert updated.no_show_risk_score == 75
    end
  end
end
