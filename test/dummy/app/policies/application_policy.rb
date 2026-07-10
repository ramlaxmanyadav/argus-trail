class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = user&.admin?
  def show? = user&.admin?
  def create? = user&.admin?
  def new? = create?
  def update? = user&.admin?
  def edit? = update?
  def destroy? = user&.admin?

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end
end
