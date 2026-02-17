# frozen_string_literal: true

module OrdersHelper
  # Link to open the order detail modal
  def modal_trigger(order)
    tag.button type: "button",
               data: { action: "click->modal#open", modal_id: dom_id(order, :modal) },
               class: "font-mono font-medium text-accent hover:underline cursor-pointer" do
      order.number
    end
  end

  # Display customer name or "Quick Sale"
  def customer_cell(order)
    if order.customer
      link_to order.customer.name, customer_path(order.customer),
              class: "text-accent hover:underline",
              data: { turbo_frame: "_top" }
    else
      tag.span "Quick Sale", class: "text-muted italic"
    end
  end

  # Action buttons for held order row
  def action_buttons(order)
    tag.div class: "flex items-center justify-end gap-1" do
      safe_join([
        link_to(register_path(order_id: order.id),
                class: "inline-flex items-center justify-center rounded-md p-1 text-accent hover:bg-[var(--color-border)]",
                title: "Resume Order",
                data: { turbo_frame: "_top" }) do
          tag.svg class: "h-4 w-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" do
            tag.path "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2",
                     d: "M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"
            tag.path "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2",
                     d: "M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
          end
        end,
        button_to(cancel_order_path(order),
                  method: :delete,
                  class: "inline-flex items-center justify-center rounded-md p-1 text-[var(--color-error-text)] hover:bg-[var(--color-error-bg)]",
                  title: "Cancel Order",
                  data: { turbo_confirm: "Cancel order #{order.number}? This cannot be undone." }) do
          tag.svg class: "h-4 w-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" do
            tag.path "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2",
                     d: "M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
          end
        end
      ])
    end
  end
end
