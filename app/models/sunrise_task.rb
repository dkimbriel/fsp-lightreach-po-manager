# Stub model for SunriseTask
# TODO: Implement full model if we need to sync task data from Project Sunrise
class SunriseTask < ApplicationRecord
  # For now, return false to allow PO generation to proceed
  # In production, this would query the sunrise_tasks table
  def self.exists?(conditions)
    false
  end

  # Stub: this table doesn't exist yet in our database
  # We can add it later if needed with a migration
  self.abstract_class = true
end
