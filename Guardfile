guard :bundler do
  watch('Gemfile')
end

guard :minitest, spring: true, env: {GUARD: 'true'}, all_env: :GUARD_COVERAGE, all_after_pass: false do
  watch(%r{^app/models/(.+)\.rb$})                        { |m| "test/models/#{m[1]}_test.rb" }
  watch(%r{^app/controllers/application_controller\.rb$}) { 'test/controllers' }
  watch(%r{^app/controllers/(.+)_controller\.rb$})        { |m| "test/integration/#{m[1]}_test.rb" }
  watch(%r{^app/jobs/(.+)\.rb$})                          { |m| "test/jobs/#{m[1]}_test.rb" }
  watch(%r{^app/views/(.+)_mailer/.+})                    { |m| "test/mailers/#{m[1]}_mailer_test.rb" }
  watch(%r{^lib/(.*/)?([^/]+)\.rb$})                      { |m| "test/lib/#{m[1]}#{m[2]}_test.rb" }
  watch(%r{^test/.+_test\.rb$})
  watch(%r{^test/test_helper\.rb$})                       { 'test' }
  watch(%r{^test/factories/(.+)_factory\.rb$})            { |m| "test/models/#{m[1]}_test.rb" }
end
