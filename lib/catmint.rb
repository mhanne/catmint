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

EM.run do
  Signal.trap("INT") { @gui.on_quit }
  @gui = Catmint::Gui.new
  EM.start_server '127.0.0.1', 12345, Catmint::ArchiveServer, @gui
  EM.gtk_main
end
