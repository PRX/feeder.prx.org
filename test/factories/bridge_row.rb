FactoryGirl.define do
  factory :bridge_row, class: Hash do

    request_metadata { {} }
    api_parameters do
      { data:
        { type: 'someType',
          attributes: {some: 'attr'}
        }
      }.with_indifferent_access
    end
    api_url { 'http://a-fine-api.api '}
    api_response do
      { ok: true,
        err: false,
        val: {
          data: {some: 'response'}
        }
      }.with_indifferent_access
    end

    initialize_with { attributes } 

    factory :bridge_row_error do
      api_response do
        { ok: false,
          err: true,
          val: {
            data: {some: 'response'}
          }
        }.with_indifferent_access
      end
    end
  end
end
