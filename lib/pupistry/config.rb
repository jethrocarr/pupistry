require 'rubygems'
require 'fileutils'
require 'tempfile'
require 'yaml'

module Pupistry
  # Pupistry::Config
  #
  # Provides loading of configuration.
  #

  class Config

    def self.load file
      $logger.debug "Loading configuration file #{file}"

      unless File.exists?(file)
        $logger.fatal "The configuration file provided does not exist, or cannot be accessed"
        exit 0
      end

      $config = YAML::load(File.open(file))

      # Make sure cache directory exists, create it otherwise
      $config["general"]["app_cache"] = File.expand_path($config["general"]["app_cache"]).chomp('/')

      unless Dir.exists?($config["general"]["app_cache"])
        begin
          FileUtils.mkdir_p($config["general"]["app_cache"])
          FileUtils.chmod(0700, $config["general"]["app_cache"]) # Generally only the user running Pupistry should have access
        rescue Exception => e
          $logger.fatal "Unable to create cache directory at \"#{$config["general"]["app_cache"]}\"."
          raise e
        end
      end

      # Write test file to confirm writability
      begin
        FileUtils.touch($config["general"]["app_cache"] + "/testfile")
        FileUtils.rm($config["general"]["app_cache"] + "/testfile")
      rescue Exception => e
        $logger.fatal "Unexpected exception when creating testfile in cache directory at \"#{$config["general"]["app_cache"]}\", is the directory writable?"
        raise e
      end

    end

    def self.find_and_load
      $logger.debug "Looking for configuration file in common locations"

      # If the HOME environmental hasn't been set (which can happen when
      # running via some cloud user-data/init systems) the app will die
      # horribly, we should set a HOME path default.
      unless ENV['HOME']
        $logger.warn "No HOME environmental set, defaulting to /tmp"
        ENV['HOME'] = "/tmp"
      end

      # Locations in order of preference:
      # settings.yaml (current dir)
      # ~/.pupistry/settings.yaml
      # /etc/pupistry/settings.yaml

      config    = ''
      local_dir = Dir.pwd

      if File.exists?("#{local_dir}/settings.yaml")
        config = "#{local_dir}/settings.yaml"

      elsif File.exists?( File.expand_path "~/.pupistry/settings.yaml" )
        config = File.expand_path "~/.pupistry/settings.yaml"

      elsif File.exists?("/usr/local/etc/pupistry/settings.yaml")
        config = "/usr/local/etc/pupistry/settings.yaml"

      elsif File.exists?("/etc/pupistry/settings.yaml")
        config = "/etc/pupistry/settings.yaml"

      else
        $logger.error "No configuration file provided."
        $logger.error "See pupistry help for information on configuration"
        exit 0
      end

      self.load(config)

    end


  end
end
# vim:shiftwidth=2:tabstop=2:softtabstop=2:expandtab:smartindent
