class Common < User
  # STI: share routes/forms with User (so form_with uses user_path, not common_path)
  def self.model_name
    User.model_name
  end
end
