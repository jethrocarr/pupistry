# rubocop:disable Style/Documentation, Style/GlobalVars
require 'rubygems'
require 'yaml'
require 'aws-sdk-v1'

module Pupistry
  # Pupistry::StorageAWS

  class StorageAWS
    attr_accessor :s3
    attr_accessor :bucket

    def initialize(mode)
      # mode is either "build" or "agent", depending which we load a different
      # set of permissions. Awareness of both is intentional, since we want the
      # build machines to known the agent creds so we can generate bootstrap
      # template files.

      unless defined? $config['general']['s3_bucket']
        $logger.fatal 'You must set the AWS s3_bucket'
        exit 0
      end

      # Define AWS configuration
      if defined? $config[mode]['access_key_id']
        if $config[mode]['access_key_id'] == ''
          $logger.debug 'No AWS IAM credentials specified, defaulting to environmental discovery'
          $logger.debug 'If you get weird permissions errors, try setting the credentials explicity in config first.'
        else
          $logger.debug 'Loading AWS credentials from configuration file'

          AWS.config(
            access_key_id:     $config[mode]['access_key_id'],
            secret_access_key: $config[mode]['secret_access_key'],
            region:            $config[mode]['region'],
            proxy_uri:         $config[mode]['proxy_uri']
          )
        end
      else
        $logger.debug 'No AWS IAM credentials specified, defaulting to environmental discovery'
        $logger.debug 'If you get weird permissions errors, try setting the credentials explicity in config first.'
      end

      # Setup S3 bucket
      @s3     = AWS::S3.new
      @bucket = @s3.buckets[$config[mode]['s3_bucket']]
    end

    def upload(src, dest)
      $logger.debug "Pushing file #{src} to s3://#{$config['general']['s3_bucket']}/#{$config['general']['s3_prefix']}#{dest}"

      begin
        # Generate the object name/key based on the relative file name and path.
        s3_obj_name = "#{$config['general']['s3_prefix']}#{dest}"
        s3_obj      = @s3.buckets[$config['general']['s3_bucket']].objects[s3_obj_name]

        # Perform S3 upload
        s3_obj.write(file: src)

      rescue AWS::S3::Errors::NoSuchBucket
        $logger.fatal "S3 bucket #{$config['general']['s3_bucket']} does not exist"
        exit 0

      rescue AWS::S3::Errors::AccessDenied
        $logger.fatal "Access to S3 bucket #{$config['general']['s3_bucket']} denied"
        exit 0

      rescue AWS::S3::Errors::PermanentRedirect => e
        $logger.error "The wrong endpoint has been specified (or autodetected) for #{$config['general']['s3_bucket']}."
        raise e

      rescue AWS::S3::Errors::SignatureDoesNotMatch => e
        $logger.error "IAM signature error when accessing #{$config['general']['s3_bucket']}, probably invalid IAM credentials"
        raise e

      rescue AWS::S3::Errors::MissingCredentialsError
        $logger.error 'AWS credentials not supplied. You must either:'
        $logger.error 'a) Specify them in the config file for Pupistry'
        $logger.error 'b) Use IAM roles with an EC2 instance.'
        $logger.error 'c) Set them in ENV as AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY'
        return false

      rescue StandardError => e
        raise e
      end
    end

    def download(src, dest = 'stream')
      $logger.debug "Downloading file s3://#{$config['general']['s3_bucket']}/#{$config['general']['s3_prefix']}#{src} to #{dest}"

      begin
        # Generate the object name/key based on the relative file name and path.
        s3_obj_name = "#{$config['general']['s3_prefix']}#{src}"
        s3_obj      = @s3.buckets[$config['general']['s3_bucket']].objects[s3_obj_name]

        # Download the file
        if dest == 'stream'
          # Return the contents rather than writing to disk. We assume stream mode
          # if the dest filename was unspecified
          return s3_obj.read
        else
          # Download to an ondisk file
          File.open(dest, 'wb') do |file|
            s3_obj.read do |chunk|
              file.write(chunk)
            end
          end
        end

      rescue AWS::S3::Errors::NoSuchKey
        $logger.debug 'No such file exists for download, this is normal at times.'
        return false

      rescue AWS::S3::Errors::NoSuchBucket
        $logger.fatal "S3 bucket #{$config['general']['s3_bucket']} does not exist"
        exit 0

      rescue AWS::S3::Errors::AccessDenied
        $logger.fatal "Access to S3 bucket #{$config['general']['s3_bucket']} denied"
        exit 0

      rescue AWS::S3::Errors::PermanentRedirect => e
        $logger.error "The wrong endpoint has been specified (or autodetected) for #{$config['general']['s3_bucket']}."
        raise e

      rescue AWS::S3::Errors::SignatureDoesNotMatch => e
        $logger.error "IAM signature error when accessing #{$config['general']['s3_bucket']}, probably invalid IAM credentials"
        raise e

      rescue AWS::S3::Errors::MissingCredentialsError
        $logger.error 'AWS credentials not supplied. You must either:'
        $logger.error 'a) Specify them in the config file for Pupistry'
        $logger.error 'b) Use IAM roles with an EC2 instance.'
        $logger.error 'c) Set them in ENV as AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY'
        return false

      rescue StandardError => e
        raise e
      end
    end
  end
end
# vim:shiftwidth=2:tabstop=2:softtabstop=2:expandtab:smartindent
