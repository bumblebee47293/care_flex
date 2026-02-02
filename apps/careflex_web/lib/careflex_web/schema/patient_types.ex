defmodule CareflexWeb.Schema.PatientTypes do
  @moduledoc """
  GraphQL types and operations for patients.
  """

  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  alias CareflexWeb.Resolvers

  @desc "A patient in the healthcare system"
  object :patient do
    field :id, non_null(:id)
    field :external_id, non_null(:string)
    field :first_name, non_null(:string)
    field :last_name, non_null(:string)
    field :email, non_null(:string)
    field :phone, :string
    field :timezone, non_null(:string)
    field :status, non_null(:patient_status)
    field :communication_preferences, :json
    field :accessibility_needs, :json
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)

    # Associations
    field :appointments, list_of(:appointment), resolve: dataloader(CareflexCore)
    field :benefits, list_of(:benefit), resolve: dataloader(CareflexCore)
  end

  @desc "Patient status"
  enum :patient_status do
    value :active
    value :inactive
    value :suspended
  end

  @desc "Input for creating a patient"
  input_object :create_patient_input do
    field :first_name, non_null(:string)
    field :last_name, non_null(:string)
    field :email, non_null(:string)
    field :phone, :string
    field :date_of_birth, :string
    field :timezone, :string
    field :communication_preferences, :json
    field :accessibility_needs, :json
  end

  @desc "Input for updating a patient"
  input_object :update_patient_input do
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :timezone, :string
    field :status, :patient_status
    field :communication_preferences, :json
    field :accessibility_needs, :json
  end

  object :patient_queries do
    @desc "Get all patients (paginated)"
    field :patients, list_of(:patient) do
      arg :page, :integer, default_value: 1
      arg :page_size, :integer, default_value: 50
      resolve &Resolvers.Patient.list_patients/3
    end

    @desc "Get a single patient by ID"
    field :patient, :patient do
      arg :id, non_null(:id)
      resolve &Resolvers.Patient.get_patient/3
    end

    @desc "Search patients by name"
    field :search_patients, list_of(:patient) do
      arg :query, non_null(:string)
      resolve &Resolvers.Patient.search_patients/3
    end
  end

  object :patient_mutations do
    @desc "Create a new patient"
    field :create_patient, :patient do
      arg :input, non_null(:create_patient_input)
      resolve &Resolvers.Patient.create_patient/3
    end

    @desc "Update a patient"
    field :update_patient, :patient do
      arg :id, non_null(:id)
      arg :input, non_null(:update_patient_input)
      resolve &Resolvers.Patient.update_patient/3
    end

    @desc "Delete a patient (soft delete)"
    field :delete_patient, :patient do
      arg :id, non_null(:id)
      resolve &Resolvers.Patient.delete_patient/3
    end
  end
end
