Gem::Specification.new do |spec|
  spec.name        = 'pupistry'
  spec.version     = '1.0.0'
  spec.date        = '2015-05-10'
  spec.summary     = 'A workflow tool for Puppet Masterless Deployments'
  spec.description = 'Provides security, reliability and consistency to Puppet masterless environments'
  spec.authors     = ['Jethro Carr']
  spec.email       = 'jethro.carr@jethrocarr.com'
  spec.files       = Dir[
                       'exe/*',
                       'lib/*',
                       'lib/pupistry/*',
                       'resources/*',
                       'resources/aws/*',
                       'resources/bootstrap/*',
                       'README.md',
                       'settingspec.example.yaml'
                     ]
  spec.executables = ['pupistry']
  spec.homepage    = 'https://github.com/jethrocarr/pupistry'
  spec.license     = 'Apache'

  spec.add_development_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.6'
  spec.add_development_dependency 'simplecov', '~> 0.10'
  spec.add_development_dependency 'rubocop'

  spec.add_runtime_dependency 'aws-sdk-v1'
  spec.add_runtime_dependency 'thor'
  spec.add_runtime_dependency 'erubis'
  spec.add_runtime_dependency 'rufus-scheduler', '~> 3'

  # Now technically we don't call r10k from this gem, instead we call it via
  # system, but we can cheat a bit and list it here to get it installed for uspec.
  spec.add_runtime_dependency 'r10k'
end
