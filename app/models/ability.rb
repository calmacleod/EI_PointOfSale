class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    # All authenticated users can manage their own notifications and push subscriptions.
    if user.persisted?
      can :manage, Notification, user_id: user.id
      can :manage, PushSubscription, user_id: user.id
      can :manage, CashDrawerSession
    end

    if user.is_a?(Admin)
      can :manage, User
      can :manage, [ TaxCode, Supplier, Category, Product, ProductGroup, Service, Customer, Report, ReceiptTemplate, DataImport ]
      return
    end

    # Common users can update their own profile (via Profile, not Admin > Users).
    can %i[edit update], User, id: user.id if user.persisted?

    # Common users can read products, services, and customers.
    can :read, [ Product, Service, Customer ] if user.persisted?

    # Common users can view and export reports, but not create or delete them.
    can %i[read export_pdf export_excel], Report if user.persisted?

    # Common users can view receipt templates (for printing receipts).
    can :read, ReceiptTemplate if user.persisted?
  end
end
