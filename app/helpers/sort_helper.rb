# frozen_string_literal: true

module SortHelper
  # Renders a clickable column header that toggles sort direction.
  #
  # Usage:
  #   <th><%= sort_link "Customer", :name %></th>
  #   <th><%= sort_link "Created", :created_at %></th>
  #
  # The link preserves all existing query params (search, filters, pagination)
  # and adds/updates `sort` and `dir` params.
  #
  def sort_link(label, column, **options)
    column = column.to_s
    is_active = current_sort_column == column
    next_dir  = is_active && current_sort_direction == "asc" ? "desc" : "asc"

    url = url_for(request.query_parameters.merge(sort: column, dir: next_dir, page: nil))

    arrow = if is_active
              current_sort_direction == "asc" ? "▲" : "▼"
    end

    link_class = "group inline-flex items-center gap-0.5 #{options.delete(:class)}"
    active_class = is_active ? "text-accent" : ""

    link_to url, class: "#{link_class} #{active_class}".strip, data: { turbo_action: "replace" } do
      safe_join([
        label,
        (tag.span(arrow, class: "text-[9px]", aria: { hidden: true }) if arrow)
      ].compact)
    end
  end
end
