
require 'rubygems'

require 'rake'
require 'rake/clean'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'rake/testtask'

#require 'rake/rdoctask'
require 'hanna/rdoctask'


RUFUS_SQS_VERSION = '0.8'

#
# GEM SPEC

spec = Gem::Specification.new do |s|

  s.name              = 'rufus-sqs'
  s.version           = RUFUS_SQS_VERSION
  s.authors           = [ 'John Mettraux' ]
  s.email             = 'jmettraux@gmail.com'
  s.homepage          = 'http://rufus.rubyforge.org/rufus-sqs/'
  s.platform          = Gem::Platform::RUBY
  s.summary           = 'A Ruby gem for Amazon SQS'
  #s.license           = 'MIT'

  s.require_path      = 'lib'
  #s.autorequire       = "rufus-decision"
  s.test_file         = 'test/test.rb'
  s.has_rdoc          = true
  s.extra_rdoc_files  = [ 'README.txt' ]

  [ 'rufus-verbs' ].each do |d|
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

Rake::RDocTask.new do |rd|

  rd.main = 'README.txt'
  rd.rdoc_dir = 'html/rufus-sqs'
  rd.rdoc_files.include(
    'README.txt',
    'CHANGELOG.txt',
    'LICENSE.txt',
    #'CREDITS.txt',
    'lib/**/*.rb')
  #rd.rdoc_files.exclude('lib/tokyotyrant.rb')
  rd.title = 'rufus-sqs rdoc'
  rd.options << '-N' # line numbers
  rd.options << '-S' # inline source
end

task :rrdoc => :rdoc do
  FileUtils.cp('doc/rdoc-style.css', 'html/rufus-sqs/')
end


#
# WEBSITE

task :upload_website => [ :clean, :rrdoc ] do

  account = "jmettraux@rubyforge.org"
  webdir = "/var/www/gforge-projects/rufus"

  sh "rsync -azv -e ssh html/rufus-sqs #{account}:#{webdir}/"
end

