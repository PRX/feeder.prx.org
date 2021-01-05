require 'test_helper'

class TestSanitizer
  include TextSanitizer
end

describe TextSanitizer do
  let(:model) { TestSanitizer.new }
  let(:text) do
    '<!-- Sorry! --><p>my</p> <b>dog & cat</b> <a href="/">ate</a> ' +
    '<span><div>my</div></span> <script>homework</script>'
  end

  it 'scrubs all tags' do
    assert_equal model.sanitize_text_only(text), 'my dog & cat ate my '
  end

  it 'leaves ampersands alone' do
    assert_equal model.sanitize_text_only('Us & Them'), 'Us & Them'
  end

  it 'scrubs all but links' do
    r = 'my dog &amp; cat <a href="/">ate</a> my '
    assert_equal model.sanitize_links_only(text), r
  end

  it 'scrubs all but white listed' do
    r = '<p>my</p> <b>dog &amp; cat</b> <a href="/">ate</a> <span><div>my</div></span> '
    assert_equal model.sanitize_white_list(text), r
  end

  it 'white lists tables' do
    text = "<table>\n<thead></thead>\n<tbody>\n<tr>\n<th></th>\n<td></td>\n</tr>\n" +
           "<caption></caption>\n</tbody>\n<tfoot></tfoot>\n</table>"
    assert_equal model.sanitize_white_list(text), text
  end
end
