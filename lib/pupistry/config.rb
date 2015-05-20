# rubocop:disable Style/Documentation, Style/GlobalVars
require 'rubygems'
require 'fileutils'
require 'tempfile'
require 'yaml'
require 'safe_yaml'

module Pupistry
  # Pupistry::Config
  #
  # Provides loading of configuration.
  #

  class Config
    def self.load(file)
      $logger.debug "Loading configuration file #{file}"
     
      # Load YAML file with minimum safety/basic checks
      unless File.exist?(file)
        $logger.fatal 'The configuration file provided does not exist, or cannot be accessed'
        exit 0
      end

      begin
        $config = YAML.load(File.open(file), safe: true, raise_on_unknown_tag: true)
      rescue Exception => ex
        $logger.fatal "The supplied file is not a valid YAML configuration file"
        $logger.debug ex.message
        exit 0
      end


      # Run checks for minimum configuration parameters
      # TODO: Is there a smarter way of doing this? Maybe a better config parser?
      begin
        fail "Missing general:app_cache"         unless defined? $config['general']['app_cache']
        fail "Missing general:s3_bucket"         unless defined? $config['general']['s3_bucket']
        fail "Missing general:gpg_disable"       unless defined? $config['general']['gpg_disable']
        fail "Missing agent:puppetcode"          unless defined? $config['agent']['puppetcode']
      rescue => ex
        $logger.fatal "The supplied configuration files doesn't include the minimum expect configuration parameters"
        $logger.debug ex.message
        exit 0
      end

      

      # Make sure cache directory exists, create it otherwise
      $config['general']['app_cache'] = File.expand_path($config['general']['app_cache']).chomp('/')

      unless Dir.exist?($config['general']['app_cache'])
        begin
          FileUtils.mkdir_p($config['general']['app_cache'])
          FileUtils.chmod(0700, $config['general']['app_cache']) # Generally only the user running Pupistry should have access
        rescue StandardError => e
          $logger.fatal "Unable to create cache directory at \"#{$config['general']['app_cache']}\"."
          raise e
        end
      end

      # Write test file to confirm writability
      begin
        FileUtils.touch($config['general']['app_cache'] + '/testfile')
        FileUtils.rm($config['general']['app_cache'] + '/testfile')
      rescue StandardError => e
        $logger.fatal "Unexpected exception when creating testfile in cache directory at \"#{$config['general']['app_cache']}\", is the directory writable?"
        raise e
      end
    end

    def self.find_and_load
      $logger.debug 'Looking for configuration file in common locations'

      # If the HOME environmental hasn't been set (which can happen when
      # running via some cloud user-data/init systems) the app will die
      # horribly, we should set a HOME path default.
      unless ENV['HOME']
        $logger.warn 'No HOME environmental set, defaulting to /tmp'
        ENV['HOME'] = '/tmp'
      end

      # Locations in order of preference:
      # settings.yaml (current dir)
      # ~/.pupistry/settings.yaml
      # /etc/pupistry/settings.yaml

      config    = ''
      local_dir = Dir.pwd

      if File.exist?("#{local_dir}/settings.yaml")
        config = "#{local_dir}/settings.yaml"

      elsif File.exist?(File.expand_path '~/.pupistry/settings.yaml')
        config = File.expand_path '~/.pupistry/settings.yaml'

      elsif File.exist?('/usr/local/etc/pupistry/settings.yaml')
        config = '/usr/local/etc/pupistry/settings.yaml'

      elsif File.exist?('/etc/pupistry/settings.yaml')
        config = '/etc/pupistry/settings.yaml'

      else
        $logger.error 'No configuration file provided.'
        $logger.error 'See pupistry help for information on configuration'
        exit 0
      end

      load(config)
    end
  end
end
# vim:shiftwidth=2:tabstop=2:softtabstop=2:expandtab:smartindent
