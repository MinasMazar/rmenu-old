require "logger"
$logger = Logger.new STDERR

require "yaml"
require "rmenu/version"
require "rmenu/monkeypatch"
require "rmenu/utils"
require "rmenu/mixins"
require "rmenu/profiles"
require "rmenu/plugins"
require "rmenu/daemon"

module Rmenu
end
