module Catmint
  class Completion
    attr_accessor :comp, :model, :renderer
    def initialize gui, entry, area
      @gui, @entry, @area = gui, entry, area
      @model = Gtk::ListStore.new([GObject::TYPE_STRING, GObject::TYPE_STRING])
      @comp = Gtk::EntryCompletion.new_with_area(@area)
      @comp.text_column = 0
      @comp.minimum_key_length = 1
      @comp.set_match_func(->(comp, text, iter, _) {
          url = comp.get_model.value(iter, 0).get_string
          title = comp.get_model.value(iter, 1).get_string
          !!(url =~/#{text}/i || title =~ /#{text}/i)
        }, nil, nil)

      @renderer = Gtk::CellRendererText.new
      @comp.area.pack_start @renderer, false, false, false
      @comp.area.orientation = :vertical
      @renderer.set_padding 10, 0
      @renderer.foreground = "blue"
      @comp.set_cell_data_func(renderer, ->(layout, renderer, model, iter, data) {
          renderer.text = model.get_value(iter, 1).get_string
        }, nil, nil)

      GObject.signal_connect(@comp, "match-selected") do |comp, _, iter, _|
        url = comp.get_model.get_value(iter, 0).get_string
        @entry.text = url
        @gui.on_apply
        true
      end
      @comp.set_model @model

      @entry.set_completion @comp
    end

    def update data
      return  unless @model
      @model.clear
      data.each do |url, title|
        next  unless url || title
        row = @model.append
        @model.set_value(row, 0, url || '')
        @model.set_value(row, 1, title || '')
      end

    end
  end
end
