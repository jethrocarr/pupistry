require 'rubygems'
require 'yaml'
require 'time'
require 'digest'
require 'fileutils'

module Pupistry
  # Pupistry::Artifact

  class Artifact
    # All the functions needed for manipulating the artifats
    attr_accessor :checksum


    def fetch_r10k
      $logger.info "Using r10k utility to fetch the latest Puppet code"

      unless defined? $config["build"]["puppetcode"]
        $logger.fatal "You must configure the build:puppetcode config option in settings.yaml"
        raise "Invalid Configuration"
      end

      # https://github.com/puppetlabs/r10k
      #
      # r10k does a fantastic job with all the git stuff and we want to use it
      # to download the Puppet code from all the git modules (based on following
      # the master one provided), then we can steal the Puppet code from the
      # artifact generated.
      #
      # TODO: We should re-write this to hook directly into r10k's libraries,
      # given that both Pupistry and r10k are Ruby, presumably it should be
      # doable and much more polished approach. For now the MVP is to just run
      # it via system, pull requests/patches to fix very welcome!


      # Build the r10k config to instruct it to use our cache path for storing
      # it's data and exporting the finished result.
      $logger.debug "Generating an r10k configuration file..."
      r10k_config = {
        "cachedir" => "#{$config["general"]["app_cache"]}/r10kcache",
        "sources"  => {
          "puppet" => {
            "remote"  => $config["build"]["puppetcode"],
            "basedir" => $config["general"]["app_cache"] + "/puppetcode",
          }
        }
      }

      begin
        File.open("#{$config["general"]["app_cache"]}/r10kconfig.yaml",'w') do |fh|
          fh.write YAML::dump(r10k_config)
        end
      rescue Exception => e
        $logger.fatal "Unexpected error when trying to write the r10k configuration file"
        raise e
      end

      
      # Execute R10k with the provided configuration
      $logger.debug "Executing r10k"

      if system "r10k deploy environment -c #{$config["general"]["app_cache"]}/r10kconfig.yaml -pv"
        $logger.info "r10k run completed"
      else
        $logger.error "r10k run failed, unable to generate artifact"
        raise "r10k run did not complete, unable to generate artifact"
      end

    end

    def fetch_latest
      # Fetch the latest S3 YAML file and check the version metadata without writing
      # it to disk. Returns the version. Useful for quickly checking for updates :-)

      $logger.debug "Checking latest artifact version..."

      s3        = Pupistry::Storage_AWS.new 'agent'
      contents  = s3.download 'manifest.latest.yaml'

      if contents
        manifest = YAML::load(contents)

        if defined? manifest['version']
          return manifest['version']
        else
          return false
        end

      else
        # download did not work
        return false
      end


    end


    def fetch_current
      # Fetch the latest on-disk YAML file and check the version metadata, used
      # to determine the latest artifact that has not yet been pushed to S3.
      # Returns the version.

      # Read the symlink information to get the latest version
      if File.exists?($config["general"]["app_cache"] + "/artifacts/manifest.latest.yaml")
          manifest    = YAML::load(File.open($config["general"]["app_cache"] + "/artifacts/manifest.latest.yaml"))
          @checksum   = manifest['version']
        else
          $logger.error "No artifact has been built yet. You need to run pupistry build first?"
          return 0
        end
    end


    def fetch_artifact

      # Figure out which version to fetch (if not explicitly defined)
      if defined? @checksum
        $logger.debug "Downloading artifact version #{@checksum}"
      else
        @checksum = fetch_latest

        if defined? @checksum
          $logger.debug "Downloading latest artifact (#{@checksum})"
        else
          $logger.error "There is not current artifact that can be fetched"
          return false
        end

      end

      # Download files if they don't already exist
      if File.exists?($config["general"]["app_cache"] + "/artifacts/manifest.#{@checksum}.yaml") and File.exists?($config["general"]["app_cache"] + "/artifacts/artifact.#{@checksum}.tar.gz")
        $logger.debug "This artifact is already present, no download required."
      else
        s3 = Pupistry::Storage_AWS.new 'agent'
        s3.download "manifest.#{@checksum}.yaml", $config["general"]["app_cache"] + "/artifacts/manifest.#{@checksum}.yaml"
        s3.download "artifact.#{@checksum}.tar.gz", $config["general"]["app_cache"] + "/artifacts/artifact.#{@checksum}.tar.gz"
      end

    end



    def push_artifact
      # The push step involves 2 steps:
      # 1. GPG sign the artifact and write it into the manifest file
      # 2. Upload the manifest and archive files to S3.
      # 3. Upload a copy as the "latest" manifest file which will be hit by clients.


      # Determine which version we are uploading. Either one specifically
      # selected, otherwise find the latest one to push

      if defined? @checksum
        $logger.info "Uploading artifact version #{@checksum}."
      else
        @checksum = fetch_current

        if @checksum
          $logger.info "Uploading artifact version latest (#{@checksum})"
        else
          # If there is no current version, we can't do much....
          exit 0
        end
      end


      # Do we even need to upload? If nothing has changed....
      if @checksum == fetch_latest
        $logger.error "You've already pushed this artifact version, nothing to do."
        exit 0
      end


      # Make sure the files actually exist...
      unless File.exists?($config["general"]["app_cache"] + "/artifacts/manifest.#{@checksum}.yaml")
        $logger.error "The files expected for #{@checksum} do not appear to exist or are not readable"
        raise "Fatal unexpected error"
      end

      unless File.exists?($config["general"]["app_cache"] + "/artifacts/artifact.#{@checksum}.tar.gz")
        $logger.error "The files expected for #{@checksum} do not appear to exist or are not readable"
        raise "Fatal unexpected error"
      end


      # GPG sign the files
      if $config["general"]["gpg_disable"] == true
        $logger.warn "You have GPG signing *disabled*, whilst not critical it does weaken your security."
        $logger.warn "Skipping signing step..."
      else
        $logger.info "GPG signing the artifact with configured key"

        # TODO: should probably write this bit!
      end


      # Upload the artifact & manifests to S3. We also make an additional copy 
      # as the "latest" file which will be downloaded by all the agents checking
      # for new updates.

      s3 = Pupistry::Storage_AWS.new 'build'
      s3.upload $config["general"]["app_cache"] + "/artifacts/artifact.#{@checksum}.tar.gz", "artifact.#{@checksum}.tar.gz"
      s3.upload $config["general"]["app_cache"] + "/artifacts/manifest.#{@checksum}.yaml", "manifest.#{@checksum}.yaml"
      s3.upload $config["general"]["app_cache"] + "/artifacts/manifest.#{@checksum}.yaml", "manifest.latest.yaml"


      # Test a read of the manifest, we do this to make sure the S3 ACLs setup
      # allow downloading of the uploaded files - helps avoid user headaches if
      # they misconfigure and then blindly trust their bootstrap config.
      #
      # Only worth doing this step if they've explicitly set their AWS IAM credentials
      # for the agent, which should be everyone except for IAM role users.

      if $config["agent"]["aws_access_id"]
        fetch_artifact
      else
        $logger.warn "The agent's AWS credentials are unset on this machine, unable to do download test to check permissions for you."
        $logger.warn "Assuming you know what you're doing, please set if unsure."
      end

      $logger.info "Upload of artifact version #{@checksum} completed and is now latest"
    end
    

    def build_artifact
      # r10k has done all the heavy lifting for us, we just need to generate a
      # tarball from the app_cache /puppetcode directory. There are some Ruby
      # native libraries, but really we might as well just use the native tools
      # since we don't want to do anything clever like in-memory assembly of
      # the file. Like r10k, if you want to convert to a nicely polished native
      # Ruby solution, patches welcome.

      $logger.info "Creating artifact..."

      Dir.chdir($config["general"]["app_cache"]) do

        # Make sure there is a directory to write artifacts into
        FileUtils.mkdir_p('artifacts')

        # Build the tar file - we delibertly don't compress in a single step
        # so that we can grab the checksum, since checksum will always differ
        # post-compression.
        unless system "tar -c --exclude '.git' -f artifacts/artifact.temp.tar puppetcode/*"
          $logger.error "Unable to create tarball"
          raise "An unexpected error occured when executing tar"
        end

        # The checksum is important, we use it as our version for each artifact
        # so we can tell them apart in a unique way.
        @checksum = Digest::MD5.file($config["general"]["app_cache"] + "/artifacts/artifact.temp.tar").hexdigest

        # Now we have the checksum, check if it's the same as any existing
        # artifacts. If so, drop out here, good to give feedback to the user
        # if nothing has changed since it's easy to forget to git push a single
        # module/change.

        if File.exists?($config["general"]["app_cache"] + "/artifacts/manifest.#{@checksum}.yaml")
          $logger.error "This artifact version (#{@checksum}) has already been built, nothing todo."
          $logger.error "Did you remember to \"git push\" your module changes?"

          # Cleanup temp file
          FileUtils.rm($config["general"]["app_cache"] + "/artifacts/artifact.temp.tar")
          exit 0
        end

        # Compress the artifact now that we have taken it's checksum
        $logger.info "Compressing artifact..."

        if system "gzip artifacts/artifact.temp.tar"
        else
          $logger.error "An unexpected error occured during compression of the artifact"
          raise "An unexpected error occured during compression of the artifact"
        end
      end


      # We have the checksum, so we can now rename the artifact file
      FileUtils.mv($config["general"]["app_cache"] + "/artifacts/artifact.temp.tar.gz", $config["general"]["app_cache"] + "/artifacts/artifact.#{@checksum}.tar.gz")


      $logger.info "Building manifest information for artifact..."

      # Create the manifest file, this is used by clients for pulling details about
      # the latest artifacts. We don't GPG sign here, but we do put in a placeholder.
      manifest = {
        "version"   => @checksum, 
        "date"      => Time.new.inspect,
        "builduser" => ENV['USER'] || 'unlabled',
        "gpgsig"    => 'unsighed',
      }

      begin
        File.open("#{$config["general"]["app_cache"]}/artifacts/manifest.#{@checksum}.yaml",'w') do |fh|
          fh.write YAML::dump(manifest)
        end
      rescue Exception => e
        $logger.fatal "Unexpected error when trying to write the manifest file"
        raise e
      end

      # This is the latest artifact, create some symlinks pointing the latest to it
      begin
        FileUtils.ln_s("manifest.#{@checksum}.yaml", "#{$config["general"]["app_cache"]}/artifacts/manifest.latest.yaml", :force => true)
        FileUtils.ln_s("artifact.#{@checksum}.tar.gz",  "#{$config["general"]["app_cache"]}/artifacts/artifact.latest.tar.gz",  :force => true)
      rescue Exception => e
        $logger.fatal "Something weird went really wrong trying to symlink the latest artifacts"
        raise e
      end


      $logger.info "New artifact version #{@checksum} ready for pushing"
    end


    def unpack
      # Unpack the currently selected artifact to the archives directory.
    
      # An application version must be specified
      unless defined? @checksum
        raise "Application bug, trying to unpack no artifact"
      end

      # Make sure the files actually exist...
      unless File.exists?($config["general"]["app_cache"] + "/artifacts/manifest.#{@checksum}.yaml")
        $logger.error "The files expected for #{@checksum} do not appear to exist or are not readable"
        raise "Fatal unexpected error"
      end

      unless File.exists?($config["general"]["app_cache"] + "/artifacts/artifact.#{@checksum}.tar.gz")
        $logger.error "The files expected for #{@checksum} do not appear to exist or are not readable"
        raise "Fatal unexpected error"
      end

      # Clean up an existing unpacked copy - in *theory* it should be same, but
      # a mistake like running out of disk could have left it in an unclean state
      # so let's make sure it's gone
      clean_unpack


      # Unpack the archive file
      FileUtils.mkdir_p($config["general"]["app_cache"] + "/artifacts/unpacked.#{@checksum}")
      Dir.chdir($config["general"]["app_cache"] + "/artifacts/unpacked.#{@checksum}") do

        unless system "tar -xf ../artifact.#{@checksum}.tar.gz"
          $logger.error "Unable to unpack artifact files to #{Dir.pwd}"
          raise "An unexpected error occured when executing tar"
        else
          $logger.debug "Successfully unpacked artifact #{@checksum}"
        end
      end

    end


    def clean_unpack
      # Cleanup/remove any unpacked archive directories. Requires that the
      # checksum be set to the version to be purged.

      unless defined? @checksum
        raise "Application bug, trying to unpack no artifact"
      end

      if Dir.exists?($config["general"]["app_cache"] + "/artifacts/unpacked.#{@checksum}/")
        $logger.debug "Cleaning up #{$config["general"]["app_cache"]}/artifacts/unpacked.#{@checksum}..."
        FileUtils.rm_r $config["general"]["app_cache"] + "/artifacts/unpacked.#{@checksum}", :secure => true
      else
        $logger.debug "Nothing to cleanup (selected artifact is not currently unpacked)"
      end

    end

  end
end

# vim:shiftwidth=2:tabstop=2:softtabstop=2:expandtab:smartindent
