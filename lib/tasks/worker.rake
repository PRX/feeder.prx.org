task :worker do
  exec("bundle exec shoryuken --rails --config config/shoryuken.yml --require ./app/workers")
end

task w: :worker
