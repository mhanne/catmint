require 'sequel'
require 'distillery'

module Catmint
  class History

    attr_reader :gui
    def db; gui.db rescue nil; end

    def initialize gui
      @gui = gui
    end

    def add url, title, html
      return  unless url && title && url =~ /(.*?):\/\/(.*?).(.*?)/

      existing = db[:page].filter(:url => url)
      if existing.any?
        existing.update(:title => title,
          :last_visit => Time.now,
          :times_visited => existing.first[:times_visited] + 1,
          :content => extract_content(html))
      else
        db[:page].insert(:url => url, :title => title,
            :last_visit => Time.now, :times_visited => 1,
            :content => extract_content(html))
      end
    end

    def list
      db[:page].sort_by {|p| p[:times_visited]}.reverse.map do |p|
        [p[:url], p[:title]]
      end
    end

    def search query
      terms = query.split(" ").map(&:upcase)
      results = []
      terms.reverse.each do |term|
        db[:page].where("UPPER(url) LIKE '%#{term}%' OR " +
          "UPPER(title) LIKE '%#{term}%' OR " +
          "UPPER(content) LIKE '%#{term}%'")
          .order("times_visited").all.each {|r| results << r}
      end
      results.uniq
    end

    def extract_content html
      html.encode!("US-ASCII", :invalid => :replace, :undef => :replace)
      Distillery.distill(html).gsub!(/<(.*?)>/, '').gsub!(/\s+/, " ")
    rescue
      ""
    end

  end
end
