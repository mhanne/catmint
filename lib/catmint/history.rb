require 'sequel'

module Catmint
  class History

    def initialize
      connect
    end

    # connect to database
    def connect
      @db = Sequel.connect("sqlite://#{File.join(ENV['HOME'], '.catmint', 'history.db')}")
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

    def add url, title, content
      return  unless url && title && url =~ /(.*?):\/\/(.*?).(.*?)/
      existing = @db[:page].filter(:url => url)
      if existing.any?
        existing.update(:title => title,
          :last_visit => Time.now,
          :times_visited => existing.first[:times_visited] + 1,
          :content => content)
      else
        @db[:page].insert({:url => url, :title => title,
            :last_visit => Time.now, :times_visited => 1,
            :content => content})
      end
    end

    def list
      @db[:page].sort_by {|p| p[:times_visited]}.reverse.map do |p|
        [p[:url], p[:title]]
      end
    end

    def search query
      terms = query.split(" ").map(&:upcase)
      results = []
      terms.reverse.each do |term|
        @db[:page].where("UPPER(url) LIKE '%#{term}%' OR " +
          "UPPER(title) LIKE '%#{term}%' OR " +
          "UPPER(content) LIKE '%#{term}%'")
          .order("times_visited").all.each {|r| results << r}
      end
      results.uniq
    end

  end
end
