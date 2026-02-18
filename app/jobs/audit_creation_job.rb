# frozen_string_literal: true

# Creates audit records asynchronously to avoid blocking the request thread.
# The audit context (user, remote_address, request_uuid) is captured at enqueue time
# and passed through to the job.
class AuditCreationJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  # @param auditable_type [String] the class name of the audited record
  # @param auditable_id [Integer] the ID of the audited record
  # @param action [String] create, update, or destroy
  # @param audited_changes [Hash] the changes to be audited
  # @param audit_context [Hash] captured context from Audited.store
  def perform(auditable_type, auditable_id, action, audited_changes, audit_context = {})
    # For destroy actions, the record may be gone
    auditable = auditable_type.constantize.find_by(id: auditable_id) unless action == "destroy"

    # Set the store context for this job execution
    Audited.store[:audited_user] = user_from_context(audit_context) if audit_context["user_id"]
    Audited.store[:current_remote_address] = audit_context["remote_address"]
    Audited.store[:current_request_uuid] = audit_context["request_uuid"]

    version = next_version(auditable_type, auditable_id)

    audit_attributes = {
      auditable_type: auditable_type,
      auditable_id: auditable_id,
      auditable: auditable,
      action: action,
      audited_changes: audited_changes,
      version: version,
      comment: audit_context["comment"]
    }

    Audited::Audit.create!(audit_attributes)
  end

  private

    def user_from_context(context)
      return unless context["user_type"] && context["user_id"]

      user_class = context["user_type"].constantize
      user_class.find_by(id: context["user_id"])
    rescue NameError, ActiveRecord::RecordNotFound
      nil
    end

    def next_version(auditable_type, auditable_id)
      (Audited::Audit.where(
        auditable_type: auditable_type,
        auditable_id: auditable_id
      ).maximum(:version) || 0) + 1
    end
end
