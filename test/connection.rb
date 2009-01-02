print "Using native SQLAnywhere Interface\n"
require_dependency 'models/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter  => 'sqlanywhere',
    :database => 'arunit',
    :server   => 'arunit',
    :username => 'dba',
    :password => 'sql'
  },
  'arunit2' => {
    :adapter  => 'sqlanywhere',
    :database => 'arunit2',
    :server   => 'arunit',
    :username => 'dba',
    :password => 'sql'
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'
