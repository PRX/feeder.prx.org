require 'test_helper'

class TestEncoder
  include FixerEncoder
end

describe FixerEncoder do

  let(:model) { TestEncoder.new }
  let(:cache_control) { 'x-fixer-Cache-Control=max-age%3D86400' }
  let(:query_str) { "x-fixer-public=true&#{cache_control}" }

  it 'starts a fixer job' do
    sqs = SqsMock.new('my-id')
    TestEncoder.stub :new_fixer_sqs_client, sqs do
      opts = {callback: 'sqs://cb', job_type: 'blah', source: 's3://src', destination: 's3://dest'}
      model.fixer_start!(opts)
      sqs.job[:job][:id].must_equal 'my-id'
      sqs.job[:job][:job_type].must_equal 'blah'
      sqs.job[:job][:original].must_equal 's3://src'
      sqs.job[:job][:tasks][0][:result].must_equal "s3://dest?#{query_str}"
    end
  end

end
