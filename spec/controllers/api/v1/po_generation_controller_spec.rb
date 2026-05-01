require 'rails_helper'

RSpec.describe Api::V1::PoGenerationController, type: :controller do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'POST #generate_region' do
    let(:region) { 'Austin' }

    context 'when no job is running for region' do
      it 'creates a new job' do
        expect {
          post :generate_region, params: { region: region }
        }.to change(PoGenerationJob, :count).by(1)

        job = PoGenerationJob.last
        expect(job.job_type).to eq('region')
        expect(job.region).to eq(region)
        expect(job.user).to eq(user)
      end

      it 'enqueues the worker' do
        expect(BatchPoGenerationWorker).to receive(:perform_async)
        post :generate_region, params: { region: region }
      end

      it 'returns success response' do
        allow(BatchPoGenerationWorker).to receive(:perform_async)
        post :generate_region, params: { region: region }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['job_id']).to be_present
        expect(json['message']).to include('started')
      end
    end

    context 'when job is already running for region' do
      before do
        create(:po_generation_job, :running, :region_job, region: region)
      end

      it 'does not create a new job' do
        expect {
          post :generate_region, params: { region: region }
        }.not_to change(PoGenerationJob, :count)
      end

      it 'returns conflict status' do
        post :generate_region, params: { region: region }
        expect(response).to have_http_status(:conflict)
      end

      it 'returns error message' do
        post :generate_region, params: { region: region }
        json = JSON.parse(response.body)
        expect(json['error']).to include('already in progress')
      end
    end

    context 'when user is not authenticated' do
      before do
        sign_out user
      end

      it 'returns unauthorized' do
        post :generate_region, params: { region: region }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #generate_single' do
    let(:project_id) { 'SF-12345' }

    it 'creates a new job' do
      expect {
        post :generate_single, params: { project_id: project_id }
      }.to change(PoGenerationJob, :count).by(1)

      job = PoGenerationJob.last
      expect(job.job_type).to eq('single')
      expect(job.user).to eq(user)
    end

    it 'enqueues the worker' do
      expect(BatchPoGenerationWorker).to receive(:perform_async)
      post :generate_single, params: { project_id: project_id }
    end

    it 'returns success response' do
      allow(BatchPoGenerationWorker).to receive(:perform_async)
      post :generate_single, params: { project_id: project_id }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['job_id']).to be_present
    end
  end

  describe 'POST #generate_batch' do
    let(:project_ids) { ['SF-001', 'SF-002', 'SF-003'] }

    context 'when no conflicts' do
      it 'creates a new job' do
        expect {
          post :generate_batch, params: { project_ids: project_ids }
        }.to change(PoGenerationJob, :count).by(1)

        job = PoGenerationJob.last
        expect(job.job_type).to eq('batch')
        expect(job.project_ids).to match_array(project_ids)
      end

      it 'enqueues the worker' do
        expect(BatchPoGenerationWorker).to receive(:perform_async)
        post :generate_batch, params: { project_ids: project_ids }
      end

      it 'returns success response' do
        allow(BatchPoGenerationWorker).to receive(:perform_async)
        post :generate_batch, params: { project_ids: project_ids }

        expect(response).to have_http_status(:success)
      end
    end

    context 'when some projects are locked' do
      before do
        running_job = create(:po_generation_job, :running, :batch_job, project_ids: ['SF-001'])
      end

      it 'does not create a new job' do
        expect {
          post :generate_batch, params: { project_ids: project_ids }
        }.not_to change(PoGenerationJob, :count)
      end

      it 'returns conflict status' do
        post :generate_batch, params: { project_ids: project_ids }
        expect(response).to have_http_status(:conflict)
      end

      it 'returns conflicting project IDs' do
        post :generate_batch, params: { project_ids: project_ids }
        json = JSON.parse(response.body)
        expect(json['conflicting_projects']).to include('SF-001')
      end
    end

    context 'when project_ids is empty' do
      it 'returns bad request' do
        post :generate_batch, params: { project_ids: [] }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'GET #job_status' do
    let(:job) { create(:po_generation_job, user: user) }

    it 'returns job status' do
      get :job_status, params: { id: job.id }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['status']).to eq(job.status)
      expect(json['job_type']).to eq(job.job_type)
    end

    it 'includes logs' do
      create(:po_generation_log, po_generation_job: job, message: 'Test log', level: 'info')

      get :job_status, params: { id: job.id }

      json = JSON.parse(response.body)
      expect(json['logs']).to be_an(Array)
      expect(json['logs'].first['message']).to eq('Test log')
    end

    context 'when job does not exist' do
      it 'returns not found' do
        get :job_status, params: { id: 99999 }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when job belongs to different user' do
      let(:other_user) { create(:user, email: 'other@gofreedompower.com') }
      let(:other_job) { create(:po_generation_job, user: other_user) }

      it 'returns not found' do
        get :job_status, params: { id: other_job.id }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #resend_email' do
    let(:job) { create(:po_generation_job, :completed, user: user) }

    before do
      allow_any_instance_of(EmailNotificationService).to receive(:send_batch_email)
    end

    it 'calls email notification service' do
      expect_any_instance_of(EmailNotificationService).to receive(:send_batch_email).with(test_mode: false)
      post :resend_email, params: { id: job.id }
    end

    it 'returns success response' do
      post :resend_email, params: { id: job.id }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['message']).to include('Email sent')
    end

    context 'when job is not completed' do
      let(:running_job) { create(:po_generation_job, :running, user: user) }

      it 'returns bad request' do
        post :resend_email, params: { id: running_job.id }
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when email fails' do
      before do
        allow_any_instance_of(EmailNotificationService).to receive(:send_batch_email).and_raise(StandardError, 'Email error')
      end

      it 'returns error response' do
        post :resend_email, params: { id: job.id }
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
