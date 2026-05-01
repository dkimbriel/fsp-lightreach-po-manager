require 'rails_helper'

RSpec.describe PoGenerationLog, type: :model do
  describe 'associations' do
    it { should belong_to(:po_generation_job) }
  end

  describe 'validations' do
    it { should validate_presence_of(:level) }
    it { should validate_presence_of(:message) }
  end
end
