class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: :google_oauth2

  def google_oauth2
    auth = request.env['omniauth.auth']

    user = User.from_google(
      uid: auth.uid,
      email: auth.info.email,
      full_name: auth.info.name
    )

    if user
      sign_in_and_redirect user, event: :authentication
      set_flash_message(:notice, :success, kind: 'Google') if is_navigational_format?
    else
      redirect_to new_user_session_path, alert: 'Your email is not authorized to access this application. Please use a @gofreedompower.com email.'
    end
  end

  def failure
    redirect_to new_user_session_path, alert: 'Authentication failed.'
  end
end
