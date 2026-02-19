# frozen_string_literal: true

module Orders
  # Generates a formatted receipt using the active ReceiptTemplate.
  # Returns an array of text lines for thermal-printer-style rendering.
  class GenerateReceipt
    def self.call(order)
      new(order).call
    end

    def initialize(order)
      @order = order
      @template = ReceiptTemplate.current
      @store = Store.current
      @width = @template&.chars_per_line || 48
    end

    def call
      lines = []
      lines.concat(header_lines)
      lines << separator
      lines.concat(order_info_lines)
      lines << separator
      lines.concat(line_item_lines)
      lines << separator
      lines.concat(totals_lines)
      lines << separator
      lines.concat(payment_lines)
      lines.concat(tax_exempt_lines)
      lines << separator
      lines.concat(footer_lines)
      lines
    end

    private

      def header_lines
        return [] unless @template

        lines = []
        @template.ordered_sections.each do |section|
          lines.concat(render_header_section(section))
        end
        lines
      end

      # Renders a single named section for the actual receipt.
      # Sections that belong to order_info_lines are skipped here.
      def render_header_section(section)
        case section
        when "logo"
          [] # Logo is not represented in text output
        when "store_name"
          return [] unless @template.show_store_name && @store.name.present?
          [ center(@store.name.upcase) ]
        when "store_address"
          return [] unless @template.show_store_address
          @store.receipt_address_lines.map { |l| center(l) }
        when "store_phone"
          return [] unless @template.show_store_phone && @store.phone.present?
          [ center("Tel: #{@store.phone}") ]
        when "store_email"
          return [] unless @template.show_store_email && @store.email.present?
          [ center(@store.email) ]
        when "header_text"
          return [] unless @template.header_text.present?
          lines = [ "" ]
          @template.header_text.each_line { |l| lines << center(l.chomp) }
          lines
        when "date_time", "cashier_name"
          [] # Rendered in order_info_lines to keep them grouped with order number
        else
          []
        end
      end

      def order_info_lines
        lines = []

        sections = @template&.ordered_sections || ReceiptTemplate::SECTIONS
        date_time_first = sections.index("date_time").to_i < sections.index("cashier_name").to_i

        if date_time_first
          lines.concat(date_time_line)
          lines << left_right("Order:", @order.number)
          lines.concat(cashier_line)
        else
          lines.concat(cashier_line)
          lines << left_right("Order:", @order.number)
          lines.concat(date_time_line)
        end

        if @order.customer.present?
          lines << left_right("Customer:", @order.customer.name)
        end

        lines
      end

      def date_time_line
        return [] unless @template&.show_date_time

        dt = @order.completed_at || @order.created_at
        [ left_right("Date: #{dt.strftime('%Y-%m-%d')}", dt.strftime("%H:%M")) ]
      end

      def cashier_line
        return [] unless @template&.show_cashier_name

        [ left_right("Cashier:", @order.created_by.name || "Staff") ]
      end

      def line_item_lines
        lines = []
        @order.order_lines.each do |line|
          price = format_money(line.subtotal_before_discount)
          name = line.name.to_s
          available = @width - price.length - 1

          if name.length <= available
            lines << left_right(name, price)
          else
            # First line: as much of the name as fits + right-aligned price
            lines << left_right(name[0...available], price)
            # Remaining name wraps to subsequent lines (indented)
            rest = name[available..]
            rest.chars.each_slice(@width - 2).each do |chunk|
              lines << "  #{chunk.join}"
            end
          end

          # Show product/service code on next line
          if line.code.present?
            lines << "  [#{line.code}]"
          end

          if line.quantity > 1
            lines << "  #{line.quantity} x #{format_money(line.unit_price)}"
          end

          if line.discount_amount > 0
            lines << left_right("  Discount", "-#{format_money(line.discount_amount)}")
          end
        end
        lines
      end

      def totals_lines
        lines = []
        lines << left_right("Subtotal:", format_money(@order.subtotal))

        if @order.discount_total > 0
          lines << left_right("Discount:", "-#{format_money(@order.discount_total)}")
        end

        lines << left_right("Tax:", format_money(@order.tax_total))
        lines << ""
        lines << left_right("TOTAL:", format_money(@order.total))
        lines
      end

      def payment_lines
        lines = []
        @order.order_payments.each do |payment|
          lines << left_right(payment.display_method + ":", format_money(payment.amount))

          if payment.cash? && payment.amount_tendered.present?
            lines << left_right("  Tendered:", format_money(payment.amount_tendered))
            lines << left_right("  Change:", format_money(payment.change_given || 0))
          end

          lines << left_right("  Ref:", payment.reference) if payment.reference.present?
        end
        lines
      end

      def tax_exempt_lines
        return [] unless @order.tax_exempt? || @order.tax_exempt_number.present?

        lines = [ "" ]
        lines << center("** TAX EXEMPT **")
        lines << center("Status Card: #{@order.tax_exempt_number}") if @order.tax_exempt_number.present?
        lines
      end

      def footer_lines
        lines = []
        if @template&.footer_text.present?
          lines << ""
          @template.footer_text.each_line { |l| lines << center(l.chomp) }
        end
        lines
      end

      def center(text)
        text.truncate(@width).center(@width)
      end

      def left_right(left, right)
        right = right.to_s
        gap = @width - left.length - right.length
        gap = 1 if gap < 1
        "#{left}#{' ' * gap}#{right}"
      end

      def separator
        "=" * @width
      end

      def format_money(amount)
        "$#{'%.2f' % (amount || 0)}"
      end
  end
end
