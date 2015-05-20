# rubocop:disable Style/Documentation, Style/GlobalVars
require 'rubygems'
require 'yaml'
require 'safe_yaml'
require 'fileutils'
require 'base64'

module Pupistry
  # Pupistry::GPG

  class GPG
    # All the functions needed for manipulating the GPG signatures
    attr_accessor :checksum
    attr_accessor :signature

    def initialize(checksum)
      # Need a checksum to do signing for
      if checksum
        @checksum = checksum
      else
        $logger.fatal 'Probable bug, need a checksum provided with GPG validation'
        exit 0
      end

      # Make sure that we have GPG available
      unless system('gpg --version >> /dev/null 2>&1') # rubocop:disable Style/GuardClause
        $logger.fatal "'gpg' command is not available, unable to do any signature creation or verification."
        exit 0
      end
    end

    # Sign the artifact and return the signature. Does not validation of the signature.
    #
    # false   Failure
    # base64  Encoded signature
    #
    def artifact_sign
      @signature = 'unsigned'

      # Clean up the existing signature file
      signature_cleanup

      Dir.chdir("#{$config['general']['app_cache']}/artifacts/") do
        # Generate the signature file and pick up the signature data
        unless system "gpg --use-agent --detach-sign artifact.#{@checksum}.tar.gz"
          $logger.error 'Unable to sign the artifact, an unexpected failure occured. No file uploaded.'
          return false
        end

        if File.exist?("artifact.#{@checksum}.tar.gz.sig")
          $logger.info 'A signature file was successfully generated.'
        else
          $logger.error 'A signature file was NOT generated.'
          return false
        end

        # Convert the signature into base64. It's easier to bundle all the
        # metadata into a single file and extracting it out when needed, than
        # having to keep track of yet-another-file. Because we encode into
        # ASCII here, no need to call GPG with --armor either.

        @signature = Base64.encode64(File.read("artifact.#{@checksum}.tar.gz.sig"))

        unless @signature
          $logger.error 'An unexpected issue occured and no signature was generated'
          return false
        end
      end

      # Make sure the public key has been uploaded if it hasn't already
      pubkey_upload

      @signature
    end

    # Verify the signature for a particular artifact.
    #
    # true  Signature is legit
    # false Signature is invalid (security issue!)
    #
    def artifact_verify
      Dir.chdir("#{$config['general']['app_cache']}/artifacts/") do
        if File.exist?("artifact.#{@checksum}.tar.gz.sig")
          $logger.debug 'Signature already extracted on disk, running verify....'
        else
          $logger.debug 'Extracting signature from manifest data...'
          signature_extract
        end

        # Verify the signature
        pubkey_install unless pubkey_exist?

        output_verify = `gpg --quiet --status-fd 1 --verify artifact.#{@checksum}.tar.gz.sig 2>&1`

        # Cleanup on disk file
        signature_cleanup

        # Was it valid?
        output_verify.each_line do |line|
          if /\[GNUPG:\]\sGOODSIG\s[A-Z0-9]*#{$config["general"]["gpg_signing_key"]}\s/.match(line)
            $logger.info "Artifact #{@checksum} has a valid signature belonging to #{$config['general']['gpg_signing_key']}"
            return true
          end

          if /\[GNUPG:\]\sBADSIG\s/.match(line)
            $logger.fatal "Artifact #{@checksum} has AN INVALID GPG SECURITY SIGNATURE and could be CORRUPT or TAMPERED with."
            exit 0
          end
        end

        # Unexpected error
        $logger.error 'An unexpected validation issue occured, see below debug information:'

        output_verify.each_line do |line|
          $logger.error "GPG: #{line}"
        end
      end

      # Something went wrong
      $logger.fatal "Artifact #{@checksum} COULD NOT BE GPG VALIDATED and could be CORRUPT or TAMPERED with."
      exit 0
    end

    # Generally we should clean up old signature files before and after using them
    #
    def signature_cleanup
      FileUtils.rm("#{$config['general']['app_cache']}/artifacts/artifact.#{@checksum}.tar.gz.sig", force: true)
    end

    # Extract the signature from the manifest file and write it to file in native binary format.
    #
    # false     Unable to extract
    # unsigned  Manifest shows that the artifact is not signed
    # base64    Encoded signature
    #
    def signature_extract
      manifest = YAML.load(File.open($config['general']['app_cache'] + "/artifacts/manifest.#{@checksum}.yaml"), :safe => true, :raise_on_unknown_tag => true)

      if manifest['gpgsig']
        # We have the base64 version
        @signature = manifest['gpgsig']

        # Decode the base64 and write the signature file
        File.write("#{$config['general']['app_cache']}/artifacts/artifact.#{@checksum}.tar.gz.sig", Base64.decode64(@signature))

        return @signature
      else
        return false
      end

    rescue StandardError => e
      $logger.error 'Something unexpected occured when reading the manifest file'
      raise e
    end

    # Save the signature into the manifest file
    #
    def signature_save
      manifest            = YAML.load(File.open($config['general']['app_cache'] + "/artifacts/manifest.#{@checksum}.yaml"), :safe => true, :raise_on_unknown_tag => true)
      manifest['gpgsig']  = @signature

      File.open("#{$config['general']['app_cache']}/artifacts/manifest.#{@checksum}.yaml", 'w') do |fh|
        fh.write YAML.dump(manifest)
      end

      return true

    rescue StandardError
      $logger.error 'Something unexpected occured when updating the manifest file with GPG signature'
      return false
    end

    # Check if the public key is installed on this machine?
    #
    def pubkey_exist?
      # We prefix with 0x to avoid matching on strings in key names
      if system "gpg --status-fd a --list-keys 0x#{$config['general']['gpg_signing_key']} 2>&1 >> /dev/null"
        $logger.debug 'Public key exists on this system'
        return true
      else
        $logger.debug 'Public key does not exist on this system'
        return false
      end
    end

    # Extract & upload the public key to the s3 bucket for other users
    #
    def pubkey_upload
      unless File.exist?("#{$config['general']['app_cache']}/artifacts/#{$config['general']['gpg_signing_key']}.publickey")

        # GPG key does not exist locally, we therefore assume it's not in the S3
        # bucket either, so we should export out and upload. Technically this may
        # result in a few extra uploads (once for any new machine using Pupistry)
        # but it doesn't cause any issue and saves me writing more code ;-)

        $logger.info "Exporting GPG key #{$config['general']['gpg_signing_key']} and uploading to S3 bucket..."

        # If it doesn't exist on this machine, then we're a bit stuck!
        unless pubkey_exist?
          $logger.error "The public key #{$config['general']['gpg_signing_key']} does not exist on this system, so unable to export it out"
          return false
        end

        # Export out key
        unless system "gpg --export --armour 0x#{$config['general']['gpg_signing_key']} > #{$config['general']['app_cache']}/artifacts/#{$config['general']['gpg_signing_key']}.publickey"
          $logger.error 'A fault occured when trying to export the GPG key'
          return false
        end

        # Upload
        s3 = Pupistry::StorageAWS.new 'build'

        unless s3.upload "#{$config['general']['app_cache']}/artifacts/#{$config['general']['gpg_signing_key']}.publickey", "#{$config['general']['gpg_signing_key']}.publickey"
          $logger.error 'Unable to upload GPG key to S3 bucket'
          return false
        end

      end
    end

    # Install the public key. This is a potential avenue for exploit, if a
    # machine is being built for the first time, it has no existing trust of
    # the GPG key, other than transit encryption to the S3 bucket. To protect
    # against attacks at the bootstrap time, you should pre-load your machine
    # images with the public GPG key.
    #
    # For those users who trade off some security for convienence, we install
    # the GPG public key for them direct from the S3 repo.
    #
    def pubkey_install
      $logger.warn "Installing GPG key #{$config['general']['gpg_signing_key']}..."

      s3 = Pupistry::StorageAWS.new 'agent'

      unless s3.download "#{$config['general']['gpg_signing_key']}.publickey", "#{$config['general']['app_cache']}/artifacts/#{$config['general']['gpg_signing_key']}.publickey"
        $logger.error 'Unable to download GPG key from S3 bucket, this will prevent validation of signature'
        return false
      end

      unless system "gpg --import < #{$config['general']['app_cache']}/artifacts/#{$config['general']['gpg_signing_key']}.publickey > /dev/null 2>&1"
        $logger.error 'A fault occured when trying to import the GPG key'
        return false
      end

    rescue StandardError
      $logger.error 'Something unexpected occured when installing the GPG public key'
      return false
    end
  end
end

# vim:shiftwidth=2:tabstop=2:softtabstop=2:expandtab:smartindent
