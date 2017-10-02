require 'test_helper'

class TestSanitizer
  include TextSanitizer
end

describe TextSanitizer do
  let(:model) { TestSanitizer.new }
  let(:text) do
    '<!-- Sorry! --><p>my</p> <b>dog</b> <a href="/">ate</a> ' +
    '<span><div>my</div></span> <script>homework</script>'
  end

  it 'scrubs all tags' do
    model.sanitize_text_only(text).must_equal 'my dog ate my '
  end

  it 'leaves ampersands alone' do
    model.sanitize_text_only('Us & Them').must_equal 'Us & Them'
  end

  it 'scrubs all but links' do
    r = 'my dog <a href="/">ate</a> my '
    model.sanitize_links_only(text).must_equal r
  end

  it 'scrubs all but white listed' do
    r = '<p>my</p> <b>dog</b> <a href="/">ate</a> <span><div>my</div></span> '
    model.sanitize_white_list(text).must_equal r
  end

  it 'white lists tables' do
    text = "<table>\n<thead></thead>\n<tbody>\n<tr>\n<th></th>\n<td></td>\n</tr>\n" +
           "<caption></caption>\n</tbody>\n<tfoot></tfoot>\n</table>"
    model.sanitize_white_list(text).must_equal text
  end
end
