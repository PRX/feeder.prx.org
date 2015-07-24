require 'test_helper'


class SqsMock
  def initialize(id = nil)
    @id = id || '11111111'
  end

  def create_job(j)
    j[:job][:id] = @id
    j
  end
end

describe Tasks::CopyAudioTask do
  let(:task) { create(:copy_audio_task) }

  let(:msg) do
    %{
      {
        "_links": {
          "curies": [{
            "name": "prx",
            "href": "http://meta.prx.org/relation/{rel}",
            "templated": true
          }],
          "self": {
            "href": "/api/v1/stories/80548",
            "profile": "http://meta.prx.org/model/story"
          },
          "prx:account": {
            "href": "/api/v1/accounts/125347",
            "title": "American Routes",
            "profile": "http://meta.prx.org/model/account/group"
          },
          "prx:audio": {
            "href": "/api/v1/stories/80548/audio_files",
            "count": 2
          }
        }
      }
    }
  end

  let(:audio_msg) do
    %{
      {
        "_links": {
          "curies": [{
            "name": "prx",
            "href": "http://meta.prx.org/relation/{rel}",
            "templated": true
          }],
          "self": {
            "href": "/api/v1/stories/80548/audio_files",
            "profile": "http://meta.prx.org/model/collection/audio-file"
          }
        },
        "count": 2,
        "total": 2,
        "_embedded": {
          "prx:items": [{
            "_links": {
              "self": {
                "href": "/api/v1/audio_files/406322",
                "profile": "http://meta.prx.org/model/audio-file"
              },
              "profile": {
                "href": "http://meta.prx.org/model/audio-file"
              },
              "enclosure": {
                "href": "/pub/80abf51e1bc69102259ef4eeca86ac8a/0/web/audio_file/406322/broadcast/AR0328segmentA.mp3",
                "type": "audio/mpeg"
              },
              "original": {
                "href": "/api/v1/audio_files/406322/original{?expiration}",
                "templated": true,
                "type": "audio/mpeg"
              }
            },
            "id": 406322,
            "filename": "AR0328segmentA.mp2",
            "label": "AR0328segmentA",
            "size": 33690581,
            "duration": 1054
          }, {
            "_links": {
              "self": {
                "href": "/api/v1/audio_files/406315",
                "profile": "http://meta.prx.org/model/audio-file"
              },
              "profile": {
                "href": "http://meta.prx.org/model/audio-file"
              },
              "enclosure": {
                "href": "/pub/cec6514f74e8caa075d4e28a0cc0788a/0/web/audio_file/406315/broadcast/AR0328cutaway1.mp3",
                "type": "audio/mpeg"
              },
              "original": {
                "href": "/api/v1/audio_files/406315/original{?expiration}",
                "templated": true,
                "type": "audio/mpeg"
              }
            },
            "id": 406315,
            "filename": "AR0328cutaway1.mp2",
            "label": "AR0328cutaway1",
            "size": 1955571,
            "duration": 61
          }]
        }
      }
    }
  end

  let(:story) do
    body = JSON.parse(msg)
    href = body['_links']['self']['href']
    resource = task.api
    link = HyperResource::Link.new(resource, href: href)
    HyperResource.new_from(body: body, resource: resource, link: link)
  end

  before do
    if use_webmock?
      stub_request(:get, "https://cms.prx.org/api/v1/stories/80548").
        to_return(status: 200, body: msg, headers: {})

      stub_request(:get, "https://cms.prx.org/api/v1/stories/80548/audio_files").
        to_return(status: 200, body: audio_msg, headers: {})

      stub_request(:get, "https://cms.prx.org/api/v1/audio_files/406322/original?expiration=604800").
        to_return(status: 301, body: '', headers: { location: 'http://final/location.mp3' } )

    end
  end

  it 'can start the job' do
    task.fixer_sqs_client = SqsMock.new
    task.stub(:get_account_token, "token") do
      task.start!
      task.options[:source].must_equal 'http://final/location.mp3'
      task.options[:destination].must_match /s3:\/\/test-prx-feed\/jjgo\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/AR0328segmentA.mp2/
      task.options[:audio_uri].must_equal '/api/v1/audio_files/406322'
    end
  end

  it 'creates a fixer job' do
    task.fixer_sqs_client = SqsMock.new
    job = task.fixer_copy_file(destination: 'dest', source: 'src')
    job[:job][:job_type].must_equal 'audio'
  end

  it 'alias owner as episode' do
    task.episode.must_equal task.owner
  end

  it 'knows what bucket to drop the file in' do
    task.feeder_storage_bucket.must_equal 'test-prx-feed'
  end

  it 'determines a destination url' do
    podcast = Minitest::Mock.new.expect(:path, 'path')
    episode = Minitest::Mock.new
    episode.expect(:podcast, podcast)
    episode.expect(:guid, 'guid')
    url = task.destination_url(episode, story)
    url.must_equal 's3://test-prx-feed/path/guid/AR0328segmentA.mp2?x-fixer-public=true'
  end

  it 'uses an sqs queue for callbacks' do
    task.fixer_call_back_queue.must_equal 'sqs://us-east-1/test_feeder_fixer_callback'
  end

  it 'returns enclosure path' do
    task.audio_info[:content_type].must_equal 'audio/mpeg'
  end

  it 'determines the story audio uri' do
    task.story_audio_uri(story).must_equal '/api/v1/audio_files/406322'
  end

  it 'can publish on complete' do
    podcast = Minitest::Mock.new.expect(:publish!, true)
    episode = Minitest::Mock.new.expect(:podcast, podcast)
    task.stub(:episode, episode) do
      task.task_status_changed({})
    end
  end

  it 'can detect if the audio file has changed' do
    task.options = {}
    assert task.new_audio_file?(story)
  end
end
