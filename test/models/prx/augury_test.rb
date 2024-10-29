require "test_helper"

describe Prx::Augury do
  let(augury) { Prx::Augury.new }

  it "retrieves placements" do
    assert augury.placements(1234)
  end
end
