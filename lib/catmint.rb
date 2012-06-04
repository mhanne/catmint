require 'yaml'
require 'json'
require 'open-uri'
require 'fileutils'
require_relative "catmint/em_gtk"
require_relative "catmint/view"
require_relative "catmint/completion"
require_relative "catmint/history"
require_relative "catmint/gui"
require_relative "catmint/archive"

GirFFI.setup :WebKit, '3.0'
Gtk.init

