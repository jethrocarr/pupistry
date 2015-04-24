require 'rubygems'
require 'yaml'
require 'fileutils'
require 'base64'

module Pupistry
  # Pupistry::Agent

  class Agent
    # Functions for running the Pupistry agent aka "apply mode" to actually
    # download and run Puppet against the contents of the artifact.

    def self.apply options
      ## Download and apply the latest artifact (if any)

      # Fetch artifact versions
      $logger.info "Checking version of artifact available..."

      artifact = Pupistry::Artifact.new
      artifact.checksum = artifact.fetch_latest

      unless artifact.checksum
        $logger.error "There is no current artifact available for download, no steps can be taken."
        exit 0
      end

      artifact_installed = Pupistry::Artifact.new
      artifact_installed.checksum = artifact_installed.fetch_installed

      if artifact_installed.checksum
        $logger.debug "Currently on #{artifact_installed.checksum}"
      else
        $logger.debug "No currently installed artifact - blank slate!"
      end

      # Download the new artifact if one has changed. If we already have this
      # version, then we should skip downloading and go straight to running
      # Puppet - unless the user runs with --force (eg to fix a corrupted
      # artifact).
      
      if artifact.checksum != artifact_installed.checksum or options[:force]
        if options[:force]
          $logger.warn "Forcing download of latest artifact regardless of current one."
        end

        # Install the artifact
        $logger.info "Downloading latest artifact (#{artifact.checksum})..."

        artifact.fetch_artifact
        artifact.unpack

        unless artifact.install
          $logger.fatal "An unexpected error happened when installing the latest artifact, cancelling Puppet run"
          exit 0
        end

        # Remove temporary unpacked files
        artifact.clean_unpack
      else
        $logger.info "Already have latest artifact applied."

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
          $logger.info "Running with minimal effort mode enabled, not running Puppet since artifact version already applied"
          exit 0
        end

      end

      # Check if the requested environment/branch actually exists
      if options[:environment]
        environment = options[:environment]
      else
        environment = 'master'
      end

      unless Dir.exists?("#{$config["agent"]["puppetcode"]}/#{environment}")
        $logger.fatal "The requested branch/environment of #{environment} does not exist, unable to run Puppet"
        exit 0
      end


      # Execute Puppet.
      puppet_cmd = "puppet apply"

      if options[:noop]
        puppet_cmd += " --noop"
      end

      puppet_cmd += " --environment #{environment}"
      puppet_cmd += " --modulepath #{$config["agent"]["puppetcode"]}/#{environment}/modules/"
      puppet_cmd += " --hiera_config #{$config["agent"]["puppetcode"]}/#{environment}/hiera.yaml"
      puppet_cmd += " #{$config["agent"]["puppetcode"]}/#{environment}/manifests/site.pp"

      $logger.info "Executing Puppet..."
      $logger.debug "With: #{puppet_cmd}"

      unless system puppet_cmd
        $logger.fatal "An unexpected issue occured when running puppet"
      end

    end

  end 
end

# vim:shiftwidth=2:tabstop=2:softtabstop=2:expandtab:smartindent
