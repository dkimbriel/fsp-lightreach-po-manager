require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:po_generation_jobs).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
  end

  describe '.from_google' do
    let(:email) { 'test@gofreedompower.com' }
    let(:uid) { 'google_123' }
    let(:full_name) { 'Test User' }

    context 'with valid @gofreedompower.com email' do
      it 'creates a new user' do
        expect {
          User.from_google(uid: uid, email: email, full_name: full_name)
        }.to change(User, :count).by(1)
      end

      it 'returns the created user' do
        user = User.from_google(uid: uid, email: email, full_name: full_name)
        expect(user).to be_persisted
        expect(user.email).to eq(email)
        expect(user.uid).to eq(uid)
        expect(user.full_name).to eq(full_name)
      end

      it 'finds existing user instead of creating duplicate' do
        existing_user = create(:user, email: email, uid: uid)
        user = User.from_google(uid: uid, email: email, full_name: full_name)
        expect(user.id).to eq(existing_user.id)
      end
    end

    context 'with invalid email domain' do
      let(:invalid_email) { 'test@gmail.com' }

      it 'returns nil' do
        user = User.from_google(uid: uid, email: invalid_email, full_name: full_name)
        expect(user).to be_nil
      end

      it 'does not create a user' do
        expect {
          User.from_google(uid: uid, email: invalid_email, full_name: full_name)
        }.not_to change(User, :count)
      end
    end
  end
end
