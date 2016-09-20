require "logger"
$logger = Logger.new STDERR

require "yaml"
require "rmenu/version"
require "rmenu/monkeypatch"
require "rmenu/utils"
require "rmenu/main_implementation"

module Rmenu
end
