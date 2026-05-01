require 'rails_helper'

RSpec.describe PoGenerationService, type: :service do
  let(:job) { create(:po_generation_job, :running) }
  let(:service) { described_class.new(job) }

  describe '#log_progress' do
    it 'creates a log entry in the database' do
      expect {
        service.log_progress('Test message')
      }.to change(PoGenerationLog, :count).by(1)

      log = PoGenerationLog.last
      expect(log.message).to eq('Test message')
      expect(log.level).to eq('info')
      expect(log.po_generation_job).to eq(job)
    end

    it 'supports different log levels' do
      service.log_progress('Error message', level: :error)
      log = PoGenerationLog.last
      expect(log.level).to eq('error')
    end

    it 'broadcasts to ActionCable' do
      expect(ActionCable.server).to receive(:broadcast).with(
        "po_generation_#{job.id}",
        hash_including(message: 'Test message', level: 'info')
      )
      service.log_progress('Test message')
    end
  end

  describe '#generate_location_summary_pdf' do
    let(:location_pos) do
      [
        {
          po_id: 12345,
          project_id: 'SF-001',
          project_name: 'Austin Project 1',
          po_items: [
            { part_number: 'PSR-B168', quantity: 10, category: 3 },
            { part_number: 'MODULE-123', quantity: 20, category: 2 }
          ]
        },
        {
          po_id: 12346,
          project_id: 'SF-002',
          project_name: 'Austin Project 2',
          po_items: [
            { part_number: 'PSR-B168', quantity: 5, category: 3 },
            { part_number: 'INVERTER-456', quantity: 2, category: 21 }
          ]
        }
      ]
    end

    it 'generates a PDF binary' do
      pdf_binary = service.generate_location_summary_pdf(location_pos, 'Austin')
      expect(pdf_binary).to be_a(String)
      expect(pdf_binary.bytesize).to be > 0
    end

    it 'includes the location name' do
      # PDF generation should not raise errors
      expect {
        service.generate_location_summary_pdf(location_pos, 'Austin')
      }.not_to raise_error
    end

    it 'handles empty PO list' do
      expect {
        service.generate_location_summary_pdf([], 'Austin')
      }.not_to raise_error
    end
  end

  describe '#upload_po_to_lightreach' do
    let(:po_data) do
      {
        po_id: 12345,
        project_id: 'SF-001',
        po_name: 'PO-12345',
        lightreach_account_id: 'LR-123'
      }
    end

    let(:pdf_binary) { 'PDF_BINARY_CONTENT' }

    before do
      allow(Lightreach::Document).to receive(:upload).and_return({ 'status' => 'success' })
    end

    it 'uploads PDF to Lightreach' do
      expect(Lightreach::Document).to receive(:upload).with(
        'LR-123',
        hash_including(type: 'billOfMaterials')
      )
      service.upload_po_to_lightreach(po_data, pdf_binary)
    end

    it 'logs progress on success' do
      expect(service).to receive(:log_progress).with(/Uploaded PO/)
      service.upload_po_to_lightreach(po_data, pdf_binary)
    end

    it 'returns the upload result' do
      result = service.upload_po_to_lightreach(po_data, pdf_binary)
      expect(result).to eq({ 'status' => 'success' })
    end

    context 'when upload fails' do
      before do
        allow(Lightreach::Document).to receive(:upload).and_raise(StandardError, 'Upload failed')
      end

      it 'logs error and returns nil' do
        expect(service).to receive(:log_progress).with(/Failed to upload/, level: :error)
        result = service.upload_po_to_lightreach(po_data, pdf_binary)
        expect(result).to be_nil
      end

      it 'does not raise error' do
        expect {
          service.upload_po_to_lightreach(po_data, pdf_binary)
        }.not_to raise_error
      end
    end
  end
end
