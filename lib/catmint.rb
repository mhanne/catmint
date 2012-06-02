require 'yaml'
require 'open-uri'
require_relative "catmint/em_gtk"
require_relative "catmint/view"
require_relative "catmint/completion"
require_relative "catmint/gui"

GirFFI.setup :WebKit, '3.0'
Gtk.init

EM.run do
  @gui = Catmint::Gui.new
  Signal.trap("INT") { @gui.on_quit }
  EM.gtk_main
end
