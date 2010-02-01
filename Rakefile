#====================================================
#
#    Copyright 2008-2010 iAnywhere Solutions, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#                                                                               
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.
#
# While not a requirement of the license, if you do modify this file, we
# would appreciate hearing about it.   Please email sqlany_interfaces@sybase.com
#
#
#====================================================

require 'rake/clean'
require 'rake/rdoctask'
require 'rubygems'
require 'rubygems/builder'

PACKAGE_NAME = "activerecord-sqlanywhere-adapter"
ARCH=Config::CONFIG['arch']

pkg_version = "0.1.3"

spec = Gem::Specification.new do |spec|
  spec.authors = ["Eric Farrar"]
  spec.email = 'eric.farrar@ianywhere.com'
  spec.name = 'activerecord-sqlanywhere-adapter'
  spec.summary = 'ActiveRecord driver for SQL Anywhere'
  spec.description = <<-EOF
    ActiveRecord driver for SQL Anywhere
  EOF
  spec.version = pkg_version
  spec.has_rdoc = true
  spec.rubyforge_project = 'sqlanywhere'
  spec.homepage = 'http://sqlanywhere.rubyforge.org'  
  spec.files = Dir['lib/**/*.rb'] + Dir['test/**/*']
  spec.required_ruby_version = '>= 1.8.6'
  spec.require_paths = ['lib']
  spec.add_dependency('sqlanywhere', '>= 0.1.0')
  spec.add_dependency('activerecord', '>= 2.0.2')
  spec.rdoc_options << '--title' << 'ActiveRecord Driver for SQL Anywhere' <<
                       '--main' << 'README' <<
                       '--line-numbers'
  spec.extra_rdoc_files = ['README', 'CHANGELOG', 'LICENSE']  
end

desc "Build the gem"
task :gem => ["activerecord-sqlanywhere-adapter-#{pkg_version}.gem"] do
end

file "activerecord-sqlanywhere-adapter-#{pkg_version}.gem" => ['lib/active_record/connection_adapters/sqlanywhere_adapter.rb', 'README', 'Rakefile'] do
   Gem::Builder.new(spec).build
end


desc "Install the gem"
task :install => ["activerecord-sqlanywhere-adapter-#{pkg_version}.gem"] do
     sh "gem install activerecord-sqlanywhere-adapter-#{pkg_version}.gem"
end

desc "Build distributables (src zip, src tar.gz, gem)"
task :dist do |t|
   puts "Cleaning Build Environment..."
   Rake.application['clobber'].invoke   
   system "rake clobber"

   files = Dir.glob('*')

   puts "Creating #{File.join('build', PACKAGE_NAME)}-#{pkg_version} directory..." 
   FileUtils.mkdir_p "#{File.join('build', PACKAGE_NAME)}-#{pkg_version}"

   puts "Copying files to #{File.join('build', PACKAGE_NAME)}-#{pkg_version}..." 
   FileUtils.cp_r files, "#{File.join('build', PACKAGE_NAME)}-#{pkg_version}"

   if( ARCH =~ /win32/ ) then
      system "attrib -R #{File.join('build', PACKAGE_NAME)}-#{pkg_version} /S"
   else
      system "find #{File.join('build', PACKAGE_NAME)}-#{pkg_version} -type d -exec chmod 755 {} \\;"
      system "find #{File.join('build', PACKAGE_NAME)}-#{pkg_version} -type f -exec chmod 644 {} \\;"
   end

   if( ARCH =~ /win32/ ) then   
      puts "Creating #{File.join('build', PACKAGE_NAME)}-#{pkg_version}.zip..." 
      system "cd build && zip -q -r #{PACKAGE_NAME}-#{pkg_version}.zip #{PACKAGE_NAME}-#{pkg_version}"   
   else
      puts "Creating #{File.join('build', PACKAGE_NAME)}-#{pkg_version}.tar..." 
      system "tar cf #{File.join('build', PACKAGE_NAME)}-#{pkg_version}.tar -C build #{PACKAGE_NAME}-#{pkg_version}"
      
      puts "GZipping to create #{File.join('build', PACKAGE_NAME, PACKAGE_NAME)}-#{pkg_version}.tar.gz..." 
      system "gzip #{File.join('build', PACKAGE_NAME)}-#{pkg_version}.tar"
   end

   puts "Building GEM distributable..." 
   Rake.application['gem'].invoke   

   puts "Copying GEM to #{File.join('build', PACKAGE_NAME)}-#{pkg_version}.gem..." 
   FileUtils.cp "#{PACKAGE_NAME}-#{pkg_version}.gem", "build"
end

Rake::RDocTask.new do |rd|
   rd.title = "ActiveRecord Driver for SQL Anywhere"
   rd.main = "README"
   rd.rdoc_files.include('README', 'CHANGELOG', 'LICENSE', 'lib/**/*.rb')
end

desc "Publish the RDOCs on RubyForge"
task :publish_rdoc => ["html/index.html"] do
  system "pscp -r html/* efarrar@rubyforge.org:/var/www/gforge-projects/sqlanywhere/activerecord-sqlanywhere-adapter"
end

CLOBBER.include("activerecord-sqlanywhere-adapter-#{pkg_version}.gem", "build/**/*", "build")
