class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "no-reply@pos.callummacleod.ca") }
  layout "mailer"
end
