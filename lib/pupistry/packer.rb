# rubocop:disable Style/Documentation, Style/GlobalVars
require 'rubygems'
require 'erubis'

module Pupistry
  # Pupistry::Packer

  class Packer
    attr_accessor :template_dir
    attr_accessor :contents

    def initialize
      # We need to find where the templates are located - either it should be
      # in the current working directory, or if we are an installed gem, we
      # can try the gem's installed path.

      if Dir.exist?('resources/packer/')
        # Use local PWD version first if possible
        @template_dir = Dir.pwd
      else
        # Check for GEM installed location
        begin
          @template_dir = Gem::Specification.find_by_name('pupistry').gem_dir
        rescue Gem::LoadError
          $logger.error "Unable to find packer templates directory, doesn't appear we are running from project dir nor as a Gem"
          return false
        end
      end

      @template_dir = @template_dir.chomp('/') + '/resources/packer/'

      if Dir.exist?(@template_dir)
        $logger.debug "Using directory #{@template_dir} for packer templates"
      else
        $logger.error "Unable to find packer templates dir at #{@template_dir}, unable to proceed."
        return false
      end
    end

    def list
      # Simply glob the templates directory and list their names.
      $logger.debug 'Finding all available templates'

      Dir.glob("#{@template_dir}/*.erb").each do |file|
        puts "- #{File.basename(file, '.json.erb')}"
      end
    end

    def build(template)
      # Build a template with the configured parameters already to go and save
      # into the object, so it can be outputted in the desired format.

      $logger.debug "Generating a packer template using #{template}"

      unless File.exist?("#{@template_dir}/#{template}.json.erb")
        $logger.error 'The requested template does not exist, unable to build'
        return 0
      end

      # Extract the OS bootstrap name from the template filename, we can then
      # generate the bootstrap commands to be inserted inline into the packer
      # configuration.

      matches = template.match(/^\S*_(\S*)$/)

      if matches[1]
        $logger.debug "Fetching bootstrap data for #{matches[1]}..."
      else
        $logger.error 'Unable to parse the packer filename properly'
        return 0
      end

      bootstrap = Pupistry::Bootstrap.new
      unless bootstrap.build matches[1]
        $logger.error 'An unexpected error occured when building the bootstrap data to go inside Packer'
      end

      # Pass the values we care about to the template
      template_values = {
        bootstrap_commands: bootstrap.output_array
      }

      # Generate template using ERB
      begin
        @contents = Erubis::Eruby.new(File.read("#{@template_dir}/#{template}.json.erb")).result(template_values)
      rescue StandardError => e
        $logger.error 'An unexpected error occured when trying to generate the packer template'
        raise e
      end
    end

    def output_plain
      # Do nothing clever, just output the template data.
      puts '-- Packer Start --'
      puts @contents
      puts '-- Packer End --'
      puts 'Tip: add --file output.json to write out the packer file directly and then run with `packer build output.json`'
    end

    def output_file(filename)
      # Write the template to the specified file
      begin
        File.open(filename, 'w') do |f|
          f.puts @contents
        end
      rescue StandardError => e
        $logger.error "An unexpected erorr occured when attempting to write the template to #{filename}"
        raise e
      else
        $logger.info "Wrote template into file #{filename} successfully."
      end
    end
  end
end

# vim:shiftwidth=2:tabstop=2:softtabstop=2:expandtab:smartindent
