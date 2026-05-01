class PoGenerationLog < ApplicationRecord
  belongs_to :po_generation_job

  validates :level, presence: true, inclusion: { in: %w[info success warning error] }
  validates :message, presence: true

  scope :ordered, -> { order(created_at: :asc) }
end
