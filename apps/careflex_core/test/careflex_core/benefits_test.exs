defmodule CareflexCore.BenefitsTest do
  use CareflexCore.DataCase, async: true

  alias CareflexCore.Benefits
  alias CareflexCore.Benefits.Benefit

  describe "check_eligibility/3" do
    test "returns benefit when eligible with sufficient balance" do
      patient = insert(:patient)
      benefit = insert(:benefit,
        patient_id: patient.id,
        benefit_type: :transportation,
        total_allocated: Decimal.new("200.00"),
        used_amount: Decimal.new("50.00")
      )

      assert {:ok, returned_benefit} = Benefits.check_eligibility(
        patient.id,
        :transportation,
        Decimal.new("100.00")
      )

      assert returned_benefit.id == benefit.id
    end

    test "returns error when insufficient balance" do
      patient = insert(:patient)
      insert(:benefit,
        patient_id: patient.id,
        benefit_type: :meals,
        total_allocated: Decimal.new("100.00"),
        used_amount: Decimal.new("90.00")
      )

      assert {:error, :insufficient_balance} = Benefits.check_eligibility(
        patient.id,
        :meals,
        Decimal.new("50.00")
      )
    end

    test "returns error when no active benefit exists" do
      patient = insert(:patient)

      assert {:error, :no_active_benefit} = Benefits.check_eligibility(
        patient.id,
        :fitness,
        Decimal.new("25.00")
      )
    end

    test "returns error when benefit is expired" do
      patient = insert(:patient)
      insert(:expired_benefit, patient_id: patient.id, benefit_type: :utilities)

      assert {:error, :benefit_expired} = Benefits.check_eligibility(
        patient.id,
        :utilities,
        Decimal.new("10.00")
      )
    end
  end

  describe "record_usage/3" do
    test "records usage and updates balance" do
      benefit = insert(:benefit,
        total_allocated: Decimal.new("200.00"),
        used_amount: Decimal.new("0.00")
      )

      audit_context = %{user_role: :agent, action: "record_usage"}

      assert {:ok, updated} = Benefits.record_usage(
        benefit.id,
        Decimal.new("50.00"),
        audit_context
      )

      assert Decimal.equal?(updated.used_amount, Decimal.new("50.00"))
    end

    test "marks benefit as depleted when fully used" do
      benefit = insert(:benefit,
        total_allocated: Decimal.new("100.00"),
        used_amount: Decimal.new("80.00"),
        status: :active
      )

      audit_context = %{user_role: :agent, action: "record_usage"}

      {:ok, updated} = Benefits.record_usage(
        benefit.id,
        Decimal.new("20.00"),
        audit_context
      )

      assert updated.status == :depleted
    end

    test "prevents usage exceeding total allocation" do
      benefit = insert(:benefit,
        total_allocated: Decimal.new("100.00"),
        used_amount: Decimal.new("90.00")
      )

      audit_context = %{user_role: :agent, action: "record_usage"}

      assert {:error, changeset} = Benefits.record_usage(
        benefit.id,
        Decimal.new("20.00"),
        audit_context
      )

      assert "exceeds remaining balance" in errors_on(changeset).used_amount
    end
  end

  describe "get_patient_benefits/1" do
    test "returns all benefits for patient" do
      patient = insert(:patient)
      benefit1 = insert(:benefit, patient_id: patient.id, benefit_type: :transportation)
      benefit2 = insert(:benefit, patient_id: patient.id, benefit_type: :meals)

      # Another patient's benefit
      insert(:benefit)

      benefits = Benefits.get_patient_benefits(patient.id)

      assert length(benefits) == 2
      assert Enum.any?(benefits, &(&1.id == benefit1.id))
      assert Enum.any?(benefits, &(&1.id == benefit2.id))
    end
  end

  describe "get_active_benefits/1" do
    test "returns only active benefits" do
      patient = insert(:patient)
      active = insert(:benefit, patient_id: patient.id, status: :active)
      insert(:depleted_benefit, patient_id: patient.id)
      insert(:expired_benefit, patient_id: patient.id)

      benefits = Benefits.get_active_benefits(patient.id)

      assert length(benefits) == 1
      assert hd(benefits).id == active.id
    end
  end

  describe "create_benefit/2" do
    test "creates benefit with valid attributes" do
      patient = insert(:patient)
      today = Date.utc_today()

      attrs = %{
        patient_id: patient.id,
        benefit_type: :otc_items,
        total_allocated: Decimal.new("150.00"),
        period_start: Date.beginning_of_month(today),
        period_end: Date.end_of_month(today),
        external_plan_id: "EXT-PLAN-123"
      }

      audit_context = %{user_role: :system, action: "create_benefit"}

      assert {:ok, %Benefit{} = benefit} = Benefits.create_benefit(attrs, audit_context)
      assert benefit.benefit_type == :otc_items
      assert Decimal.equal?(benefit.total_allocated, Decimal.new("150.00"))
      assert Decimal.equal?(benefit.used_amount, Decimal.new("0.00"))
      assert benefit.status == :active
    end

    test "validates period dates" do
      patient = insert(:patient)

      attrs = %{
        patient_id: patient.id,
        benefit_type: :fitness,
        total_allocated: Decimal.new("100.00"),
        period_start: ~D[2024-12-31],
        period_end: ~D[2024-01-01]  # End before start
      }

      audit_context = %{user_role: :system, action: "create_benefit"}

      assert {:error, changeset} = Benefits.create_benefit(attrs, audit_context)
      assert "must be after period start" in errors_on(changeset).period_end
    end
  end

  describe "sync_external_benefits/1" do
    test "creates benefits from external API" do
      patient = insert(:patient)

      assert {:ok, results} = Benefits.sync_external_benefits(patient.id)

      # Mock API returns 3 benefits
      successful = Enum.filter(results, &match?({:ok, _}, &1))
      assert length(successful) >= 1
    end
  end

  describe "expire_old_benefits/0" do
    test "marks expired benefits" do
      past_date = Date.utc_today() |> Date.add(-1)

      benefit = insert(:benefit,
        period_end: past_date,
        status: :active
      )

      Benefits.expire_old_benefits()

      updated = Repo.get!(Benefit, benefit.id)
      assert updated.status == :expired
    end

    test "does not affect current benefits" do
      future_date = Date.utc_today() |> Date.add(30)

      benefit = insert(:benefit,
        period_end: future_date,
        status: :active
      )

      Benefits.expire_old_benefits()

      updated = Repo.get!(Benefit, benefit.id)
      assert updated.status == :active
    end
  end
end
