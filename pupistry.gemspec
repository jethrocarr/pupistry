Gem::Specification.new do |s|
  s.name        = 'pupistry'
  s.version     = '0.0.1'
  s.date        = '2015-04-04'
  s.summary     = "A workflow tool for Puppet Masterless Deployments"
  s.description = "Provides security, reliability and consistency to Puppet masterless environments"
  s.authors     = ["Jethro Carr"]
  s.email       = 'jethro.carr@jethrocarr.com'
  s.files       = Dir['bin/*'] + Dir['lib/*'] + ["README.md"]
  s.executables = ["pupistry"]
  s.homepage    = 'https://github.com/jethrocarr/pupistry'
  s.license     = 'Apache'

  s.add_runtime_dependency 'aws-sdk-v1'
  s.add_runtime_dependency 'thor'
end
