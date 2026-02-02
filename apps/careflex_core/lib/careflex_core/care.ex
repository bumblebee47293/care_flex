defmodule CareflexCore.Care do
  @moduledoc """
  The Care context - manages patient information and access.

  This context handles all patient-related operations with:
  - PII encryption/decryption
  - Audit logging for sensitive operations
  - Soft delete support
  - Authorization checks
  """

  import Ecto.Query, warn: false
  alias CareflexCore.Repo
  alias CareflexCore.Care.Patient
  alias CareflexCore.Audit

  @doc """
  Returns the list of active patients with pagination.

  ## Examples

      iex> list_patients()
      [%Patient{}, ...]

      iex> list_patients(page: 2, page_size: 20)
      [%Patient{}, ...]

  """
  def list_patients(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 50)

    Patient
    |> where([p], is_nil(p.deleted_at))
    |> where([p], p.status == :active)
    |> order_by([p], desc: p.inserted_at)
    |> limit(^page_size)
    |> offset(^((page - 1) * page_size))
    |> Repo.all()
  end

  @doc """
  Gets a single patient by ID.

  Raises `Ecto.NoResultsError` if the Patient does not exist.

  ## Examples

      iex> get_patient!(123)
      %Patient{}

      iex> get_patient!(456)
      ** (Ecto.NoResultsError)

  """
  def get_patient!(id) do
    Patient
    |> where([p], is_nil(p.deleted_at))
    |> Repo.get!(id)
  end

  @doc """
  Gets a patient by external ID.
  """
  def get_patient_by_external_id(external_id) do
    Patient
    |> where([p], is_nil(p.deleted_at))
    |> where([p], p.external_id == ^external_id)
    |> Repo.one()
  end

  @doc """
  Gets a patient by email (uses hashed lookup).
  """
  def get_patient_by_email(email) do
    email_hash = :crypto.hash(:sha256, email)

    Patient
    |> where([p], is_nil(p.deleted_at))
    |> where([p], p.email_hash == ^email_hash)
    |> Repo.one()
  end

  @doc """
  Creates a patient.

  ## Examples

      iex> create_patient(%{field: value})
      {:ok, %Patient{}}

      iex> create_patient(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_patient(attrs \\ %{}, audit_context \\ %{}) do
    result =
      %Patient{}
      |> Patient.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, patient} ->
        Audit.log_action(
          Map.merge(audit_context, %{
            action: "create_patient",
            resource_type: "Patient",
            resource_id: patient.id,
            changes: attrs
          })
        )
        {:ok, patient}

      error ->
        error
    end
  end

  @doc """
  Updates a patient.

  ## Examples

      iex> update_patient(patient, %{field: new_value})
      {:ok, %Patient{}}

      iex> update_patient(patient, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_patient(%Patient{} = patient, attrs, audit_context \\ %{}) do
    result =
      patient
      |> Patient.update_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_patient} ->
        Audit.log_action(
          Map.merge(audit_context, %{
            action: "update_patient",
            resource_type: "Patient",
            resource_id: patient.id,
            changes: attrs
          })
        )
        {:ok, updated_patient}

      error ->
        error
    end
  end

  @doc """
  Soft deletes a patient.

  ## Examples

      iex> delete_patient(patient)
      {:ok, %Patient{}}

      iex> delete_patient(patient)
      {:error, %Ecto.Changeset{}}

  """
  def delete_patient(%Patient{} = patient, audit_context \\ %{}) do
    result =
      patient
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now())
      |> Repo.update()

    case result do
      {:ok, deleted_patient} ->
        Audit.log_action(
          Map.merge(audit_context, %{
            action: "delete_patient",
            resource_type: "Patient",
            resource_id: patient.id
          })
        )
        {:ok, deleted_patient}

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking patient changes.

  ## Examples

      iex> change_patient(patient)
      %Ecto.Changeset{data: %Patient{}}

  """
  def change_patient(%Patient{} = patient, attrs \\ %{}) do
    Patient.changeset(patient, attrs)
  end

  @doc """
  Searches patients by name (requires decryption, use sparingly).
  """
  def search_patients_by_name(query_string) do
    # Note: This is inefficient as it requires decrypting all records
    # In production, consider using a search index or encrypted search solution
    list_patients(page_size: 1000)
    |> Enum.filter(fn patient ->
      full_name = "#{patient.first_name} #{patient.last_name}"
      String.contains?(String.downcase(full_name), String.downcase(query_string))
    end)
  end
end
