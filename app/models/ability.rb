class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    if user.is_a?(Admin)
      can :manage, User
      can :manage, [ TaxCode, Supplier, Category, Product, ProductVariant, Service, Customer, Report ]
      return
    end

    # Common users can update their own profile (via Profile, not Admin > Users).
    can %i[edit update], User, id: user.id if user.persisted?

    # Common users can read products, services, and customers.
    can :read, [ Product, ProductVariant, Service, Customer ] if user.persisted?

    # Common users can view and export reports, but not create or delete them.
    can %i[read export_pdf export_excel], Report if user.persisted?
  end
end
