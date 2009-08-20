
require 'rubygems'

require 'rake'
require 'rake/clean'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'rake/testtask'


RUFUS_SQS_VERSION = '0.8'

#
# GEM SPEC

spec = Gem::Specification.new do |s|

  s.name = 'rufus-sqs'
  s.version = RUFUS_SQS_VERSION
  s.authors = [ 'John Mettraux' ]
  s.email = 'jmettraux@gmail.com'
  s.homepage = 'http://rufus.rubyforge.org/rufus-sqs/'
  s.platform = Gem::Platform::RUBY
  s.summary = 'A Ruby gem for Amazon SQS'
  #s.license           = 'MIT'
  s.description = %{A Ruby gem for Amazon SQS}

  s.require_path = 'lib'
  #s.autorequire = "rufus-decision"
  s.test_file = 'test/test.rb'
  s.has_rdoc = true
  s.extra_rdoc_files = [ 'README.txt' ]

  %w[ rufus-verbs ].each do |d|
    s.requirements << d
    s.add_dependency d
  end

  files = FileList['"{bin,docs,lib,test}/**/*' ]
  files.exclude 'html'
  s.files = files.to_a
end

#
# tasks

CLEAN.include('pkg', 'html')

task :default => [ :clean, :repackage ]


#
# TESTING

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/test.rb']
  t.verbose = true
end

#
# PACKAGING

Rake::GemPackageTask.new(spec) do |pkg|
  #pkg.need_tar = true
end

Rake::PackageTask.new("rufus-sqs", RUFUS_SQS_VERSION) do |pkg|

  pkg.need_zip = true
  pkg.package_files = FileList[
    "Rakefile",
    "*.txt",
    "lib/**/*",
    "test/**/*"
  ].to_a
  #pkg.package_files.delete("MISC.txt")
  class << pkg
    def package_name
      "#{@name}-#{@version}-src"
    end
  end
end


#
# DOCUMENTATION

task :rdoc do
  sh %{
    rm -fR rdoc
    yardoc 'lib/**/*.rb' \
      -o html/rufus-sqs \
      --title 'rufus-sqs'
  }
end


#
# WEBSITE

task :upload_website => [ :clean, :rdoc ] do

  account = "jmettraux@rubyforge.org"
  webdir = "/var/www/gforge-projects/rufus"

  sh "rsync -azv -e ssh html/rufus-sqs #{account}:#{webdir}/"
end

