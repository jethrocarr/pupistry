# rubocop:disable Style/Documentation, Style/GlobalVars
require 'rubygems'
require 'yaml'
require 'safe_yaml'
require 'fileutils'
require 'base64'

module Pupistry
  # Pupistry::HieraCrypt

  class HieraCrypt

    # As HieraCrypt is an optional extension, we should provide calling code
    # an easy way to determine if we're enabled or not.
    def self.is_enabled?
      begin
        if $config['build']['hieracrypt'] == true
          $logger.debug 'Hieracrypt is enabled.'
          return true
        end
      rescue => ex
        # Nothing todo, fall back.
      end

      $logger.debug 'Hieracrypt is disabled.'
      return false
    end


    # To encrypt the Hieradata against the certs we have, there's a few things
    # that we need to do.
    #
    # 1. Firstly we need to iterate through all the available environments in
    #    the app_cache/puppetcode directory and for each one, load the Hiera
    #    rules.
    #
    # 2. Secondly (assuming HieraCrypt is even enabled) we must find all the
    #    node files that contain the cert & fact data.
    #
    # 3. Apply the rules to the host and determine which files should go into
    #    the encrypted hieradata file for that host and copy to a dir.
    #
    # 4. Generate the encrypted HieraCrypt file with the files in it, one per
    #    each node we have.
    #
    # 5. Purge the unencrypted hieradata and the working files.
    #
    # Run after fetch_r10k and before build_artifact
    #
    def self.encrypt_hieradata
      unless is_enabled?
        return false
      end
      
      $logger.info "Encrypting Hieradata (HieraCrypt Feature)..."


      # Key paths to remember inside puppetcode / BRANCH:
      #
      # hieracrypt/nodes/     Where the various per-host files live.
      # hieradata/hiera.yaml  The Hiera rules
      # hieradata/*           Any/all Hiera data.
      #
      puppetcode = $config['general']['app_cache'] + '/puppetcode'

      
      # Run through each environment.
      for env in Dir.glob(puppetcode +'/*')
        env = File.basename(env)

        if Dir.exists?(puppetcode + '/' + env)
          $logger.debug "Processing branch: #{env}"

          Dir.chdir(puppetcode + '/' + env) do
            # Directory env exists, check inside it for a hiera.yaml
            if File.exists?('hiera.yaml')
              $logger.debug 'Found hiera file '+ puppetcode + '/' + env + '/hiera.yaml'
            else
              $logger.warn "No hiera.yaml could be found for branch #{env}, no logic to encrypt on"
              return false
            end


            # Iterate through each node in the environment
            unless Dir.exists?('hieradata')
              $logger.warn "No hieradata found for branch #{env}, so nothing to encrypt. Skipping."
              break
            end

            if Dir.exists?('hieracrypt')
              $logger.debug 'Found hieracrypt directory'
            else
              $logger.warn "No hieracrypt/ directory could be found for branch #{env}, no encryption can take place there."
              break
            end

            unless Dir.exists?('hieracrypt/nodes')
              $logger.warn "No hieracrypt/nodes directory could be found for branch #{env}, no encryption can take place there."
              break
            end
            
            unless Dir.exists?('hieracrypt/encrypted')
              # We place the encrypted data files in here.
              Dir.mkdir('hieracrypt/encrypted')
            end

            nodes = Dir.glob('hieracrypt/nodes/*')

            if nodes
              for node in nodes
                node = File.basename(node)

                $logger.debug "Found node #{node} for environment #{env}, processing now..."
                  # Apply the Hiera rules to the directory and get back a list of
                  # files that would be matched by Hiera
                  # TODO
                  $logger.warn "Selective hiera rule enforcement not yet active"

                  # TODO: Special rule needed, if fact == environment and null, set to ${env}


                  # Copy all the files to a working directory, maintaining directory
                  # structure.

                  begin
                    FileUtils.rm_r "hieradata.#{node}"
                  rescue Errno::ENOENT
                    # Normal error if it doesn't exist yet.
                  end

                  FileUtils.cp_r 'hieradata', "hieracrypt.#{node}"


                  # Generate the encrypted file
                  tar = Pupistry::Config.which_tar
                  $logger.debug "Using tar at #{tar}"

                  unless system "#{tar} -c -z -f hieracrypt.#{node}.tar.gz hieracrypt.#{node}"
                    $logger.error 'Unable to create tarball'
                    fail 'An unexpected error occured when executing tar'
                  end

                  openssl = "openssl smime -encrypt -binary -aes256 -in hieracrypt.#{node}.tar.gz -out hieracrypt/encrypted/#{node}.tar.gz.enc hieracrypt/nodes/#{node}"
                  $logger.debug "Executing: #{openssl}"

                  unless system openssl
                    $logger.error "Generation of encrypted file failed for node #{node}"
                    fail 'An unexpected error occured when executing openssl'
                  end

                  # Cleanup Unencrypted
                  FileUtils.rm_r "hieracrypt.#{node}.tar.gz"
                  FileUtils.rm_r "hieracrypt.#{node}"
                end
            else
              $logger.warn "No nodes could be found for branch #{env}, no encryption can take place there."
              break
            end

            # We don't do the purge of hieradata unencrypted directory here,
            # instead we tell the artifact creation process to exclude it from
            # the artifact generation if Hieracrypt is enabled.

          end
        end
      end

    end

    # Find & decrypt the data for this server, if any. This should be run
    # ALWAYS regardless of the Hieracrypt parameter, since we don't want people
    # to have to worry about rolling it out to clients, we can figure it out
    # based on what files do (or don't) exist.
    #
    # Runs after unpack, but before artifact install. We get the artifact class
    # to pass through the location to operate inside of.
    #
    def self.decrypt_hieradata puppetcode
      $logger.debug "Decrypting Hieracrypt..."
      
      hostname         = get_hostname             # Facter hostname value
      ssh_host_rsa_key = get_ssh_rsa_private_key  # We generate the SSL cert using the SSH RSA Host key


      # Run through each environment.
      for env in Dir.glob(puppetcode +'/*')
        env = File.basename(env)

        if Dir.exists?(puppetcode + '/' + env)
          $logger.debug "Processing branch: #{env}"

          Dir.chdir(puppetcode + '/' + env) do
            unless Dir.exists?("hieracrypt/encrypted")
              $logger.debug "Environment #{env} is using unencrypted hieradata."
            else
              $logger.debug "Environment #{env} is using HieraCrypt, searching for host..."

              if File.exists?("hieracrypt/encrypted/#{hostname}.tar.gz.enc")
                $logger.info "Found encrypted Hieradata for #{hostname} in #{env} branch"

                # Perform decryption of this host.
                openssl = "openssl smime -decrypt -inkey #{ssh_host_rsa_key} < hieracrypt/encrypted/#{hostname}.tar.gz.enc | tar -xz"

                unless system openssl
                  $logger.error "A fault occured trying to decrypt the data for #{hostname}"
                end

                # Move unpacked host-specific Hieradata into final location
                FileUtils.mv "hieracrypt.#{hostname}", "hieradata"
              else
                $logger.error "Unable to find a HieraCrypt package for #{hostname} in branch #{env}, this machine will be missing all Hieradata"
              end
            end
          end
        end
      end

    end


    # Fetch the Puppet facts and the x509 cert from the server and export them
    # in a combined version for easy cut'n'paste to the puppetcode repo.
    def self.generate_nodedata
      $logger.info "Generating an export package of cert and facts..."

      # Setup the cache so we can park various files as we work.
      cache_dir = $config['general']['app_cache'] +'/hieracrypt'

      unless Dir.exists?(cache_dir)
        Dir.mkdir(cache_dir)
      end

      # Generate the SSH public cert.
      ssh_host_rsa_key = get_ssh_rsa_private_key  # We generate the SSL cert using the SSH RSA Host key
      cert_days        = '36500'                  # Valid for 100 years
      subject_string   = '/C=XX/ST=Pupistry/L=Pupistry/O=Pupistry/OU=Pupistry/CN=Pupistry/emailAddress=pupistry@example.com'

      unless File.exists?(ssh_host_rsa_key)
        $logger.error "Unable to find ssh_host_rsa_key file at: #{ssh_host_rsa_key}, unable to proceed."
      end

      # TODO: Is there a native library we can use for invoking this and is anyone brave enough to face it? For now
      # system might be easier.
      openssl = 'openssl req -x509 -key '+ ssh_host_rsa_key +' -nodes -days '+ cert_days +' -newkey rsa:2048 -out '+ cache_dir +'/server.pem -subj '+ subject_string
      $logger.debug "Executing: #{openssl}"

      unless system openssl
        $logger.error "An error occured attempting to execute openssl"
      end

      # Grab all the facter values
      puppet_facts = facts_for_hiera($config['agent']['puppetcode'])

      # TODO: Hit facter natively via Rubylibs?
      unless system 'facter -p -j '+ puppet_facts.join(" ") +' >> '+ cache_dir +'/server.pem 2> /dev/null'
        $logger.error "An error occur attempting to execute facter"
      end

      # Output the whole file for the user
      hostname = get_hostname
      puts "The following output should be saved into `hieracrypt/nodes/#{hostname}`:"
      puts IO.read(cache_dir +'/server.pem')

    end


    # Iterate through the puppetcode environments for all hiera.yaml files
    # and suck out all the facts that Hiera cares about. We do this since
    # we want to selectively return only the facts we need, since it's
    # pretty common to have facts exposing stuff that's potentially a bit
    # private and unwanted in the puppetcode repo.
    #
    # Returns
    # Array of Facts

    def self.facts_for_hiera(path)
      $logger.debug "Searching for facts specified in Hiera rules..."
            
      puppet_facts = []

      for env in Dir.entries(path)
        if Dir.exists?(path + '/' + env)
          # Directory env exists, check inside it for a hiera.yaml
          if File.exists?(path + '/' + env + '/hiera.yaml')
            $logger.debug 'Found hiera file '+ path + '/' + env + '/hiera.yaml, checking for facts'

            # Iterate through the Hiera rules for values
            hiera = YAML.load_file(path + '/' + env + '/hiera.yaml', safe: true, raise_on_unknown_tag: true)

            if defined? hiera[':hierarchy']
              if hiera[':hierarchy'].is_a?(Array)
                for line in hiera[':hierarchy']
                  # Match syntax of %{::some_kinda_fact}
                  line.scan(/%{::([[:word:]]*)}/) { |match|
                    puppet_facts.push(match) unless puppet_facts.include?(match)
                  }
                end
              else
                $logger.error "Use the array format of the hierachy entry in Hiera, string format not supported because why would you?"
              end
            end
          end
        end
      end

      if puppet_facts.count == 0
        $logger.warn "Couldn't find any facts mentioned in Hiera, possibly missing or very empty/basic hiera.yaml file in puppetcode repo"
      else
        $logger.debug "Facts specified in Hiera are: "+ puppet_facts.join(", ")
      end

      return puppet_facts
    end



    def self.get_ssh_rsa_private_key
      # Currently hard coded
      return '/etc/ssh/ssh_host_rsa_key'
    end

    def self.get_hostname
      # TODO: Ewwww
      hostname = `facter hostname`
      return hostname.chomp
    end

  end
end

# vim:shiftwidth=2:tabstop=2:softtabstop=2:expandtab:smartindent
