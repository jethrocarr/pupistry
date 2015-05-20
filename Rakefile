require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rake/clean'
require 'rubocop/rake_task'

RuboCop::RakeTask.new(:rubocop) do |r|
  r.patterns = ['lib/**/*.rb', 'exe/*.rb']

  # Rubocop is important, but it shouldn't be a reason for build failure
  r.fail_on_error = false
end

Rake::TestTask.new do |t|
  t.pattern = 'test/test_*.rb'
end

task 'default' => [:test, :rubocop]
