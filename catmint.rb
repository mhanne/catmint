require "./em_gtk.rb"
require "em-http-request"

GirFFI.setup :WebKit, '3.0'

Gtk.init

module Catmint

  class View

    attr_reader :gui, :scroll, :view, :url, :link_hints
    def frame; view.get_main_frame; end
    def html; view.get_main_frame.get_data_source.get_data.str; end

    def initialize gui
      @gui = gui
      @scroll = Gtk::ScrolledWindow.new nil, nil
      @view = WebKit::WebView.new
      @link_hints = false
      connect_signals
      @scroll.add @view
      @view.load_string 'hi', nil, nil, nil
      @scroll.show_all
    end

    def open(url)
      url = "http://#{url}"  unless url =~ /(.*?):\/\/(.*?)/
      @url = url

      http = EM::HttpRequest.new(@url).get
      http.errback { p "Error loading page" }
      http.callback do
        case http.response_header.status
        when 301
          open(http.response_header.location)
        when 200
          @html = http.response
          display_html(@html, nil, nil, @url)
        end
      end
    end

    def reload
      open(@url)
    end

    def follow_link i
      url = html.scan(/<a.*?\shref=["|'](.*?)["|']\s*.*?>(.*?)<\/a>/)[i][0]
      @link_hints = false
      uri = URI.parse(@url).merge(URI.parse(url))
      open(uri.to_s)
    end

    def display_html html, content_type, encoding, base_uri
      i = 0; html.gsub!("</a>") { i += 1; " (#{i - 1})</a>" }  if @link_hints
      @view.load_string(html, content_type, encoding, base_uri)
    end

    def toggle_link_hints
      @link_hints = !@link_hints
      @link_hints ? display_html(html, nil, nil, @url) : reload
    end

    def connect_signals
      GObject.signal_connect(@view, "load-progress-changed") do
        gui.progressbar.set_fraction @view.get_progress
        gui.progressbar.text = "%i %" % (@view.get_progress * 100)
        gui.progressbar.show_text = true
      end

      GObject.signal_connect(@view, "load-committed") do
        gui.statusbar.push 0, "Loading #{@url}"
      end

      GObject.signal_connect(@view, "load-finished") do
        gui.statusbar.push 0, "#{@url} loaded."
        gui.entry_url.text = @view.uri  if @view.uri && @view.uri != "about:blank"

        gui.on_focus_entry_url  if @link_hints

        page = gui.tabs.get_nth_page gui.tabs.page
        box = gui.tabs.get_tab_label(page)
        box = Gtk::Box.new(0, 0)#  if !box || box.is_a?(Gtk::Label)
        box.pack_end Gtk::Label.new(@view.title), true, true, 0  if @view.title
        box.show_all
        gui.tabs.set_tab_label page, box
      end

      GObject.signal_connect(view, "icon-loaded") do |*a|
        icon = Gtk::Image.new_from_pixbuf(view.try_get_favicon_pixbuf 16, 16)
        page = gui.tabs.get_nth_page gui.views.index(self)
        box = gui.tabs.get_tab_label(page)
        box = Gtk::Box.new(0, 0)  if !box || box.is_a?(Gtk::Label)
        box.pack_start(icon, true, true, 0)
        box.show_all
        gui.tabs.set_tab_label page, box
      end

      GObject.signal_connect(@view, "hovering-over-link") do |view, _, url, _|
        next  unless url
        gui.statusbar.push 0, url
      end
    end
  end

  class Gui
    attr_reader :views
    def current_view; @views[tabs.get_current_page]; end

    def accelerator accel, action
      send(action).add_accelerator("activate", accelgroup1,
        *Gtk.accelerator_parse(accel), 0)
    end

    def initialize
      @views = []
      @builder = Gtk::Builder.new
      @builder.add_from_file(File.join(File.dirname(__FILE__), "gui.builder"))
      @builder.connect_signals_full(->(builder, widget, signal, handler, _, _, gui) do
          GObject.signal_connect(widget, signal) { gui.send(handler) }
        end, self)

      tabs.remove_page(0); on_new_tab

      GObject.signal_connect(window, "destroy") { on_quit }
      accelerator("<Control>q", :menu_file_quit)
      accelerator("<Control>b", :button_back)
      accelerator("<Control>m", :button_forward)
      accelerator("<Control>l", :menu_view_focus_url)
      accelerator("<Control>f", :menu_view_link_hints)
      accelerator("<Control>i", :menu_view_inspector)
      accelerator("<Control>t", :menu_tabs_new)
      accelerator("<Control>w", :menu_tabs_close)
      accelerator("<Control>Page_Up", :menu_tabs_prev)
      accelerator("<Control>Page_Down", :menu_tabs_next)

      window.show_all
    end

    def on_display_link_hints
      current_view.toggle_link_hints
    end

    def on_apply
      if current_view.link_hints
        i = entry_url.text.to_i
        current_view.follow_link(i)
      else
        url = entry_url.text
        current_view.open(url)
      end
    end

    def on_focus_entry_url
      entry_url.text = ''
      entry_url.grab_focus
    end

    def on_new_tab
      view = View.new self
      @views << view
      tabs.append_page view.scroll, Gtk::Label.new("")
      tabs.set_current_page tabs.page_num(scroll)
      view.display_html "catmint", nil, nil, nil
      on_focus_entry_url
    end

    def on_prev_tab
      p = (tabs.current_page - 1) % tabs.n_pages
      tabs.set_current_page(p)
      entry_url.text = @views[p].view.uri
    end

    def on_next_tab
      p = (tabs.current_page + 1) % tabs.n_pages
      tabs.set_current_page(p)
      entry_url.text = @views[p].view.uri
    end

    def on_close_tab
      tabs.remove_page(tabs.current_page)
      entry_url.text = @views[tabs.current_page].view.uri
    end

    def on_quit
      puts "bye"; EM.stop
    end

    def method_missing name, *args
      @builder.get_object(name.to_s) rescue super(name, *args)
    end
    
  end
end

EM.run do
  Catmint::Gui.new
  EM.gtk_main
end
