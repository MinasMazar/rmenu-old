require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

desc "Start Rmenu instance"
task :start_rmenu do
  system "bundle exec ruby -rpry exe/rmenu start"
end

task :default => :start_rmenu
