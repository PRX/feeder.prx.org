require "test_helper"

class TestSanitizer
  include TextSanitizer
end

describe TextSanitizer do
  let(:model) { TestSanitizer.new }
  let(:text) do
    "<!-- Sorry! --><p>my</p>" \
    "     <b>dog & cat</b> <a href=\"/\">ate</a><span>" \
    "<div>my</div>" \
    "</span><script>homework</script>"
  end

  it "scrubs all tags" do
    assert_equal model.sanitize_text_only(text), "my\ndog & cat ate\nmy"
  end

  it "leaves ampersands alone" do
    assert_equal model.sanitize_text_only("Us & Them"), "Us & Them"
  end

  it "scrubs all but links" do
    r = "my\ndog &amp; cat <a href=\"/\">ate</a>\nmy"
    assert_equal model.sanitize_links_only(text), r
  end

  it "adds space near some tags" do
    t = "0<p>1</p>2<br>3<br />4<br/>5<div>6</div>7"
    assert_equal model.add_newlines_to_tags(t), "0\n<p>1</p>\n2\n<br>3\n<br>4\n<br>5\n<div>6</div>\n7"
  end

  it "adds space for removed tags" do
    t = " 0<p>1</p>2<br>3<br />4<br/>5<div> 6 </div>7 "
    assert_equal model.sanitize_links_only(t), "0\n1\n2\n3\n4\n5\n6\n7"
  end

  it "scrubs all but white listed" do
    r = '<p>my</p> <b>dog &amp; cat</b> <a href="/">ate</a><span><div>my</div></span>'
    assert_equal model.sanitize_white_list(text), r
  end

  it "white lists tables" do
    text = "<table>\n<thead></thead>\n<tbody>\n<tr>\n<th></th>\n<td></td>\n</tr>\n" \
      "<caption></caption>\n</tbody>\n<tfoot></tfoot>\n</table>"
    assert_equal model.sanitize_white_list(text), text
  end
end
