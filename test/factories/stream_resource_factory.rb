FactoryBot.define do
  factory :stream_resource do
    start_at { "2025-12-17T15:00:00Z" }
    end_at { "2025-12-17T16:00Z" }
    actual_start_at { "2025-12-17 14:55:21Z" }
    actual_end_at { "2025-12-17 16:07:21Z" }

    original_url { "s3://prx-testing/test/audio.mp3" }

    status { "complete" }
    mime_type { "audio/mpeg" }
    file_size { 774059 }
    bit_rate { 128 }
    sample_rate { 44100 }
    channels { 2 }
    duration { 4320.0 }
  end
end
