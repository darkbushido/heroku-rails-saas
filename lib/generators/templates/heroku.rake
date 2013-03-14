# ### Shortcuts: uncomment these for easier to type deployments
# ### e.g. rake deploy (instead of rake heroku:deploy)
# ###
# task :deploy =>  ["heroku:deploy"]
# task :console => ["heroku:console"]
# task :setup =>   ["heroku:setup"]
# task :logs =>    ["heroku:logs"]
# task :restart => ["heroku:restart"]

# Heroku Deploy Callbacks
namespace :heroku do
  # Runs before all the deploys complete.
  task :before_deploy do
  end

  # Runs before each push to a particular heroku deploy environment.
  task :before_each_deploy, [:local_name, :remote_name, :configs] => :environment do |t, args|
  end

  # Runs every time there is heroku deploy regardless of exceptions/failures.
  task :ensure_each_deploy, [:local_name, :remote_name, :configs] => :environment do |t, args|
  end

  # Runs after each push to a particular heroku deploy environment
  task :after_each_deploy, [:local_name, :remote_name, :configs] => :environment do |t, args|
  end

  # Runs after all the deploys complete
  task :after_deploy do
  end

  # Callback for when we switch environment
  task :switch_environment do
  end
end