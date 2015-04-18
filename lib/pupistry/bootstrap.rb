require 'rubygems'
require "base64"
require 'erubis'

module Pupistry
  # Pupistry::Bootstrap

  class Bootstrap
    attr_accessor :template_dir
    attr_accessor :contents

    def initialize

      # We need to find where the templates are located - either it should be
      # in the current working directory, or if we are an installed gem, we
      # can try the gem's installed path.

      if Dir.exists?("resources/bootstrap/")
        # Use local PWD version first if possible
        @template_dir = Dir.pwd
      else
        # Check for GEM installed location
        begin
          @template_dir = Gem::Specification.find_by_name("pupistry").gem_dir
        rescue Gem::LoadError
          $logger.error "Unable to find templates/ directory, doesn't appear we are running from project dir nor as a Gem"
          return false
        end
      end

      @template_dir = @template_dir.chomp("/") + "/resources/bootstrap/"

      unless Dir.exists?(@template_dir)
        $logger.error "Unable to find templates dir at #{@template_dir}, unable to proceed."
        return false
      else
        $logger.debug "Using directory #{@template_dir} for bootstrap templates"
      end

    end
    

    def list
      # Simply glob the templates directory and list their names.
      $logger.debug "Finding all available templates"

      Dir.glob("#{@template_dir}/*.erb").each do |file|
        puts "- #{File.basename(file, ".erb")}"
      end
    end


    def build template
      # Build a template with the configured parameters already to go and save
      # into the object, so it can be outputted in the desired format.

      $logger.debug "Generating a bootstrap script for #{template}"

      unless File.exists?("#{@template_dir}/#{template}.erb")
        $logger.error "The requested template does not exist, unable to build"
        return 0
      end

      # Assume values we care about
      template_values = {
        s3_bucket: $config["general"]["s3_bucket"],
        s3_prefix: $config["general"]["s3_prefix"],
        gpg_disable: $config["general"]["gpg_disable"],
        gpg_signing_key: $config["general"]["gpg_signing_key"],
        puppetcode: $config["agent"]["puppetcode"],
        access_key_id: $config["agent"]["access_key_id"],
        secret_access_key: $config["agent"]["secret_access_key"],
        region: $config["agent"]["region"],
        proxy_uri: $config["agent"]["proxy_uri"],
      }

      # Generate template using ERB
      begin
        @contents = Erubis::Eruby.new(File.read("#{@template_dir}/#{template}.erb")).result(template_values)
      rescue Exception => e
        $logger.error "An unexpected error occured when trying to generate the bootstrap template"
        raise e
      end

    end

    def output_plain
      # Do nothing clever, just output the template data.
      puts "-- Bootstrap Start --"
      puts @contents
      puts "-- Bootstrap End --"
    end

    def output_base64
      # Some providers like AWS can accept the data in Base64 version which is
      # smaller and less likely to get messed up by copy and paste or weird
      # formatting issues.
      puts "-- Bootstrap Start --"
      puts Base64.encode64(@contents)
      puts "-- Bootstrap End --"
    end

  end
end

# vim:shiftwidth=2:tabstop=2:softtabstop=2:expandtab:smartindent
