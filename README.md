Heroku Rails SaaS
=============

Easier configuration and deployment of Rails apps on Heroku

Configure all your Heroku environments via a YML file (config/heroku.yml) that defines all your environments, addons, scaling settings and environment variables.
Configure your app specific Heroku environment via a YML file (config/heroku/awesomeapp.yml) thats defines all your environments, addons, scaling settings and environment variables for awesomeapp.

## Install

### Rails 3

Add this to your Gemfile:

    group :development do
      gem 'heroku-rails-saas'
    end

## Configure

In config/heroku.yml you will need add the Heroku apps that you would like to attach to this project. You can generate this file and edit it by running:

    rails generate heroku:config

If you want to defined more 

### Example Configuration File

For config ENV use 'DELETE' as a value to indicate you want it removed/unset.

For all configuration settings

    config:
      BUNDLE_WITHOUT: "test:development"
      CONFIG_VAR1: "config1"
      CONFIG_VAR2: "config2"

    # Be sure to add yourself as a collaborator, otherwise your
    # access to the app will be revoked.
    collaborators:
      - "my-heroku-email@somedomain.com"
      - "another-heroku-email@somedomain.com"

    addons:
      - scheduler:standard
      # add any other addons here

    scale:
      web: 1
      worker: 0

    formation:
      web: 1
      worker: 2

For an app specific settings awesomeapp

    apps:
      production: awesomeapp
      staging: awesomeapp-staging
      legacy: awesomeapp-legacy

    stacks:
      bamboo-mri-1.9.2

    production:
      CONFIG_VAR1: "config1-production"

    collaborators
      - "awesomeapp@somedomain.com"

    domains:
      production:
        - "awesomeapp.com"
        - "www.awesomeapp.com"

    production:
      - ssl:piggyback
      - cron:daily
      - newrelic:bronze

    scale:
      production:
        web: 3
        worker: 2
      staging:
        web: 2
        worker: 1

### Setting up Heroku

To set heroku up (using your heroku.yml), just run.

    rake all heroku:setup

This will create the heroku apps you have defined, and create the settings for each.

Run `rake <app_name>:<environment> heroku:setup` every time you edit the heroku.yml. It will only make incremental changes (based on what you've added/removed). If nothing has changed in the heroku.yml since the last `heroku:setup`, then no heroku changes will be sent.


## Usage

After configuring your Heroku apps you can use rake tasks to control the
apps.

    rake <app_name>:production heroku:deploy

A rake task with the shorthand name of each app is now available and adds that
server to the list that subsequent commands will execute on. Because this list
is additive, you can easily select which servers to run a command on.

    rake <app_name>:demo <app_name>:staging heroku:restart

Additionally all commands will be execute in parallel, this is done by forking the process for each 
heorku app.

A special rake task 'all' is created that causes any further commands to
execute on all heroku apps (Note: Any environment labeled `production` will not
be included, you must explicitly state it).

Furthermore there are rake task 'environments' created from environments in configs
that causes any further commands to execute on all heroku apps.

    rake all:production heroku:info

Need to add new config ENV variables across all apps?

    rake all heroku:setup:config

Need to add a new collaborator/team member across all apps?

    rake all heroku:setup:collaborators

A full list of tasks provided:

    rake all                        # Select all non Production Heroku apps for later command
    rake all:production             # Select all Production Heroku apps for later command

    rake heroku:deploy              # Deploys latest code, run heroku:setup, turns on maintenance, migrates, scale/restarts and turns off maintenance
    rake heroku:apps                # Lists configured apps
    rake heroku:info                # Queries the heroku status info on each app
    rake heroku:exec                # Execute command on the heroku app (e.g. rake task)
    rake heroku:command             # Execute command on the heroku app (e.g. rake task) 
    rake heroku:restart             # Restarts remote servers
    rake heroku:scale               # Scales heroku processes
    rake heroku:logs                # Shows the Heroku logs
    rake heorku:maintenance:on      # Turn maintenance on
    rake heorku:maintenance:off     # Turn maintenance off

    rake heroku:setup               # runs all heroku setup scripts
    rake heroku:setup:addons        # sets up the heroku addons
    rake heroku:setup:collaborators # sets up the heroku collaborators
    rake heroku:setup:config        # sets up the heroku config env variables
    rake heroku:setup:domains       # sets up the heroku domains
    rake heroku:setup:stacks        # sets the correct stack for each heroku app

    rake heroku:db:migrate          # Migrates and restarts remote servers

You can easily alias frequently used tasks within your application's Rakefile:

    task :deploy =>  ["heroku:deploy"]

With this in place, you can be a bit more terse:

    rake all deploy

### Sample Output

    rake v2:development v2:production heroku:setup

All output/response now are labeled with the heroku app name and a font color.
    
    Load heroku-rails-saas rake task
    [ v2-production ] Setting collaborators... 
    [ v2-dev ] Setting collaborators... 
    [ v2-dev ] Deleting collaborator(s):
    [ v2-dev ]  chris@synctv.com
    [ v2-dev ] Setting config... 
    [ v2-production ] Setting config... 
    [ v2-production ] Setting addons... 
    [ v2-dev ] Setting addons... 
    [ v2-production ] Deleting addon(s):
    [ v2-production ]   RandomAddon:dev
    [ v2-production ] Setting domains... 
    [ v2-dev ] Setting domains... 

### Deploy Hooks

You can easily hook into the deploy process by defining any of the following rake tasks.

When you ran `rails generate heroku:config`, it created a list of empty rake tasks within lib/tasks/heroku.rake.Edit these rake tasks to provide custom logic for before/after deployment.
Typically these are use to notify your monitoring service of a deployment or run one of rake task to update your database. 

    namespace :heroku do
      # runs before all the deploys complete
      task :before_deploy do

      end

      # runs before each push to a particular heroku deploy environment
      task :before_each_deploy do

      end

      # runs after each push to a particular heroku deploy environment
      task :after_each_deploy do

      end

      # runs after all the deploys complete
      task :after_deploy do

      end
    end


## About Heroku Rails SaaS

### Links

Homepage:: <https://github.com/darkbushido/heroku-rails-saas>

Issue Tracker:: <http://github.com/darkbushido/heroku-rails-saas/issues>

### Heroku Rails SaaS Contributors

* Lance Sanchez (lance.sanchez@gmail.com)
* Chris Trinh (chris.chtrinh@gmail.com)

### License

License:: Copyright (c) 2012 Lance Sanchez <lance.sanchez@gmail.com> released under the MIT license.

## Forked from Heroku Rails

Heroku Rails SaaS is a fork/extension for Heroku Rails to add the ability to manage multiple apps with multiple enviroments

### Heroku Rails Contributors

* Jacques Crocker (railsjedi@gmail.com)

### Heroku Rails License

License:: Copyright (c) 2010 Jacques Crocker <railsjedi@gmail.com>, released under the MIT license.

## Forked from Heroku Sans

Heroku Rails is a fork and rewrite/reorganiziation of the heroku_sans gem. Heroku Sans is a simple and elegant set of Rake tasks for managing Heroku environments. Check out that project here: <http://github.com/fastestforward/heroku_san>

### Heroku Sans Contributors

* Elijah Miller (elijah.miller@gmail.com)
* Glenn Roberts (glenn.roberts@siyelo.com)
* Damien Mathieu (42@dmathieu.com)

### Heroku Sans License

License:: Copyright (c) 2009 Elijah Miller <elijah.miller@gmail.com>, released under the MIT license.