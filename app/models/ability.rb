class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    # All authenticated users can manage their own notifications, push subscriptions, and saved queries.
    if user.persisted?
      can :manage, Notification, user_id: user.id
      can :manage, PushSubscription, user_id: user.id
      can :manage, SavedQuery, user_id: user.id
      can :manage, CashDrawerSession
      can :manage, TerminalReconciliation
      can :manage, StoreTask

      # Register (POS cashier workspace)
      can :show, :register
      can :new_order, :register

      # Orders are store-wide: any authenticated user can create, edit, hold, resume, and complete orders.
      can %i[read create update hold resume complete cancel quick_lookup assign_customer remove_customer held], Order
      can :manage, [ OrderLine, OrderPayment, OrderDiscount ]

      # Gift certificates: all authenticated users can sell and look up GCs.
      can %i[new create lookup], GiftCertificate
    end

    if user.is_a?(Admin)
      can :manage, User
      can :manage, [ TaxCode, Supplier, Category, Product, ProductGroup, Service, Customer, Report, ReceiptTemplate, DataImport ]
      can :read, GiftCertificate
      can :manage, [ Discount, DiscountItem ]
      # Admins can also void orders, process refunds, and view the full event audit trail.
      can %i[void refund_form process_refund receipt], Order
      can :read, OrderEvent
      can :read, Refund
      return
    end

    # Common users can update their own profile (via Profile, not Admin > Users).
    can %i[edit update], User, id: user.id if user.persisted?

    # Common users can read products, services, and customers.
    can %i[read search], [ Product, Service, Customer ] if user.persisted?

    # Common users can read discounts (for the register screen).
    can :read, Discount if user.persisted?

    # Common users can view and export reports, but not create or delete them.
    can %i[read export_pdf export_excel], Report if user.persisted?

    # Common users can view receipt templates (for printing receipts).
    can :read, ReceiptTemplate if user.persisted?

    # Common users can view receipts for completed orders.
    can :receipt, Order if user.persisted?
  end
end
