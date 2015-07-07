FactoryGirl.define do
  factory :copy_audio_task, class: Tasks::CopyAudioTask do
    association :owner, factory: :episode
    status :complete
  end
end
