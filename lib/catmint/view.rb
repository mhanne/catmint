module Catmint
  class View

    attr_reader :gui, :scroll, :view, :url, :link_hints
    def frame; view.get_main_frame; end
    def html; view.get_main_frame.get_data_source.get_data.str; end

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
      url = "http://#{url}"  unless url =~ /(.*?):\/\/(.*?)/
      @url = url
      @view.open url
    end

    def reload
      @view.reload
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

      GObject.signal_connect(@view, "load-error") do |view, frame, url, error, _|
        code, message = *GObjectIntrospection::GError.new(error).values[1..2]
        filename = File.join(File.expand_path(File.dirname(__FILE__)), "error.html")
        err = File.read(filename)
        err.sub!("</body>", <<-EOS);
<script type='text/javascript'>
var code = '#{code}';
var message = '#{message}';
</script></body>
EOS
        display_html(err, nil, nil, "file:///#{filename}")
        true
      end

      GObject.signal_connect(@view, "load-finished") do
        gui.statusbar.push 0, "#{@url} loaded."
        gui.entry_url.text = @view.uri  if @view.uri && @view.uri != "about:blank"
        gui.on_focus_entry_url  if @link_hints
        @title = @view.title
        update_tab_label
        gui.history[@view.uri] = @view.title
        gui.update_completion
      end

      GObject.signal_connect(view, "icon-loaded") do |*a|
        @favicon = view.try_get_favicon_pixbuf 16, 16
        update_tab_label
      end

      GObject.signal_connect(@view, "hovering-over-link") do |view, _, url, _|
        next  unless url
        gui.statusbar.push 0, url
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
end
