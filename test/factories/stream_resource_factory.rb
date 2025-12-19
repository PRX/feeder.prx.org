FactoryBot.define do
  factory :stream_resource do
    start_at { "2025-12-18T13:00:00Z" }
    end_at { "2025-12-18T14:00:00Z" }
    actual_start_at { "2025-12-18T12:59:50Z" }
    actual_end_at { "2025-12-18T14:00:10Z" }

    original_url { "s3://prx-testing/test/audio.mp3" }

    status { "complete" }
    mime_type { "audio/mpeg" }
    file_size { 774059 }
    bit_rate { 128 }
    sample_rate { 44100 }
    channels { 2 }
    duration { 3620.0 }
  end
end
