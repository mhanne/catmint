module Catmint


  class Gui

    attr_accessor :history, :archive
    attr_reader :views, :url_completion
    def current_view; @views[tabs.get_current_page]; end

    attr_reader :db
    attr_reader :config
    DEFAULT_CONFIG = {
      :datadir => File.join(ENV["HOME"], ".catmint"),
      :server_url => "http://127.0.0.1:12345",
    }

    def initialize config = {}
      @views = []
      @config = DEFAULT_CONFIG.merge(config)
      FileUtils.mkdir_p @config[:datadir]
      connect_db
      @history = Catmint::History.new(self)
      @archive = Catmint::Archive.new(self)
      build_window
      @url_completion = Completion.new self, entry_url, area
      update_completion
      window.show_all; search_bar.hide
    end

    def connect_db
      @db = Sequel.connect("sqlite://#{File.join(config[:datadir], "catmint.db")}")
      migrate
    end
    def migrate
      unless @db.tables.include?(:page)
        @db.create_table :page do
          primary_key :id
          column :url, :string, :null => false, :unique => true, :index => true
          column :title, :string
          column :last_visit, Time
          column :times_visited, :int
          column :content, :text
        end
      end
    end

    def build_window
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
      accelerator("<Control>r", :menu_view_reload)
      accelerator("<Control>l", :menu_view_focus_url)
      accelerator("<Control>f", :menu_view_link_hints)
      accelerator("<Control>i", :menu_view_inspector)
      accelerator("<Control>t", :menu_tabs_new)
      accelerator("<Control>w", :menu_tabs_close)
      accelerator("<Control>Page_Up", :menu_tabs_prev)
      accelerator("<Control>Page_Down", :menu_tabs_next)
      accelerator("<Control>s", :menu_view_find)
      GObject.signal_connect(entry_search, "key-press-event") do |entry, key, _|
        search_bar.hide  if key.string == "\e"
      end
    end

    def update_completion
      return  unless @url_completion
      @url_completion.update @history.list
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

    def on_find
      entry_search.grab_focus
      search_bar.show
    end

    def on_search
      current_view.view.search_text entry_search.text, check_search_casesensitive.active,
      check_search_forward.active, check_search_wrap.active
    end

    def on_back
      current_view.view.go_back
    end

    def on_forward
      current_view.view.go_forward
    end

    def on_reload
      current_view.reload
    end

    def on_new_tab
      view = View.new self
      @views << view
      tabs.append_page view.scroll, Gtk::Label.new("")
      tabs.set_current_page tabs.page_num(scroll)
      view.render_template :index
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
      @views[tabs.current_page].close
    end

    def on_quit
      puts "bye"; EM.stop
    end

    def method_missing name, *args
      @builder.get_object(name.to_s) rescue super(name, *args)
    end

    private

    def accelerator accel, action
      send(action).add_accelerator("activate", accelgroup1,
        *Gtk.accelerator_parse(accel), 1)
    end

  end
end
