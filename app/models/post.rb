class Post < ActiveRecord::Base
  has_many :comments
  attr_accessor :title, :summary, :svg, :content
  FILESTORE = "db/blog/#{RAILS_ENV}"

  def self.import! filename
    open(filename) do |file|
      post = Post.new
      title = file.gets.strip
      post.title = title unless title.empty?
      post.created_at = file.mtime
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
      @content.sub! /^<div class="excerpt".*<\/div>\n?/m do |summary|
        @summary = summary.sub(/<div class="excerpt".*?>/,'').
          sub(/<\/div>\n?\z/,'')
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

  def svg_div scale=0.0625
    return unless svg
    height = width = viewBox = nil
    decl, rest = svg.split('>',2)
    decl.sub!(/ width=['"](\d+)["']/) {width=$i.to_i; ''}
    decl.sub!(/ height=['"](\d+)["']/) {height=$i.to_i; ''}
    decl.sub!(/ viewBox=['"]([-\d\s\.]+)["']/) do |points|
      viewBox=points.split.map {|point| point.to_i}
      ''
    end
    viewBox = [0,0,width,height] if width and height and !viewBox

    "<div style='width:#{viewBox[2]*scale}em; " +
      "height:#{viewBox[3]*scale}em; float:right'>#{decl} " +
      "viewBox='#{viewBox.join(' ')}'>#{rest}</div>"
  end
end
