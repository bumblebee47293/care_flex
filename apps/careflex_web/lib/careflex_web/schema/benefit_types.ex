defmodule CareflexWeb.Schema.BenefitTypes do
  @moduledoc """
  GraphQL types and operations for benefits.
  """

  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  alias CareflexWeb.Resolvers

  @desc "A patient benefit allocation"
  object :benefit do
    field :id, non_null(:id)
    field :patient_id, non_null(:id)
    field :benefit_type, non_null(:benefit_type)
    field :total_allocated, non_null(:decimal)
    field :used_amount, non_null(:decimal)
    field :remaining_balance, non_null(:decimal) do
      resolve fn benefit, _args, _context ->
        remaining = Decimal.sub(benefit.total_allocated, benefit.used_amount)
        {:ok, remaining}
      end
    end
    field :status, non_null(:benefit_status)
    field :period_start, non_null(:date)
    field :period_end, non_null(:date)
    field :external_plan_id, :string
    field :last_synced_at, :datetime
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)

    # Associations
    field :patient, :patient, resolve: dataloader(CareflexCore)
  end

  @desc "Type of benefit"
  enum :benefit_type do
    value :transportation, description: "Transportation services"
    value :meals, description: "Meal delivery services"
    value :fitness, description: "Fitness and wellness programs"
    value :otc_items, description: "Over-the-counter items"
    value :utilities, description: "Utility assistance"
  end

  @desc "Benefit status"
  enum :benefit_status do
    value :active
    value :expired
    value :depleted
  end

  @desc "Eligibility check result"
  object :eligibility_result do
    field :eligible, non_null(:boolean)
    field :benefit, :benefit
    field :remaining_balance, :decimal
    field :reason, :string
  end

  @desc "Input for creating a benefit"
  input_object :create_benefit_input do
    field :patient_id, non_null(:id)
    field :benefit_type, non_null(:benefit_type)
    field :total_allocated, non_null(:decimal)
    field :period_start, non_null(:date)
    field :period_end, non_null(:date)
    field :external_plan_id, :string
  end

  @desc "Input for recording benefit usage"
  input_object :record_usage_input do
    field :amount, non_null(:decimal)
  end

  object :benefit_queries do
    @desc "Get all benefits for a patient"
    field :patient_benefits, list_of(:benefit) do
      arg :patient_id, non_null(:id)
      resolve &Resolvers.Benefit.get_patient_benefits/3
    end

    @desc "Get active benefits for a patient"
    field :active_benefits, list_of(:benefit) do
      arg :patient_id, non_null(:id)
      resolve &Resolvers.Benefit.get_active_benefits/3
    end

    @desc "Check eligibility for a benefit"
    field :check_eligibility, :eligibility_result do
      arg :patient_id, non_null(:id)
      arg :benefit_type, non_null(:benefit_type)
      arg :amount, non_null(:decimal)
      resolve &Resolvers.Benefit.check_eligibility/3
    end
  end

  object :benefit_mutations do
    @desc "Create a new benefit allocation"
    field :create_benefit, :benefit do
      arg :input, non_null(:create_benefit_input)
      resolve &Resolvers.Benefit.create_benefit/3
    end

    @desc "Record benefit usage"
    field :record_benefit_usage, :benefit do
      arg :benefit_id, non_null(:id)
      arg :input, non_null(:record_usage_input)
      resolve &Resolvers.Benefit.record_usage/3
    end

    @desc "Sync benefits from external system"
    field :sync_benefits, list_of(:benefit) do
      arg :patient_id, non_null(:id)
      resolve &Resolvers.Benefit.sync_benefits/3
    end
  end
end
