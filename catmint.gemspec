$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "catmint"
  s.version     = "0.0.1"
  s.authors     = ["Marius Hanne"]
  s.email       = ["marius.hanne@sourceagency.org"]
  s.homepage    = ""
  s.summary     = %q{simple keyboard-friendly browser using webkit/gtk through ruby-gir-ffi}
  s.description = %q{simple keyboard-friendly browser using webkit/gtk through ruby-gir-ffi}

  s.files         = Dir.glob("lib/**/**")
  s.executables   = "catmint"
  s.require_paths = ["lib"]

  s.add_dependency "gir_ffi"
  s.add_dependency "eventmachine"
  s.add_dependency "eventmachine_httpserver"
  s.add_dependency "sequel"
  s.add_dependency "sqlite3"
  s.add_dependency "ruby-filemagic"
  s.add_dependency "distillery"

end
