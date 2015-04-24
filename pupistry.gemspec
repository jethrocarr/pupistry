Gem::Specification.new do |s|
  s.name        = 'pupistry'
  s.version     = '0.0.11'
  s.date        = '2015-04-24'
  s.summary     = "A workflow tool for Puppet Masterless Deployments"
  s.description = "Provides security, reliability and consistency to Puppet masterless environments"
  s.authors     = ["Jethro Carr"]
  s.email       = 'jethro.carr@jethrocarr.com'
  s.files       = Dir['bin/*'] + Dir['lib/*'] + Dir['lib/pupistry/*'] + ["README.md"] + ["settings.example.yaml"]
  s.executables = ["pupistry"]
  s.homepage    = 'https://github.com/jethrocarr/pupistry'
  s.license     = 'Apache'

  s.add_runtime_dependency 'aws-sdk-v1'
  s.add_runtime_dependency 'thor'
  s.add_runtime_dependency 'erubis'
  s.add_runtime_dependency 'rufus-scheduler', '~> 3'

  # Now technically we don't call r10k from this gem, instead we call it via
  # system, but we can cheat a bit and list it here to get it installed for us.
  s.add_runtime_dependency 'r10k'

end
