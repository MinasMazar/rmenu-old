require "logger"
$logger = Logger.new STDERR

require "yaml"
require "rmenu/version"
require "rmenu/monkeypatch"
require "rmenu/utils"
require "rmenu/item"
require "rmenu/profiles"
require "rmenu/daemon"

module Rmenu
end
