# frozen_string_literal: true

module AdminArea
  class RecurringTasksController < BaseController
    def index
      @tasks = SolidQueue::RecurringTask.order(:key).map do |task|
        last_execution = SolidQueue::RecurringExecution
                          .where(task_key: task.key)
                          .order(run_at: :desc)
                          .first

        last_job = last_execution&.job

        {
          task: task,
          last_run_at: last_execution&.run_at,
          last_job_status: job_status(last_job)
        }
      end
    end

    def run
      task = SolidQueue::RecurringTask.find(params[:id])

      if task.class_name.present?
        job_class = resolve_job_class(task.class_name)
        if job_class.present?
          job_class.perform_later
        else
          redirect_to admin_recurring_tasks_path, alert: "\"#{task.key}\" has an invalid job class."
          return
        end
      else
        redirect_to admin_recurring_tasks_path, alert: "\"#{task.key}\" cannot be run manually (command-based tasks are not supported)."
        return
      end

      redirect_to admin_recurring_tasks_path, notice: "\"#{task.key}\" has been enqueued."
    end

    private

      def resolve_job_class(class_name)
        Rails.application.eager_load! unless Rails.application.config.eager_load
        job_class = class_name.safe_constantize
        return job_class if job_class.present? && job_class < ApplicationJob

        nil
      end

      def job_status(job)
        return :unknown unless job

        if job.finished_at.present?
          if SolidQueue::FailedExecution.exists?(job_id: job.id)
            :failed
          else
            :completed
          end
        elsif SolidQueue::ClaimedExecution.exists?(job_id: job.id)
          :running
        else
          :pending
        end
      end
  end
end
