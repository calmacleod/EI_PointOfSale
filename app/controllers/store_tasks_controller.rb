# frozen_string_literal: true

class StoreTasksController < ApplicationController
  include Filterable

  before_action :set_store_task, only: %i[show edit update destroy]

  def index
    @filter_config = FilterConfig.new(:store_tasks, store_tasks_path,
                                      sort_default: "created_at", sort_default_direction: "desc",
                                      search_placeholder: "Search tasks...") do |f|
      f.select :status, label: "Status",
               options: StoreTask.statuses.keys.map { |s| [ s.humanize.titleize, s ] }
      f.select :assigned_to_id, label: "Assigned To",
               options: User.order(:name).pluck(:name, :id)
      f.date_range :due_date, label: "Due Date"
      f.date_range :created_at, label: "Created"

      f.column :title,          label: "Title",       default: true, sortable: true
      f.column :status,         label: "Status",      default: true, sortable: true
      f.column :assigned_to_id, label: "Assigned To", default: true, sortable: true
      f.column :due_date,       label: "Due Date",    default: true, sortable: true
      f.column :created_at,     label: "Created",     default: false, sortable: true
    end
    @saved_queries = current_user.saved_queries.for_resource("store_tasks")

    @pagy, @store_tasks = filter_and_paginate(
      StoreTask.includes(:assigned_to),
      config: @filter_config
    )
  end

  def show; end

  def new
    @store_task = StoreTask.new
  end

  def create
    @store_task = StoreTask.new(store_task_params)
    if @store_task.save
      redirect_to store_tasks_path, notice: "Task created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @store_task.update(store_task_params)
      redirect_to store_task_path(@store_task), notice: "Task updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @store_task.destroy
    redirect_to store_tasks_path, notice: "Task deleted."
  end

  private

    def set_store_task
      @store_task = StoreTask.find(params[:id])
    end

    def store_task_params
      params.require(:store_task).permit(:title, :body, :status, :assigned_to_id, :due_date)
    end
end
