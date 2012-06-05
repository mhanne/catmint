require 'xapian'

module Catmint
  class History

    attr_reader :gui
    def db; gui.db rescue nil; end

    def initialize gui
      @gui = gui
      @db = Xapian::WritableDatabase.new(File.join(gui.config[:datadir], "database"),
        Xapian::DB_CREATE_OR_OPEN)
    end

    def add url, title, html
      return  unless url && title && url =~ /(.*?):\/\/(.*?).(.*?)/
      hash = Digest::SHA2.hexdigest(url.to_s.sub("://", '__'))
      data = {:url => url, :title => title, :last_visit => Time.now}

      pl = @db.postlist("Q#{hash}")
      if pl.any?
        doc = @db.document(pl.first.docid)
        d = JSON::load(doc.data)
        data[:times_visited] = d["times_visited"] + 1
      else
        doc = Xapian::Document.new
        data[:times_visited] = 1
      end
      doc.data = data.to_json
      doc.add_term("Q#{hash}")

      indexer = Xapian::TermGenerator.new
      indexer.stemmer = Xapian::Stem.new("english")
      indexer.document = doc
      indexer.index_text(html)

      doc.docid > 0 ? @db.replace_document(doc.docid, doc) : @db.add_document(doc)
    end

    def list
      @db.postlist("").map{|d| @db.document(d.docid)}
        .map{|d| JSON::load(d.data)}.map{|d|[d["url"], d["title"]]}
    end

    def search query_string
      parser = Xapian::QueryParser.new
      parser.stemmer = Xapian::Stem.new("english")
      parser.database = @db
      parser.stemming_strategy = Xapian::QueryParser::STEM_SOME
      enquire = Xapian::Enquire.new(@db)
      enquire.query = parser.parse_query(query_string, Xapian::QueryParser::FLAG_PARTIAL)
      enquire.mset(0, 10)
    end

  end
end
