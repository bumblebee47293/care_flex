# Database seed data for development and testing

alias CareflexCore.Repo
alias CareflexCore.Care.Patient
alias CareflexCore.Scheduling.Appointment
alias CareflexCore.Benefits.Benefit

require Logger

Logger.info("Seeding database...")

# Create sample patients
patients = [
  %{
    external_id: "PAT-001",
    first_name: "Alice",
    last_name: "Johnson",
    email: "alice.johnson@example.com",
    phone: "+1-555-0101",
    date_of_birth: ~D[1975-03-15],
    timezone: "America/New_York",
    status: :active,
    communication_preferences: %{
      "prefer_sms" => true,
      "prefer_voice" => false,
      "prefer_email" => true
    },
    accessibility_needs: %{
      "wheelchair_accessible" => false,
      "hearing_assistance" => false
    }
  },
  %{
    external_id: "PAT-002",
    first_name: "Bob",
    last_name: "Smith",
    email: "bob.smith@example.com",
    phone: "+1-555-0102",
    date_of_birth: ~D[1982-07-22],
    timezone: "America/Chicago",
    status: :active,
    communication_preferences: %{
      "prefer_sms" => false,
      "prefer_voice" => true,
      "prefer_email" => false
    },
    accessibility_needs: %{
      "wheelchair_accessible" => true,
      "hearing_assistance" => false
    }
  },
  %{
    external_id: "PAT-003",
    first_name: "Carol",
    last_name: "Williams",
    email: "carol.williams@example.com",
    phone: "+1-555-0103",
    date_of_birth: ~D[1990-11-08],
    timezone: "America/Los_Angeles",
    status: :active,
    communication_preferences: %{
      "prefer_sms" => true,
      "prefer_voice" => false,
      "prefer_email" => true
    },
    accessibility_needs: %{
      "wheelchair_accessible" => false,
      "hearing_assistance" => true
    }
  }
]

inserted_patients =
  Enum.map(patients, fn patient_attrs ->
    # Hash email for lookup
    email_hash = :crypto.hash(:sha256, String.downcase(patient_attrs.email)) |> Base.encode16(case: :lower)

    patient_attrs
    |> Map.put(:email_hash, email_hash)
    |> then(&struct(Patient, &1))
    |> Repo.insert!()
  end)

Logger.info("Created #{length(inserted_patients)} patients")

# Create sample appointments
now = DateTime.utc_now()

appointments = [
  %{
    patient_id: Enum.at(inserted_patients, 0).id,
    care_service_type: :home_visit,
    scheduled_at: DateTime.add(now, 24, :hour),
    duration_minutes: 60,
    status: :scheduled,
    provider_id: "PROV-101",
    provider_name: "Dr. Sarah Chen",
    no_show_risk_score: 15
  },
  %{
    patient_id: Enum.at(inserted_patients, 1).id,
    care_service_type: :telehealth,
    scheduled_at: DateTime.add(now, 48, :hour),
    duration_minutes: 30,
    status: :confirmed,
    provider_id: "PROV-102",
    provider_name: "Dr. Michael Rodriguez",
    no_show_risk_score: 25
  },
  %{
    patient_id: Enum.at(inserted_patients, 2).id,
    care_service_type: :wellness_check,
    scheduled_at: DateTime.add(now, 72, :hour),
    duration_minutes: 45,
    status: :scheduled,
    provider_id: "PROV-103",
    provider_name: "Nurse Emily Davis",
    no_show_risk_score: 10
  }
]

inserted_appointments =
  Enum.map(appointments, fn appt_attrs ->
    struct(Appointment, appt_attrs)
    |> Repo.insert!()
  end)

Logger.info("Created #{length(inserted_appointments)} appointments")

# Create sample benefits
today = Date.utc_today()
period_start = Date.beginning_of_month(today)
period_end = Date.end_of_month(today)

benefits = [
  %{
    patient_id: Enum.at(inserted_patients, 0).id,
    benefit_type: :transportation,
    total_allocated: Decimal.new("200.00"),
    used_amount: Decimal.new("50.00"),
    status: :active,
    period_start: period_start,
    period_end: period_end,
    external_plan_id: "PLAN-TRANS-001"
  },
  %{
    patient_id: Enum.at(inserted_patients, 0).id,
    benefit_type: :meals,
    total_allocated: Decimal.new("300.00"),
    used_amount: Decimal.new("120.00"),
    status: :active,
    period_start: period_start,
    period_end: period_end,
    external_plan_id: "PLAN-MEALS-001"
  },
  %{
    patient_id: Enum.at(inserted_patients, 1).id,
    benefit_type: :fitness,
    total_allocated: Decimal.new("150.00"),
    used_amount: Decimal.new("0.00"),
    status: :active,
    period_start: period_start,
    period_end: period_end,
    external_plan_id: "PLAN-FITNESS-002"
  },
  %{
    patient_id: Enum.at(inserted_patients, 2).id,
    benefit_type: :otc_items,
    total_allocated: Decimal.new("100.00"),
    used_amount: Decimal.new("75.00"),
    status: :active,
    period_start: period_start,
    period_end: period_end,
    external_plan_id: "PLAN-OTC-003"
  }
]

inserted_benefits =
  Enum.map(benefits, fn benefit_attrs ->
    struct(Benefit, benefit_attrs)
    |> Repo.insert!()
  end)

Logger.info("Created #{length(inserted_benefits)} benefits")

Logger.info("Database seeding completed successfully!")
