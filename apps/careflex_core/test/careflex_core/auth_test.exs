defmodule CareflexCore.AuthTest do
  use CareflexCore.DataCase, async: true

  alias CareflexCore.Auth
  alias CareflexCore.Auth.User

  describe "register_user/2" do
    test "creates user with valid attributes" do
      attrs = %{
        email: "newuser@example.com",
        password: "SecurePass123!",
        first_name: "New",
        last_name: "User",
        role: :patient
      }

      assert {:ok, %User{} = user} = Auth.register_user(attrs)
      assert user.email == "newuser@example.com"
      assert user.role == :patient
      assert user.status == :active
      assert user.password_hash != nil
    end

    test "fails with invalid email" do
      attrs = %{
        email: "invalid-email",
        password: "SecurePass123!",
        first_name: "Test",
        last_name: "User"
      }

      assert {:error, changeset} = Auth.register_user(attrs)
      assert "has invalid format" in errors_on(changeset).email
    end

    test "fails with short password" do
      attrs = %{
        email: "test@example.com",
        password: "short",
        first_name: "Test",
        last_name: "User"
      }

      assert {:error, changeset} = Auth.register_user(attrs)
      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "fails with duplicate email" do
      user = insert(:user)

      attrs = %{
        email: user.email,
        password: "SecurePass123!",
        first_name: "Test",
        last_name: "User"
      }

      assert {:error, changeset} = Auth.register_user(attrs)
      assert "has already been taken" in errors_on(changeset).email_hash
    end
  end

  describe "authenticate_user/2" do
    test "authenticates user with valid credentials" do
      user = insert(:user, password: "SecurePass123!")

      assert {:ok, authenticated_user} = Auth.authenticate_user(user.email, "SecurePass123!")
      assert authenticated_user.id == user.id
      assert authenticated_user.last_login_at != nil
      assert authenticated_user.failed_login_attempts == 0
    end

    test "fails with invalid password" do
      user = insert(:user, password: "SecurePass123!")

      assert {:error, :invalid_credentials} = Auth.authenticate_user(user.email, "WrongPassword")
    end

    test "fails with non-existent email" do
      assert {:error, :invalid_credentials} = Auth.authenticate_user("nonexistent@example.com", "password")
    end

    test "fails with locked account" do
      user = insert(:locked_user, password: "SecurePass123!")

      assert {:error, :account_locked} = Auth.authenticate_user(user.email, "SecurePass123!")
    end

    test "increments failed attempts on wrong password" do
      user = insert(:user, password: "SecurePass123!", failed_login_attempts: 2)

      assert {:error, :invalid_credentials} = Auth.authenticate_user(user.email, "WrongPassword")

      updated_user = Repo.get!(User, user.id)
      assert updated_user.failed_login_attempts == 3
    end

    test "locks account after 5 failed attempts" do
      user = insert(:user, password: "SecurePass123!", failed_login_attempts: 4)

      assert {:error, :invalid_credentials} = Auth.authenticate_user(user.email, "WrongPassword")

      updated_user = Repo.get!(User, user.id)
      assert updated_user.failed_login_attempts == 5
      assert updated_user.locked_at != nil
    end
  end

  describe "authorize/3" do
    test "admin has all permissions" do
      admin = insert(:admin_user)

      assert :ok = Auth.authorize(admin, :any_action, nil)
      assert :ok = Auth.authorize(admin, :view_patients, nil)
      assert :ok = Auth.authorize(admin, :delete_data, nil)
    end

    test "agent can view patients and manage appointments" do
      agent = insert(:agent_user)

      assert :ok = Auth.authorize(agent, :view_patients, nil)
      assert :ok = Auth.authorize(agent, :manage_appointments, nil)
      assert :ok = Auth.authorize(agent, :view_benefits, nil)
    end

    test "agent cannot perform admin actions" do
      agent = insert(:agent_user)

      assert {:error, :unauthorized} = Auth.authorize(agent, :delete_user, nil)
    end

    test "patient can view own data" do
      patient = insert(:patient_user)

      assert :ok = Auth.authorize(patient, :view_own_appointments, nil)
      assert :ok = Auth.authorize(patient, :view_own_benefits, nil)
    end

    test "patient cannot view other patients' data" do
      patient = insert(:patient_user)

      assert {:error, :unauthorized} = Auth.authorize(patient, :view_patients, nil)
      assert {:error, :unauthorized} = Auth.authorize(patient, :manage_appointments, nil)
    end
  end

  describe "change_password/4" do
    test "changes password with valid current password" do
      user = insert(:user, password: "OldPassword123!")

      assert {:ok, updated_user} = Auth.change_password(user, "OldPassword123!", "NewPassword123!", %{user_id: user.id})

      # Can authenticate with new password
      assert {:ok, _} = Auth.authenticate_user(user.email, "NewPassword123!")

      # Cannot authenticate with old password
      assert {:error, :invalid_credentials} = Auth.authenticate_user(user.email, "OldPassword123!")
    end

    test "fails with incorrect current password" do
      user = insert(:user, password: "OldPassword123!")

      assert {:error, :invalid_password} = Auth.change_password(user, "WrongPassword", "NewPassword123!", %{})
    end
  end

  describe "unlock_account/2" do
    test "unlocks locked account" do
      user = insert(:locked_user)

      assert {:ok, unlocked_user} = Auth.unlock_account(user, %{user_id: 1, user_role: :admin})
      assert unlocked_user.locked_at == nil
      assert unlocked_user.failed_login_attempts == 0
    end
  end
end
