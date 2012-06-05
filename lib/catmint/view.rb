require 'haml'
require 'ostruct'

module Catmint
  class View

    attr_reader :gui, :scroll, :view, :url, :link_hints
    def frame; view.get_main_frame; end
    def html
      view.get_main_frame.get_data_source.get_data.str
    rescue
      ""
    end

    def initialize gui
      @gui = gui
      @scroll = Gtk::ScrolledWindow.new nil, nil
      @view = WebKit::WebView.new
      @link_hints, @title, @favicon = false, nil, nil
      connect_signals
      @scroll.add @view
      @view.load_string 'hi', nil, nil, nil
      @scroll.show_all
    end

    def open(url)
      if url =~ /(.*?)\.(.*?)/
        url = "http://#{url}"  unless url =~ /(.*?):\/\/(.*?)/
        @url = url
        @view.open url
      else
        search(url)
      end
    end

    def search query
      filename = File.join(File.dirname(__FILE__), 'search.html')
      matchset = gui.history.search(query)
      render_template :search, :results => matchset, :query => query, :gui => gui
    end

    def reload
      @view.reload
    end

    def links
      html.scan(/<a.*?\shref=["|'](.*?)["|']\s*.*?>(.*?)<\/a>/)
    end

    def follow_link i
      url = links[i][0] rescue nil
      @link_hints = false
      if url
        uri = @url ? URI.parse(@url).merge(URI.parse(url)) : URI.parse(url)
        open(uri.to_s)
      else
        gui.entry_url.text = ''
      end
    end

    def display_html html, content_type, encoding, base_uri
      i = 0; html.gsub!("</a>") { i += 1; " (#{i - 1})</a>" }  if @link_hints
      @view.load_string(html, content_type, encoding, base_uri)
    end

    def toggle_link_hints
      @link_hints = !@link_hints
      @link_hints ? display_html(html, nil, nil, @url) : reload
      if @link_hints && links
        links = html.scan(/<a.*?\shref=["|'](.*?)["|']\s*.*?>(.*?)<\/a>/)
          .map.with_index{|l,i| [i.to_s, l[1]]}
        gui.url_completion.update(links)
      end
    end

    def render_template name, data = {}
      filename = File.join(File.dirname(__FILE__), "templates", "#{name}.haml")
      haml = Haml::Engine.new(File.read(filename))
      result = haml.render(OpenStruct.new(data))
      @view.load_string(result, "text/html", "utf-8", "file:///#{filename}")
    end

    def connect_signals
      GObject.signal_connect(@view, "load-progress-changed") do
        gui.progressbar.set_fraction @view.get_progress
        gui.progressbar.text = "%i %" % (@view.get_progress * 100)
        gui.progressbar.show_text = true
      end

      GObject.signal_connect(@view, "load-committed") do
        gui.statusbar.push 0, "Loading #{@url}"
        gui.progressbar.set_fraction 0.0
        gui.progressbar.text = "0 %"
      end

      GObject.signal_connect(@view, "load-error") do |view, frame, url, error, _|
        code, message = *GObjectIntrospection::GError.new(error).values[1..2]
        render_template :error, :code => code, :message => message
        true
      end

      GObject.signal_connect(@view, "load-finished") do |view, frame|
        gui.statusbar.push 0, "#{view.uri} loaded."
        gui.entry_url.text = view.uri  if view.uri &&
          gui.tabs.page == gui.views.index(self) &&
          view.uri != "about:blank" && !(view.uri =~ /^file:\/\//)
        if @link_hints
          gui.on_focus_entry_url
          gui.entry_url.text = ""
        end
        @title = view.title
        update_tab_label
        html = view.main_frame.data_source.get_data.str rescue nil

        if !(@link_hints || view.uri =~ /^file:\/\// ||
            view.uri =~ /^#{gui.config[:server_url]}/)
          gui.history.add(view.uri, view.title, html)
          gui.update_completion  unless @link_hints
        end
        #view.search_text "Home", true, true, true
      end

      GObject.signal_connect(view, "icon-loaded") do |*a|
        @favicon = view.try_get_favicon_pixbuf 16, 16
        update_tab_label
      end

      GObject.signal_connect(@view, "hovering-over-link") do |view, _, url, _|
        next  unless url
        gui.statusbar.push 0, url
      end

      GObject.signal_connect(@view, "resource-load-finished") do |view, frame, res, _|
        next  if res.uri =~ /^file:\/\//
        next  if res.uri =~ /^#{gui.config[:server_url]}/
        begin
          ptr, len, _ = res.data.instance_eval { @struct.values }
          data = ptr.read_string(len)
          EM.defer { gui.archive.write res.uri, data }
        rescue
          p $!
          binding.pry
        end
      end
    end

    def close
      n = gui.views.index(self)
      gui.tabs.remove_page(n)
      gui.views.delete_at(n)
      gui.on_quit  if gui.tabs.n_pages < 1
    end

    def update_tab_label
      box = Gtk::Box.new(0, 0)
      close_icon = Gtk::Image.new_from_stock("gtk-close", Gtk::IconSize.find(:menu))
      eb = Gtk::EventBox.new
      GObject.signal_connect(eb, "button-press-event") { close }
      eb.add close_icon
      box.pack_end eb, true, true, 0
      box.pack_start Gtk::Image.new_from_pixbuf(@favicon), true, true, 0  if @favicon
      box.pack_end Gtk::Label.new(@title), true, true, 0  if @title
      box.show_all

      event_box = Gtk::EventBox.new
      event_box.add box
      GObject.signal_connect(event_box, "button-press-event") do |box, button, _|
        close  if button.button == 2
      end
      page = gui.tabs.get_nth_page(gui.views.index(self))
      gui.tabs.set_tab_label page, event_box
    end

  end
end
