class Users::SessionsController < Devise::SessionsController
  # GET /users/sign_in
  def new
    # This will render the login page with Google OAuth button
  end

  # DELETE /users/sign_out
  def destroy
    super
  end
end
