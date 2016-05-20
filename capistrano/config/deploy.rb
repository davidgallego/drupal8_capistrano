# config valid only for current version of Capistrano
lock '3.5.0'

#Set the application Name
set :application, 'app_name'
#Set the repository url, format: git@example.com:path/to/repo/reponame.git
set :repo_url, 'git@example.com:path/to/repo/reponame.git'

# Path to the drupal directory, default to app.
set :app_path,        "/path/to/drupal/dir"

# Default value for :linked_files is []
set :linked_files, fetch(:linked_files, []).push("#{fetch(:app_path)}/sites/default/settings.local.php")

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push("#{fetch(:app_path)}/sites/default/files", "#{fetch(:app_path)}/private-files")

#Composer and drush need to be mapped

# Remove default composer install task on deploy:updated
Rake::Task['deploy:updated'].prerequisites.delete('composer:install')
Rake::Task['deploy:reverted'].prerequisites.delete('composer:install')

# Map composer and drush commands
# NOTE: If stage have different deploy_to
# you have to copy those line for each <stage_name>.rb
# See https://github.com/capistrano/composer/issues/22

SSHKit.config.command_map[:drush] = "drush"
SSHKit.config.command_map[:composer] = "composer"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 3

after 'deploy:updated', 'deploy:composer'
after 'deploy:updated', 'drupal:dump'
after 'drupal:dump', 'drupal:config:remote_import'
after 'drupal:config:remote_import', 'drupal:update:updatedb'
after 'deploy:reverted', 'drupal:revertdump'

namespace :deploy do

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

end
