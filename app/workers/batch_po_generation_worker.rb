class BatchPoGenerationWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'po_generation', retry: 0

  def perform(job_id)
    job = PoGenerationJob.find(job_id)

    job.update!(
      status: 'running',
      started_at: Time.current,
      locked_at: Time.current,
      locked_by: jid
    )

    service = PoGenerationService.new(job)

    # Generate POs based on job type
    po_results = if job.job_type == 'region'
                   service.generate_pos_for_region(job.region)
                 else
                   service.generate_pos_for_batch(job.project_ids)
                 end

    # Update job with results
    job.update!(
      status: 'completed',
      successful_pos: po_results.length,
      failed_pos: job.total_projects - po_results.length,
      po_results: po_results,
      completed_at: Time.current
    )

    # Send batch email
    EmailNotificationService.new(job).send_batch_email if po_results.any?

  rescue StandardError => e
    job.update!(
      status: 'failed',
      error_message: e.message,
      completed_at: Time.current
    )
    raise
  ensure
    job.update!(locked_at: nil, locked_by: nil) if job.persisted?
  end
end
