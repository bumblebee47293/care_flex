defmodule CareflexCore.SchedulingPropertyTest do
  use CareflexCore.DataCase, async: true
  use ExUnitProperties

  alias CareflexCore.Scheduling
  alias CareflexCore.Scheduling.Appointment

  describe "appointment conflict detection (property-based)" do
    property "no two appointments for same patient can overlap" do
      check all(
        patient_id <- positive_integer(),
        base_time <- datetime(),
        duration1 <- integer(30..180),
        duration2 <- integer(30..180),
        time_offset <- integer(-120..120),
        max_runs: 50
      ) do
        patient = insert(:patient, id: patient_id)

        # Create first appointment
        appt1_attrs = %{
          patient_id: patient.id,
          scheduled_at: base_time,
          duration_minutes: duration1,
          appointment_type: :consultation,
          status: :scheduled
        }

        {:ok, appt1} = Scheduling.schedule_appointment(appt1_attrs, %{user_role: :admin})

        # Try to create overlapping appointment
        appt2_time = DateTime.add(base_time, time_offset, :minute)
        appt2_attrs = %{
          patient_id: patient.id,
          scheduled_at: appt2_time,
          duration_minutes: duration2,
          appointment_type: :consultation,
          status: :scheduled
        }

        result = Scheduling.schedule_appointment(appt2_attrs, %{user_role: :admin})

        # Calculate if appointments would overlap
        appt1_end = DateTime.add(base_time, duration1, :minute)
        appt2_end = DateTime.add(appt2_time, duration2, :minute)

        overlaps =
          (DateTime.compare(appt2_time, base_time) in [:gt, :eq] and
           DateTime.compare(appt2_time, appt1_end) == :lt) or
          (DateTime.compare(base_time, appt2_time) in [:gt, :eq] and
           DateTime.compare(base_time, appt2_end) == :lt)

        if overlaps do
          # Should fail with conflict error
          assert {:error, changeset} = result
          assert "conflicts with existing appointment" in errors_on(changeset).scheduled_at
        else
          # Should succeed
          assert {:ok, _appt2} = result
        end
      end
    end

    property "rescheduling maintains appointment identity" do
      check all(
        new_time_offset <- integer(1..1000),
        max_runs: 30
      ) do
        patient = insert(:patient)
        original_time = DateTime.utc_now() |> DateTime.add(1, :day)

        {:ok, appt} = Scheduling.schedule_appointment(%{
          patient_id: patient.id,
          scheduled_at: original_time,
          duration_minutes: 60,
          appointment_type: :consultation,
          status: :scheduled
        }, %{user_role: :admin})

        new_time = DateTime.add(original_time, new_time_offset, :minute)

        {:ok, rescheduled} = Scheduling.reschedule_appointment(appt, new_time, %{user_role: :admin})

        # Same appointment ID
        assert rescheduled.id == appt.id
        # Same patient
        assert rescheduled.patient_id == appt.patient_id
        # New time
        assert DateTime.compare(rescheduled.scheduled_at, new_time) == :eq
        # Status should be confirmed
        assert rescheduled.status == :confirmed
      end
    end
  end

  describe "no-show risk calculation (property-based)" do
    property "risk score is always between 0 and 100" do
      check all(
        completed <- integer(0..50),
        no_shows <- integer(0..50),
        cancelled <- integer(0..50),
        max_runs: 50
      ) do
        patient = insert(:patient)

        # Create appointment history
        past_time = DateTime.utc_now() |> DateTime.add(-30, :day)

        # Completed appointments
        for i <- 1..completed do
          insert(:appointment,
            patient_id: patient.id,
            scheduled_at: DateTime.add(past_time, -i, :day),
            status: :completed
          )
        end

        # No-show appointments
        for i <- 1..no_shows do
          insert(:appointment,
            patient_id: patient.id,
            scheduled_at: DateTime.add(past_time, -(i + completed), :day),
            status: :no_show
          )
        end

        # Cancelled appointments
        for i <- 1..cancelled do
          insert(:appointment,
            patient_id: patient.id,
            scheduled_at: DateTime.add(past_time, -(i + completed + no_shows), :day),
            status: :cancelled
          )
        end

        # Create future appointment
        future_time = DateTime.utc_now() |> DateTime.add(2, :day)
        {:ok, appt} = Scheduling.schedule_appointment(%{
          patient_id: patient.id,
          scheduled_at: future_time,
          duration_minutes: 60,
          appointment_type: :consultation,
          status: :scheduled
        }, %{user_role: :admin})

        # Calculate risk
        {:ok, updated} = Scheduling.calculate_no_show_risk(appt)

        # Risk score should be between 0 and 100
        assert updated.no_show_risk_score >= 0
        assert updated.no_show_risk_score <= 100

        # If all no-shows, should be high risk
        if no_shows > 0 and completed == 0 and cancelled == 0 do
          assert updated.no_show_risk_score > 70
        end

        # If all completed, should be low risk
        if completed > 0 and no_shows == 0 do
          assert updated.no_show_risk_score < 30
        end
      end
    end
  end

  # Custom generators
  defp datetime do
    gen all(
      days_offset <- integer(1..365),
      hour <- integer(8..17),
      minute <- member_of([0, 15, 30, 45])
    ) do
      DateTime.utc_now()
      |> DateTime.add(days_offset, :day)
      |> DateTime.truncate(:second)
      |> Map.put(:hour, hour)
      |> Map.put(:minute, minute)
    end
  end
end
