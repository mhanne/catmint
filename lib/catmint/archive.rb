require 'evma_httpserver'
require 'filemagic'
require 'digest'

module Catmint

  class Archive
    SERVER_URL = "http://127.0.0.1:12345"
    ARCHIVE_DIR = File.join(ENV["HOME"], ".catmint", "archive")

    def initialize
      FileUtils.mkdir_p(ARCHIVE_DIR)
    end

    def write name, content
      File.open(path(name), "wb") {|f| f.write content }
    end

    def exists name
      File.exist?(path(name))
    end

    def read name
      return nil  unless exists(name)
      File.binread(path(name))
    end

    def mime name
      return nil  unless exists(name)
      FileMagic.open(:mime){|a| a.file(path(name))}.split(';')[0]
    end

    def path name
      hash = Digest::SHA2.hexdigest(name.to_s.sub("://", '__'))
      dir = File.join(ARCHIVE_DIR, hash[0...2])
      FileUtils.mkdir_p(dir)
      File.join(dir, hash)
    end
  end


  class ArchiveServer < EM::Connection
    include EM::HttpServer

    attr_reader :gui
    def initialize gui
      @gui = gui
    end

    def post_init
      super
      no_environment_strings
    end

    def process_http_request
      path = @http_request_uri
      path = "#{path}?#{@http_query_string}"  if @http_query_string
      uri = translate_path(path)
      uri = "#{uri}/"  unless uri.include?("/")
      content = gui.archive.read(uri)
      unless content
        return respond(404, "<h1>404 Not Found</h1><p>#{uri}</p>")
      end
      base_uri = translate_url(uri)
      if gui.archive.mime(uri) == "text/html"
        content = replace(content, "a", "href", base_uri)
        content = replace(content, "link", "href", base_uri)
        content = replace(content, "img", "src", base_uri)
      end
      respond(200, content)
    rescue
      respond(500, "<h1>500 Error</h1><p>#{$!.message}</p>")
    end

    def respond(status, content, content_type = nil)
      res = EM::DelegatedHttpResponse.new(self)
      res.status = status
      res.content = content
      res.content_type = content_type  if content_type
      res.send_response
    end

    def replace html, tag, attr, base_uri
      html.gsub(/<#{tag}(.*?)#{attr}=["|'](.*?)["|'](.*?)[>(.*?)<\/#{tag}>|\/?>]/) do |match|
        match.sub(/#{attr}=["|'](.*?)["|']/) do |match|
          begin
            u = $1.sub(/^\//, '').gsub("&amp;", "&")
            if u =~ /:\/\//
              proto, rest = u.split("://")
              domain, path = rest.split("/", 2)
              u = "/#{domain}/#{path}"
            end
            if u =~ /^[\/|#]/
              u = "#{u[1..-1]}"
            end

            u = u.sub!(/(.*?)\.(.*?)\//, '')  if u[/(.*?)\.(.*?)\//] == base_uri.path[/__(.*?)\.(.*?)\//].split("__")[1]
            
            uri = base_uri.merge(URI.parse(u))
            next  unless uri.path
            path = "#{uri.path}".sub(/^\//, '')
            path += "?#{uri.query}"  if uri.query

            link_exists = gui.archive.exists path
            if link_exists
              str = "#{attr}='#{uri.to_s.gsub("&", "&amp;")}'"
            else
              _, host, path = uri.path.split('/', 3)
              proto, host = host.split('__')
              str = "#{proto}://#{host}/#{path}"
              str += "?#{uri.query}"  if uri.query
              uri = URI.parse(str)
              str = "#{attr}='#{uri.to_s.gsub("&", "&amp;")}'"
              if tag == "a" && !link_exists
                str += " style='color:red; text-decoration: line-through'"
              end
            end
            str
          rescue
            p $!
            match
          end
        end
      end
    rescue
      p $!
      puts *$@
    end

    def translate_url url, base = nil
      base = URI.parse(Catmint::Archive::SERVER_URL).merge((URI.parse(base) rescue "/"))
      base.merge(URI.parse(url))
    end

    def translate_path path
      URI.parse(path.split('/', 2)[1]).to_s
    end

  end
end
