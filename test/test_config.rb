require_relative './minitest_helper'

describe Pupistry::Config do
  before do
    $logger = MiniTest::Mock.new
  end

  it 'exits with an error if told to use a non-existing config file' do
    $logger.expect :debug, nil, [String]
    $logger.expect :fatal, nil, [String]
    assert_raises(SystemExit) do
      Pupistry::Config.load('not_a_real_file')
    end
    assert $logger.verify
  end

  it 'exits with an error if a non-YAML file is specified for use' do
    $logger.expect :debug, nil, [String]
    assert_raises(SystemExit) do
      Pupistry::Config.load('test/data/nonyaml.txt')
    end
    assert $logger.verify
  end

  it 'exits with an error if an empty YAML file is specified for use' do
    $logger.expect :debug, nil, [String]
    assert_raises(SystemExit) do
      Pupistry::Config.load('test/data/empty.yaml')
    end
    assert $logger.verify
  end
end
