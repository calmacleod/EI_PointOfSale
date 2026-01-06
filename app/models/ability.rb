class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    if user.is_a?(Admin)
      can :manage, User
      return
    end

    # Authenticated users can view users.
    can :read, User if user.persisted?

    # Common users can only update themselves.
    can %i[edit update], User, id: user.id if user.persisted?
  end
end
