FactoryGirl.define do
  factory :copy_image_task, class: Tasks::CopyImageTask do
    association :owner, factory: :episode_image_with_episode
    status :complete
    result task: {
      result_details: {
        info: {
            size: 774059,
            content_type: 'image/png'
        }
      }
    }
  end
end
