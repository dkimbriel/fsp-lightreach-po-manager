class EmailNotificationService
  def initialize(po_generation_job)
    @job = po_generation_job
    @po_generation_service = PoGenerationService.new(@job)
  end

  def send_batch_email(test_mode: false)
    return unless @job.completed?

    po_results = (@job.po_results || []).map(&:with_indifferent_access)
    return if po_results.empty?

    # Fetch individual PO PDFs from NetSuite and upload to Lightreach
    po_pdfs_by_id = {}
    po_results.each do |po_data|
      pdf_binary = Netsuite::PurchaseOrder.fetch_pdf_binary(po_data[:po_id])
      Rails.logger.info "Fetched PDF for PO #{po_data[:po_id]}, size: #{pdf_binary.bytesize} bytes"

      # Upload to Lightreach if account_id is available (skip in test mode)
      @po_generation_service.upload_po_to_lightreach(po_data, pdf_binary) if po_data[:lightreach_account_id].present? && !test_mode

      po_pdfs_by_id[po_data[:po_id]] = {
        po_id: po_data[:po_id],
        project_id: po_data[:project_id],
        pdf_binary: pdf_binary
      }
    end

    # Group POs by region (location_name) and send one email per region
    pos_by_region = po_results.group_by { |po| po[:location_name] }

    pos_by_region.each do |region, region_pos|
      region_po_pdfs = region_pos.map { |po| po_pdfs_by_id[po[:po_id]] }
      region_summary_pdf = @po_generation_service.generate_location_summary_pdf(region_pos, region)

      Lightreach::DirectPayMailer.regional_pos_created(
        region: region,
        created_pos: region_pos,
        po_pdfs: region_po_pdfs,
        summary_pdf: region_summary_pdf,
        test_mode: test_mode
      ).deliver_now

      Rails.logger.info "Sent PO email for region #{region} with #{region_pos.length} projects"
    end

    Rails.logger.info "Sent #{pos_by_region.keys.length} regional PO emails for #{po_results.length} total projects"
  rescue StandardError => e
    Rails.logger.error "Failed to send batch PO email: #{e.message}"
    raise
  end

  def send_single_email(po_result, cc_email: nil)
    pdf_binary = Netsuite::PurchaseOrder.fetch_pdf_binary(po_result[:po_id])
    Rails.logger.info "Fetched PDF for PO #{po_result[:po_id]}, size: #{pdf_binary.bytesize} bytes"

    # Upload to Lightreach if applicable
    @po_generation_service.upload_po_to_lightreach(po_result, pdf_binary) if po_result[:lightreach_account_id].present?

    # Send email with CC
    Lightreach::DirectPayMailer.single_po_created(
      po_data: po_result,
      pdf_binary: pdf_binary,
      cc_email: cc_email
    ).deliver_now

    Rails.logger.info "Sent single PO email for project #{po_result[:project_id]}"
  rescue StandardError => e
    Rails.logger.error "Failed to send single PO email: #{e.message}"
    raise
  end
end
