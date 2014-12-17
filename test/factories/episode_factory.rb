FactoryGirl.define do
  factory :episode do
    podcast

    title sequence {|n| "#{n}: Nut Shake with Tess Rafferty" }
    description 'Tess Rafferty joins Jordan and Jesse for jokes about things'
    link 'http://www.maximumfun.org/jordan-jesse-go/jordan-jesse-go-episode-354-nut-shake-tess-rafferty'
    author 'Jesse Thorn'
    pub_date Time.now
    categories 'comedy, humor'
    audio_file 'http://traffic.libsyn.com/thornmorris/jjgo141208_ep354.mp3'
    comments 'http://www.maximumfun.org/jordan-jesse-go/jordan-jesse-go-episode-354-nut-shake-tess-rafferty#comments'
    subtitle 'with Tess Rafferty'
    summary 'Tess Rafferty, Jordan Morris, and Jesse Thorn make funny jokes and goofs'
    explicit true
    duration 5400
    keywords 'laughs, jokes'

    after(:build) do |e|
      build(:image, imageable: e)
    end
  end
end
