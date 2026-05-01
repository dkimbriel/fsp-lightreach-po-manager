class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Main dashboard view - React will take over from here
  end
end
