require "bundler/capistrano"

server "169.237.120.176", :web, :app, :db, primary: true

set :application, "chekhov"
set :url, "http://chekhov.dss.ucdavis.edu/"
set :user, "deployer"
set :deploy_to, "/home/#{user}/apps/#{application}"
set :deploy_via, :remote_cache
set :use_sudo, false

set :scm, "git"
set :repository, "git@github.com:cthielen/#{application}.git"
set :branch, "master"

set :test_log, "log/capistrano.test.log"

default_run_options[:pty] = true
ssh_options[:forward_agent] = true

after "deploy", "deploy:cleanup" # keep only the last 5 releases
#after "deploy", "deploy:migrations" # run any pending migrations
after "deploy:update_code", "deploy:migrate"

namespace :deploy do
  before 'deploy' do
    puts "--> Running tests, please wait ..."
    unless system "bundle exec rake > #{test_log} 2>&1" #' > /dev/null'
      puts "--> Tests failed. Run `cat #{test_log}` to see what went wrong."
      exit
    else
      puts "--> Tests passed"
      system "rm #{test_log}"
    end
  end

  desc "Restart Passenger server"
  task :restart, roles: :app, except: {no_release: true} do
    run "touch #{current_path}/tmp/restart.txt"
  end

  desc "First-time config setup"
  task :setup_config, roles: :app do
    run "mkdir -p #{shared_path}/config"
    put File.read("config/database.example.yml"), "#{shared_path}/config/database.yml"
    put File.read("config/dss_rm.example.yml"), "#{shared_path}/config/dss_rm.yml"
    put File.read("config/sysaid.example.yml"), "#{shared_path}/config/sysaid.yml"
    puts "Now edit the config files in #{shared_path}."
  end
  after "deploy:setup", "deploy:setup_config"

  desc "Symlink config from shared to the newly deployed copy"
  task :symlink_config, roles: :app do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    run "ln -nfs #{shared_path}/config/dss_rm.yml #{release_path}/config/dss_rm.yml"
    run "ln -nfs #{shared_path}/config/sysaid.yml #{release_path}/config/sysaid.yml"
  end
  after "deploy:finalize_update", "deploy:symlink_config"

  desc "Make sure local git is in sync with remote."
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end
  before "deploy", "deploy:check_revision"
end