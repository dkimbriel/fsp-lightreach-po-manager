require 'rails_helper'

RSpec.describe PoGenerationJob, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:po_generation_logs).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:job_type).in_array(%w[region batch single]) }
    it { should validate_inclusion_of(:status).in_array(%w[pending running completed failed]) }
  end

  describe 'scopes' do
    let!(:pending_job) { create(:po_generation_job, status: 'pending') }
    let!(:running_job) { create(:po_generation_job, :running) }
    let!(:completed_job) { create(:po_generation_job, :completed) }

    describe '.running' do
      it 'returns only running jobs' do
        expect(PoGenerationJob.running).to contain_exactly(running_job)
      end
    end

    describe '.pending' do
      it 'returns only pending jobs' do
        expect(PoGenerationJob.pending).to contain_exactly(pending_job)
      end
    end

    describe '.completed' do
      it 'returns only completed jobs' do
        expect(PoGenerationJob.completed).to contain_exactly(completed_job)
      end
    end
  end

  describe '.running_for_region?' do
    let(:region) { 'NorCal' }

    context 'when there is a running job for the region' do
      let!(:running_job) { create(:po_generation_job, :region_job, :running, region: region) }

      it 'returns true' do
        expect(PoGenerationJob.running_for_region?(region)).to be true
      end
    end

    context 'when there is no running job for the region' do
      it 'returns false' do
        expect(PoGenerationJob.running_for_region?(region)).to be false
      end
    end

    context 'when there is a completed job for the region' do
      let!(:completed_job) { create(:po_generation_job, :region_job, :completed, region: region) }

      it 'returns false' do
        expect(PoGenerationJob.running_for_region?(region)).to be false
      end
    end
  end

  describe '.locked_project_ids' do
    context 'with multiple running jobs' do
      let!(:job1) { create(:po_generation_job, :running, project_ids: ['proj_1', 'proj_2']) }
      let!(:job2) { create(:po_generation_job, :running, project_ids: ['proj_3', 'proj_1']) }
      let!(:completed_job) { create(:po_generation_job, :completed, project_ids: ['proj_4']) }

      it 'returns unique project IDs from all running jobs' do
        locked_ids = PoGenerationJob.locked_project_ids
        expect(locked_ids).to match_array(['proj_1', 'proj_2', 'proj_3'])
      end

      it 'does not include project IDs from completed jobs' do
        locked_ids = PoGenerationJob.locked_project_ids
        expect(locked_ids).not_to include('proj_4')
      end
    end

    context 'with no running jobs' do
      it 'returns an empty array' do
        expect(PoGenerationJob.locked_project_ids).to eq([])
      end
    end
  end

  describe '#acquire_lock!' do
    let(:job) { create(:po_generation_job) }
    let(:worker_id) { 'worker_123' }

    it 'updates job to running status' do
      job.acquire_lock!(worker_id)
      expect(job.reload.status).to eq('running')
    end

    it 'sets locked_at timestamp' do
      job.acquire_lock!(worker_id)
      expect(job.reload.locked_at).to be_present
    end

    it 'sets locked_by worker ID' do
      job.acquire_lock!(worker_id)
      expect(job.reload.locked_by).to eq(worker_id)
    end

    it 'sets started_at timestamp' do
      job.acquire_lock!(worker_id)
      expect(job.reload.started_at).to be_present
    end
  end

  describe '#release_lock!' do
    let(:job) { create(:po_generation_job, :running) }

    it 'clears locked_at' do
      job.release_lock!
      expect(job.reload.locked_at).to be_nil
    end

    it 'clears locked_by' do
      job.release_lock!
      expect(job.reload.locked_by).to be_nil
    end
  end

  describe '#completed?' do
    it 'returns true when status is completed' do
      job = create(:po_generation_job, :completed)
      expect(job.completed?).to be true
    end

    it 'returns false when status is not completed' do
      job = create(:po_generation_job, status: 'running')
      expect(job.completed?).to be false
    end
  end

  describe '#failed?' do
    it 'returns true when status is failed' do
      job = create(:po_generation_job, :failed)
      expect(job.failed?).to be true
    end

    it 'returns false when status is not failed' do
      job = create(:po_generation_job, status: 'completed')
      expect(job.failed?).to be false
    end
  end
end
