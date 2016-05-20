
namespace :deploy do

  desc 'Composer install'
  task :composer do
    set :do_composer, ask('¿Want to do composer install (drupal)?:y/n','y')
    if fetch(:do_composer)=='y'
      #SSHKit.config.command_map[:composer] = "#{shared_path.join("composer.phar")}"
      on roles(:web) do
        within release_path.join(fetch(:app_path)) do
          execute :composer, 'install --prefer-dist --no-interaction --quiet --optimize-autoloader'
          execute :rm, "-rf ../../../shared/#{(fetch(:app_path))}/core  ../../../shared/#{(fetch(:app_path))}/vendor"
          #COPIAMOS PARA PROXIMOS DEPLOYS
          execute :cp, "-a core vendor ../../../shared/#{(fetch(:app_path))}"
        end
      end
    else
      on roles(:web) do
        within release_path.join(fetch(:app_path)) do
          execute :cp, "-a ../../../shared/#{(fetch(:app_path))}/core ../../../shared/#{(fetch(:app_path))}/vendor ."
        end
      end
    end
  end

end

# Specific Drupal tasks
namespace :drupal do

  desc "Restore MySQL Database"
  task :mysqlrestore, :roles => :app do
    backups = capture("ls -1 #{(fetch(:deploy_to))}/backups/").split("\n")
    default_backup = backups.last
    puts "Available backups: "
    puts backups
    backup = Capistrano::CLI.ui.ask "Which backup would you like to restore? [#{default_backup}] "
    backup_file = default_backup if backup.empty?
    within release_path.join(fetch(:app_path)) do
      set :mysql_connect, capture(:drush,'sql-connect')
    end
    execute("zcat #{fetch(:deploy_to)}/backups/#{fetch(:last_db_dump)} | #{fetch(:mysql_connect)}")
    ##run "#{fetch(:mysql_connect)} < #{(fetch(:deploy_to))}/backups/#{backup_file}"
  end


  desc 'Create database dump'
  task :dump do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        if not test "[ -d #{(fetch(:deploy_to))}/backups ]"
          execute :mkdir, "#{(fetch(:deploy_to))}/backups"
        end
        execute :drush, "sql-dump --result-file=#{(fetch(:deploy_to))}/backups/#{release_name}.sql --gzip"
      end
    end
  end

  desc 'Download database dump'
  task :dump_dl do
    on release_roles :app do |server|
      within release_path.join(fetch(:app_path)) do
        if not test "[ -d #{(fetch(:deploy_to))}/backups ]"
          execute :mkdir, "#{(fetch(:deploy_to))}/backups"
        end
        set :last_release, capture("ls -Art #{fetch(:deploy_to)}/releases/ | tail -n 1")
        execute :drush, "sql-dump --result-file=#{(fetch(:deploy_to))}/backups/#{fetch(:last_release)}.sql --gzip"
        system("scp -P2022  #{server.user}@#{server.hostname}:#{(fetch(:deploy_to))}/backups/#{fetch(:last_release)}.sql.gz .")
        output = %x[cd #{(fetch(:app_path))} && drush sql-connect]
        system("zcat #{fetch(:last_release)}.sql.gz | "+ output);
        system("rm #{fetch(:last_release)}.sql.gz")
      end
    end
  end

  desc 'Revert database dump'
  task :revertdump do
    on roles(:db) do
      set :do_revert, ask('¿Want to do revert database?:y/n','n')
      if fetch(:do_revert)=='y'
        invoke 'drupal:mysqlrestore'
      end
    end
  end

  desc 'Run any drush command!'
  task :drush do
    ask(:drush_command, "Drush command you want to run (eg. 'cache-clear css-js'). Type 'help' to have a list of avaible drush commands.")
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, fetch(:drush_command)
      end
    end
  end

  desc 'Show logs'
  task :logs do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, 'watchdog-show  --tail'
      end
    end
  end

  desc 'Provides information about things that may be wrong in your Drupal installation, if any.'
  task :requirements do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, 'core-requirements'
      end
    end
  end

  desc 'Open an interactive shell on a Drupal site.'
  task :cli do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, 'core-cli'
      end
    end
  end

  desc 'Set the site offline'
  task :site_offline do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, 'vset maintenance_mode 1 -y'
      end
    end
  end

  desc 'Set the site online'
  task :site_online do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, 'vset maintenance_mode 0 -y'
      end
    end
  end

  desc 'Revert feature'
  task :feature_revert do
    on roles(:app) do
      within release_path.join(fetch(:app_path)) do
        execute :drush, 'features-revert-all -y'
      end
    end
  end

  namespace :update do
    desc 'List any pending database updates.'
    task :updatedb_status do
      on roles(:app) do
        within release_path.join(fetch(:app_path)) do
          execute :drush, 'updatedb-status'
        end
      end
    end

    desc 'Apply any database updates required (as with running update.php).'
    task :updatedb do
      on roles(:app) do
        within release_path.join(fetch(:app_path)) do
          execute :drush, 'updatedb -y'
        end
      end
    end

    desc 'Show a report of available minor updates to Drupal core and contrib projects.'
    task :pm_updatestatus do
      on roles(:app) do
        within release_path.join(fetch(:app_path)) do
          execute :drush, 'pm-updatestatus'
        end
      end
    end
  end

  namespace :cache do
    desc 'Clear all caches'
    task :clear do
      on roles(:app) do
        within release_path.join(fetch(:app_path)) do
          execute :drush, 'cr'
        end
      end
    end
  end

  namespace :config do

    desc 'Export config to (local)config/local dir and merge with config/drupal'
    task :export do
      run_locally do
        SSHKit.config.command_map[:config_compare] = "../config_compare.sh"
        within fetch(:app_path) do
          execute :drush, 'config-export --destination=../config/local -y'
          ##execute :config_compare
          #system("../config_compare.sh")
        end
      end
    end

    desc 'Import config to (local)database'
    task :import do
      run_locally do
        within fetch(:app_path) do
          execute :drush, 'config-import --source=../config/drupal -y'
        end
      end
    end

    desc 'Import config to (remote)database'
    task :remote_import do
      on roles(:app) do
        within release_path.join(fetch(:app_path)) do
          execute :drush, 'config-import --source=../config/drupal -y'
        end
      end
    end

  end

end

namespace :files do

  desc "Download drupal sites files (from remote to local)"
  task :download do
    run_locally do
      on release_roles :app do |server|
        ask(:answer, "Do you really want to download the files on the server to your local files? Nothings will be deleted but files can be ovewrite. (y/N)");
        if fetch(:answer) == 'y' then
          remote_files_dir = "#{shared_path}/#{(fetch(:app_path))}/sites/default/files/"
          local_files_dir = "#{(fetch(:app_path))}/sites/default/files/"
          system("rsync --recursive --times --rsh=ssh --human-readable --progress --exclude='.*' --exclude='css' --exclude='js' #{server.user}@#{server.hostname}:#{remote_files_dir} #{local_files_dir}")
        end
      end
    end
  end

  desc "Upload drupal sites files (from local to remote)"
  task :upload do
    on release_roles :app do |server|
      ask(:answer, "Do you really want to upload your local files to the server? Nothings will be deleted but files can be ovewrite. (y/N)");
      if fetch(:answer) == 'y' then
        remote_files_dir = "#{shared_path}/#{(fetch(:app_path))}/sites/default/files/"
        local_files_dir = "#{(fetch(:app_path))}/sites/default/files/"
        system("rsync --recursive --times --rsh=ssh --human-readable --progress --exclude='.*' --exclude='css' --exclude='js' #{local_files_dir} #{server.user}@#{server.hostname}:#{remote_files_dir}")
      end
    end
  end

  desc "Fix drupal upload files folder permission"
  task :fix_permission do
    on roles(:app) do
      remote_files_dir = "#{shared_path}/#{(fetch(:app_path))}/sites/default/files/*"
      execute :chgrp, "-R www-data #{remote_files_dir}"
      execute :chmod, "-R g+w #{remote_files_dir}"
    end
  end

end
