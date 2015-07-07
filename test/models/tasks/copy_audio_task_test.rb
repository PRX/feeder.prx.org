require 'test_helper'

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

  it 'can publish on complete' do
    podcast = Minitest::Mock.new.expect(:publish!, true)
    episode = Minitest::Mock.new.expect(:podcast, podcast)
    task.stub(:episode, episode) do
      task.task_status_changed({})
    end
  end

  it 'can detect if the audio file has changed' do
    if use_webmock?
      stub_request(:get, "https://cms.prx.org/api/v1/stories/80548/audio_files").
        to_return(status: 200, body: audio_msg, headers: {})
    end

    task.options = {}
    assert task.new_audio_file?(story)
  end
end
