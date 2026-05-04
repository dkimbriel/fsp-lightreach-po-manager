class PoGenerationChannel < ApplicationCable::Channel
  def subscribed
    job_id = params[:job_id]

    unless job_id
      reject
      return
    end

    # Verify the job exists and belongs to the current user
    job = PoGenerationJob.find_by(id: job_id, user_id: current_user.id)

    unless job
      reject
      return
    end

    # Subscribe to the job's broadcast stream
    stream_from "po_generation_#{job_id}"

    # Send existing logs to the client on initial subscription
    transmit_existing_logs(job)
  end

  def unsubscribed
    # Cleanup when channel is unsubscribed
    stop_all_streams
  end

  private

  def transmit_existing_logs(job)
    # Send all existing logs for this job
    logs = job.po_generation_logs.order(created_at: :asc)

    logs.each do |log|
      transmit({
        timestamp: log.created_at.strftime("%H:%M:%S"),
        level: log.level,
        message: log.message,
        job_id: job.id
      })
    end

    # Send job status update
    transmit({
      type: "status_update",
      job_id: job.id,
      status: job.status,
      total_projects: job.total_projects,
      successful_pos: job.successful_pos,
      failed_pos: job.failed_pos,
      started_at: job.started_at,
      completed_at: job.completed_at
    })
  end
end
