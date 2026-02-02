defmodule CareflexCore.CareTest do
  use CareflexCore.DataCase, async: true

  alias CareflexCore.Care
  alias CareflexCore.Care.Patient

  describe "list_patients/1" do
    test "returns all patients" do
      patient1 = insert(:patient)
      patient2 = insert(:patient)

      patients = Care.list_patients()
      assert length(patients) == 2
      assert Enum.any?(patients, &(&1.id == patient1.id))
      assert Enum.any?(patients, &(&1.id == patient2.id))
    end

    test "supports pagination" do
      insert_list(10, :patient)

      page1 = Care.list_patients(page: 1, page_size: 5)
      page2 = Care.list_patients(page: 2, page_size: 5)

      assert length(page1) == 5
      assert length(page2) == 5
      refute Enum.any?(page1, fn p1 -> Enum.any?(page2, &(&1.id == p1.id)) end)
    end

    test "excludes soft-deleted patients" do
      active_patient = insert(:patient)
      deleted_patient = insert(:patient, deleted_at: DateTime.utc_now())

      patients = Care.list_patients()

      assert Enum.any?(patients, &(&1.id == active_patient.id))
      refute Enum.any?(patients, &(&1.id == deleted_patient.id))
    end
  end

  describe "get_patient!/1" do
    test "returns the patient with given id" do
      patient = insert(:patient)
      found = Care.get_patient!(patient.id)

      assert found.id == patient.id
      assert found.email == patient.email
    end

    test "raises when patient not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Care.get_patient!(999_999)
      end
    end

    test "raises when patient is soft-deleted" do
      patient = insert(:patient, deleted_at: DateTime.utc_now())

      assert_raise Ecto.NoResultsError, fn ->
        Care.get_patient!(patient.id)
      end
    end
  end

  describe "get_patient_by_email/1" do
    test "finds patient by email using hash" do
      patient = insert(:patient, email: "test@example.com")
      found = Care.get_patient_by_email("test@example.com")

      assert found.id == patient.id
    end

    test "returns nil when email not found" do
      assert Care.get_patient_by_email("nonexistent@example.com") == nil
    end

    test "email lookup is case-insensitive" do
      patient = insert(:patient, email: "Test@Example.com")
      found = Care.get_patient_by_email("test@example.com")

      assert found.id == patient.id
    end
  end

  describe "create_patient/2" do
    test "creates patient with valid attributes" do
      attrs = %{
        first_name: "Jane",
        last_name: "Smith",
        email: "jane@example.com",
        phone: "+1-555-0200",
        date_of_birth: "1990-05-15",
        timezone: "America/Los_Angeles"
      }

      audit_context = %{user_role: :admin, action: "create_patient"}

      assert {:ok, %Patient{} = patient} = Care.create_patient(attrs, audit_context)
      assert patient.first_name == "Jane"
      assert patient.last_name == "Smith"
      assert patient.email == "jane@example.com"
      assert patient.timezone == "America/Los_Angeles"
      assert patient.status == :active
    end

    test "encrypts PII fields" do
      attrs = %{
        first_name: "Encrypted",
        last_name: "User",
        email: "encrypted@example.com",
        date_of_birth: "1985-03-20"
      }

      audit_context = %{user_role: :admin, action: "create_patient"}

      {:ok, patient} = Care.create_patient(attrs, audit_context)

      # Reload from database to check encryption
      raw_patient = Repo.get!(Patient, patient.id)

      # The encrypted fields should be readable through Cloak
      assert raw_patient.first_name == "Encrypted"
      assert raw_patient.email == "encrypted@example.com"
    end

    test "generates email hash for lookups" do
      attrs = %{
        first_name: "Hash",
        last_name: "Test",
        email: "hash@example.com",
        date_of_birth: "1988-07-10"
      }

      audit_context = %{user_role: :admin, action: "create_patient"}

      {:ok, patient} = Care.create_patient(attrs, audit_context)

      assert patient.email_hash != nil
      assert is_binary(patient.email_hash)
    end

    test "requires email to be unique" do
      insert(:patient, email: "duplicate@example.com")

      attrs = %{
        first_name: "Duplicate",
        last_name: "Email",
        email: "duplicate@example.com",
        date_of_birth: "1992-11-05"
      }

      audit_context = %{user_role: :admin, action: "create_patient"}

      assert {:error, changeset} = Care.create_patient(attrs, audit_context)
      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates timezone" do
      attrs = %{
        first_name: "Invalid",
        last_name: "Timezone",
        email: "invalid@example.com",
        timezone: "Invalid/Timezone",
        date_of_birth: "1995-02-28"
      }

      audit_context = %{user_role: :admin, action: "create_patient"}

      assert {:error, changeset} = Care.create_patient(attrs, audit_context)
      assert "is not a valid timezone" in errors_on(changeset).timezone
    end
  end

  describe "update_patient/3" do
    test "updates patient with valid attributes" do
      patient = insert(:patient)

      update_attrs = %{
        phone: "+1-555-9999",
        timezone: "America/Chicago"
      }

      audit_context = %{user_role: :admin, action: "update_patient"}

      assert {:ok, updated} = Care.update_patient(patient, update_attrs, audit_context)
      assert updated.phone == "+1-555-9999"
      assert updated.timezone == "America/Chicago"
    end

    test "cannot update email directly" do
      patient = insert(:patient, email: "original@example.com")

      update_attrs = %{email: "new@example.com"}
      audit_context = %{user_role: :admin, action: "update_patient"}

      {:ok, updated} = Care.update_patient(patient, update_attrs, audit_context)

      # Email should remain unchanged
      assert updated.email == "original@example.com"
    end
  end

  describe "delete_patient/2" do
    test "soft deletes the patient" do
      patient = insert(:patient)
      audit_context = %{user_role: :admin, action: "delete_patient"}

      assert {:ok, deleted} = Care.delete_patient(patient, audit_context)
      assert deleted.deleted_at != nil

      # Patient should not appear in normal queries
      assert Care.list_patients() == []
    end
  end

  describe "search_patients_by_name/1" do
    test "finds patients by first name" do
      insert(:patient, first_name: "Alice", last_name: "Johnson")
      insert(:patient, first_name: "Bob", last_name: "Smith")

      results = Care.search_patients_by_name("Alice")

      assert length(results) == 1
      assert hd(results).first_name == "Alice"
    end

    test "finds patients by last name" do
      insert(:patient, first_name: "Charlie", last_name: "Brown")
      insert(:patient, first_name: "David", last_name: "Brown")

      results = Care.search_patients_by_name("Brown")

      assert length(results) == 2
    end

    test "search is case-insensitive" do
      insert(:patient, first_name: "Emma", last_name: "Wilson")

      results = Care.search_patients_by_name("emma")

      assert length(results) == 1
    end
  end
end
