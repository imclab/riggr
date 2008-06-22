require File.dirname(__FILE__) + '/../test_helper'

class PostTest < ActiveSupport::TestCase
  def setup
    # create an index entry
    @post = Post.new
    @post.created_at = Time.utc(2008,06,21,12,34,56)
  end

  def teardown
    FileUtils.rm_rf Post::FILESTORE
  end

  def test_filestore
    assert_equal 'db/blog/test', Post::FILESTORE
  end

  def test_filename
    @post.slug = 'slug'
    assert_equal '2008/06/21/slug', @post.filename
  end

  def test_generate_slug_from_title
    # simple title
    @post.title = 'title'
    assert_equal 'title', @post.slug

    # title with spaces
    @post.title = '  title with   spaces  '
    assert_equal 'title-with-spaces', @post.slug

    # title with apostrophe
    @post.title = "slug's revenge"
    assert_equal 'slugs-revenge', @post.slug

    # title with punctuation
    @post.title = 'very, very, bad title'
    assert_equal 'very-very-bad-title', @post.slug

    # title with entity
    @post.title = "slug&#8217;s revenge"
    assert_equal 'slugs-revenge', @post.slug

    # title with markup
    @post.title = 'very, <b>very</b>, bad title'
    assert_equal 'very-very-bad-title', @post.slug
  end

  def test_file_backingstore
    # save the index entry and create the corresponding file
    @post.slug = 'lipsum'
    @post.save!
    filename = "#{Post::FILESTORE}/#{@post.filename}"
    FileUtils.mkdir_p File.dirname(filename)
    open(filename,'w') { |file| file.write "loren\nipsum\n" }

    # verify that the file augments the model after a find occurs
    @post = Post.find(:first, :conditions => ['slug = ?', 'lipsum'])
    assert_equal 'loren', @post.title
    assert_equal "ipsum\n", @post.content
    assert_nil @post.svg
    assert_nil @post.summary
  end

  def test_import
    # import a test file
    open('tmp/import.txt','w') { |file| file.write("loren\n\ipsum\n") }
    File.utime @post.created_at, @post.created_at, 'tmp/import.txt'
    Post.import! 'tmp/import.txt'

    # verify results
    @post = Post.find(:first, :conditions => ['slug = ?', 'import'])
    assert_equal 'loren', @post.title
    assert_equal Time.utc(2008,06,21,12,34,56), @post.created_at
    assert_equal Time.utc(2008,06,21,12,34,56), @post.updated_at
    assert_equal '2008/06/21/import', @post.filename
  ensure
    File.unlink('tmp/import.txt')
  end

  # support for test_excerpt
  def import(string)
    open('tmp/import.txt','w') { |file| file.write(string.gsub(/^      /,'')) }
    Post.import! 'tmp/import.txt'
    @post = Post.find(:first, :conditions => ['slug = ?', 'import'])
  end

  def test_excerpt
    # no excerpt
    import("\n" + <<-'EOF')
      bar
    EOF

    assert_equal nil, @post.summary
    assert_equal "bar\n", @post.content
    assert_equal @post.created_at, @post.updated_at

    # simple excerpt
    import("\n" + <<-'EOF')
      <div class="excerpt">foo</div>
      bar
    EOF

    assert_equal 'foo', @post.summary
    assert_equal "bar\n", @post.content
    assert_not_equal '2008-06-21T12:34:56Z', @post.updated_at.utc.iso8601

    # excerpt + updated
    import("\n" + <<-'EOF').summary
      <div class="excerpt" updated="2008-06-21T12:34:56Z">foo</div>
      bar
    EOF

    assert_equal 'foo', @post.summary
    assert_equal "bar\n", @post.content
    assert_equal '2008-06-21T12:34:56Z', @post.updated_at.utc.iso8601

    # updated, no excerpt
    import("\n" + <<-'EOF').summary
      <div class="excerpt" updated="2008-06-21T12:34:56Z"/>
      bar
    EOF

    assert_equal nil, @post.summary
    assert_equal "bar\n", @post.content
    assert_equal '2008-06-21T12:34:56Z', @post.updated_at.utc.iso8601

    # multiline excerpt
    import("\n" + <<-'EOF').summary
      <div class="excerpt" updated="2008-06-21T12:34:56Z">
        foo
      </div>
      bar
    EOF

    assert_equal 'foo', @post.summary
    assert_equal "bar\n", @post.content
    assert_equal '2008-06-21T12:34:56Z', @post.updated_at.utc.iso8601
  end
end
