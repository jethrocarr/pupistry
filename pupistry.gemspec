# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pupistry/version'

Gem::Specification.new do |spec|
  spec.name        = 'pupistry'
  spec.version     = Pupistry::VERSION # See lib/pupistry/version.rb to change version
  spec.date        = '2015-08-15'
  spec.summary     = 'A workflow tool for Puppet Masterless Deployments'
  spec.description = 'Provides security, reliability and consistency to Puppet masterless environments' # rubocop:disable Metrics/LineLength
  spec.authors     = ['Jethro Carr']
  spec.email       = 'jethro.carr@jethrocarr.com'
  spec.bindir      = 'exe'
  spec.files       = Dir[
                       'exe/*',
                       'lib/**/*',
                       'resources/**/*',
                       'README.md',
                       'settings.example.yaml'
                     ]
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.homepage    = 'https://github.com/jethrocarr/pupistry'
  spec.license     = 'Apache'

  spec.add_development_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.6'
  spec.add_development_dependency 'simplecov', '~> 0.10'
  spec.add_development_dependency 'rubocop'

  spec.add_runtime_dependency 'aws-sdk-v1'
  spec.add_runtime_dependency 'thor'
  spec.add_runtime_dependency 'which'
  spec.add_runtime_dependency 'erubis'
  spec.add_runtime_dependency 'safe_yaml'
  spec.add_runtime_dependency 'rufus-scheduler', '~> 3'

  # Now technically we don't call r10k from this gem,
  # instead we call it via system, but we can cheat
  # a bit and list it here to get it installed for uspec.
  spec.add_runtime_dependency 'r10k'

  # r10k requires Puppet to run, so the logial thing to do would be to
  # uncomment the below dependency. But the issue is that generally
  # Puppet is installed from system packages and we don't want to screw
  # up the environmnent by loading a different version on.
  #
  # We instead handle this dependency by checking for it at startup and
  # throwing an error if we cannot find puppet.
  #
  # spec.add_runtime_dependency 'puppet'
end
