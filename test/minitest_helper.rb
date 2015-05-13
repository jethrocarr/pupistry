$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

require 'pupistry'

require 'minitest/autorun'
