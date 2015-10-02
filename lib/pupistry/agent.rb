# rubocop:disable Style/GlobalVars
require 'rubygems'
require 'fileutils'
require 'rufus-scheduler'

# Pupistry::Agent
module Pupistry
  # Functions for running the Pupistry agent aka "apply mode" to actually
  # download and run Puppet against the contents of the artifact.
  class Agent
    ## Run as a daemon
    def self.daemon(options)
      # Since options comes from Thor, it can't be modified, so we need to
      # copy the options and then we can edit it.

      options_new = options.inject({}) do |new, (name, value)|
        new[name] = value
        new
      end

      # If the minimal mode has been enabled in config, respect.
      options_new[:minimal] = true if $config['agent']['daemon_minimal']

      # If no frequency supplied, use 300 seconds safe default.
      $config['agent']['daemon_frequency'] = 300 unless $config['agent']['daemon_frequency']

      # Use rufus-scheduler to run our apply job as a regularly scheduled job
      # but with build in locking handling.

      $logger.info "Launching daemon... frequency of #{$config['agent']['daemon_frequency']} seconds."

      begin

        scheduler = Rufus::Scheduler.new

        scheduler.every "#{$config['agent']['daemon_frequency']}s", :overlap => false, :timeout => '1d', :first_at => Time.now + 1 do
          $logger.info "Triggering another Pupistry run (#{$config['agent']['daemon_frequency']}s)"
          apply options_new
        end

        scheduler.join

      rescue Rufus::Scheduler::TimeoutError
        $logger.error 'A run of Pupistry timed out after 1 day as a safety measure. There may be a bug or a Puppet action causing it to get stuck'

      rescue SignalException
        # Clean shutdown signal (eg SIGTERM)
        $logger.info 'Clean shutdown of Pupistry daemon requests'
        exit 0

      rescue StandardError => e
        raise e
      end
    end

    def self.apply(options)
      ## Download and apply the latest artifact (if any)

      # Fetch artifact versions
      $logger.info 'Checking version of artifact available...'

      artifact = Pupistry::Artifact.new
      artifact.checksum = artifact.fetch_latest

      unless artifact.checksum
        $logger.error 'There is no current artifact available for download, no steps can be taken.'
        return false
      end

      artifact_installed = Pupistry::Artifact.new
      artifact_installed.checksum = artifact_installed.fetch_installed

      if artifact_installed.checksum
        $logger.debug "Currently on #{artifact_installed.checksum}"
      else
        $logger.debug 'No currently installed artifact - blank slate!'
      end

      # Download the new artifact if one has changed. If we already have this
      # version, then we should skip downloading and go straight to running
      # Puppet - unless the user runs with --force (eg to fix a corrupted
      # artifact).

      if artifact.checksum != artifact_installed.checksum || options[:force]
        $logger.warn 'Forcing download of latest artifact regardless of current one.' if options[:force]

        # Install the artifact
        $logger.info "Downloading latest artifact (#{artifact.checksum})..."

        artifact.fetch_artifact
        artifact.unpack

        unless artifact.install
          $logger.fatal 'An unexpected error happened when installing the latest artifact, cancelling Puppet run'
          return false
        end

        # Remove temporary unpacked files
        artifact.clean_unpack
      else
        $logger.info 'Already have latest artifact applied.'

        # By default we run Puppet even if we have the latest artifact. There's
        # some grounds for debate about whether this is the right thing - in some
        # ways it is often a waste of CPU, since if the artifact hasn't changed,
        # then it's unlikley anything else has changed.
        #
        # But that's not always 100% true - Puppet will undo local changes or
        # upgrade package versions (ensure => latest) if appropiate, so we should
        # act like the standard command and attempt to apply whatever we can.
        #
        # To provide users with options, we provide the --lazy parameter to avoid
        # running Puppet except when the artifact changes. By default, Puppet
        # runs every thing to avoid surprise.

        if options[:minimal]
          $logger.info 'Running with minimal effort mode enabled, not running Puppet since artifact version already applied'
          return false
        end

      end

      # Check if the requested environment/branch actually exists
      if options[:environment]
        environment = options[:environment]
      else
        environment = 'master'
      end

      unless File.directory?("#{$config['agent']['puppetcode']}/#{environment}")
        $logger.fatal "The requested branch/environment of #{environment} does not exist, unable to run Puppet"
        return false
      end

      # Execute Puppet.
      puppet_cmd = 'puppet apply'

      puppet_cmd += ' --noop' if options[:noop]
      puppet_cmd += ' --show_diff' if options[:verbose]

      puppet_cmd += " --environment #{environment}"
      puppet_cmd += " --confdir #{$config['agent']['puppetcode']}"
      puppet_cmd += " --environmentpath #{$config['agent']['puppetcode']}"
      puppet_cmd += " --modulepath #{$config['agent']['puppetcode']}/#{environment}/modules/"
      puppet_cmd += " --hiera_config #{$config['agent']['puppetcode']}/#{environment}/hiera.yaml"
      puppet_cmd += " #{$config['agent']['puppetcode']}/#{environment}/manifests/site.pp"

      $logger.info 'Executing Puppet...'
      $logger.debug "With: #{puppet_cmd}"

      $logger.error 'An unexpected issue occured when running puppet' unless system puppet_cmd
    end
  end
end

# vim:shiftwidth=2:tabstop=2:softtabstop=2:expandtab:smartindent
