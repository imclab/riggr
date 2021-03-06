class Post < ActiveRecord::Base
  has_many :comments
  attr_accessor :title, :summary, :svg, :content
  FILESTORE = "db/blog/#{RAILS_ENV}"
  @@coder = HTMLEntities.new

  def self.import! filename
    open(filename) do |file|
      post = Post.new
      title = file.gets.strip
      post.title = title unless title.empty?
      post.created_at = file.mtime.utc
      name = File.basename(filename)
      if name =~ /^(\d+)\.txt/
        post.alt = $1.to_i
      else
        post.slug = name.gsub(/\.txt/,'').gsub('_','-')
      end
      dest = "#{Post::FILESTORE}/#{post.filename}"
      FileUtils.mkdir_p File.dirname(dest)
      FileUtils.cp filename, dest, :preserve => true
      post.save!
    end
  end

  def after_find
    open("#{Post::FILESTORE}/#{filename}") do |file|
      @title = file.gets.chomp
      @content = file.read
      self.updated_at = self.created_at
      @content.sub! /^<div class="excerpt".*?(\/>|<\/div>)\n?/m do |summary|
        @summary = summary.sub(/<\/div>\n?\z/,'').sub(/^.*?>\s*/) do |div|
          self.updated_at = Time.parse($1) if div =~ / updated="(.*?)"/
          ''
        end
        @summary = nil if @summary.empty?
        '' 
      end
      @content.sub! /^<svg .*<\/svg>\n?/m do |svg|
        @svg = svg.strip
        '' 
      end
    end
  rescue
  end

  def filename
    self.created_at.strftime('%Y/%m/%d/') + (self.slug || self.alt.to_s)
  end

  def title= title
    @title = title
    self.slug = @title.gsub("'",'').gsub(/\&#?\w+;/,'').gsub(/<.*?>/,'').
      gsub(/\W/,' ').strip.gsub(/\s+/,'-')
  end

  def self.decode(string)
    return unless string
    string.gsub(/(&\w+;)/) { |entity|
      if %w[ &amp; &lt; &gt; &quot; &apos; ].include? entity
        entity
      else
        @@coder.decode(entity)
      end
    }
  end

  def title
    Post::decode @title
  end

  def content
    Post::decode @content
  end

  def summary
    Post::decode @summary
  end

  def scaled_svg options={}
    return unless svg
    height = width = viewBox = nil
    decl, rest = svg.split('>',2)
    decl.sub!(/ width=['"](\d+)["']/) {width=$1.to_i; ''}
    decl.sub!(/ height=['"](\d+)["']/) {height=$1.to_i; ''}
    decl.sub!(/ viewBox=['"]([-\d\s\.]+)["']/) do
      viewBox=$1.split.map {|point| point.to_i}
      ''
    end
    viewBox = [0,0,width,height] if width and height and !viewBox

    scale = 0.05 * (options[:scale] || 1)
    output = "#{decl} viewBox='#{viewBox.join(' ')}' " + 
      "width='#{(viewBox[2]*scale).to_s.sub(/\.0$/,'')}em' " +
      "height='#{(viewBox[3]*scale).to_s.sub(/\.0$/,'')}em'>" +
      "#{rest}"

    output.gsub! /<(\w+)([^<]*)\/>/, '<\1\2></\1>' if options[:html]
    output
  end
end
