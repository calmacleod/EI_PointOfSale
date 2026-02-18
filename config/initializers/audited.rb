# frozen_string_literal: true

# Configure audited gem for asynchronous audit creation.
# Models using `audited async: true` will have audits created via background jobs.

module AsyncAuditing
  def audit_create
    return unless auditing_enabled

    if async_auditing_enabled?
      enqueue_async_audit("create", audited_attributes)
    else
      super
    end
  end

  def audit_update
    return unless auditing_enabled

    if async_auditing_enabled?
      changes = audited_changes(exclude_readonly_attrs: true)
      return if changes.empty? && audit_comment.blank?

      enqueue_async_audit("update", changes)
    else
      super
    end
  end

  def audit_destroy
    return unless auditing_enabled

    if async_auditing_enabled?
      return if new_record?

      enqueue_async_audit("destroy", audited_attributes)
    else
      super
    end
  end

  private

    def async_auditing_enabled?
      self.class.audited_options[:async] == true
    end

    def enqueue_async_audit(action, audited_changes_data)
      # Capture context from Audited.store at enqueue time
      context = {}.tap do |ctx|
        user = Audited.store[:audited_user] || Audited.store[:current_user]&.call
        if user
          ctx["user_id"] = user.id
          ctx["user_type"] = user.class.name
        end

        ctx["remote_address"] = Audited.store[:current_remote_address]
        ctx["request_uuid"] = Audited.store[:current_request_uuid] || SecureRandom.uuid
        ctx["comment"] = audit_comment if audit_comment.present?
      end

      AuditCreationJob.perform_later(
        self.class.name,
        id,
        action,
        audited_changes_data,
        context
      )
    end
end

Rails.application.config.after_initialize do
  Audited::Auditor::AuditedInstanceMethods.prepend(AsyncAuditing)
end
