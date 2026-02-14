class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    if user.is_a?(Admin)
      can :manage, User
      can :manage, [ TaxCode, Supplier, Category, Product, ProductVariant, Service, Customer ]
      return
    end

    # Authenticated users can view users.
    can :read, User if user.persisted?

    # Common users can only update themselves.
    can %i[edit update], User, id: user.id if user.persisted?

    # Common users can read products, services, and customers.
    can :read, [ Product, ProductVariant, Service, Customer ] if user.persisted?
  end
end
