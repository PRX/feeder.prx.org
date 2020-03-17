port ENV['PORT'] || 3000
environment ENV['RAILS_ENV'] || 'development'
workers 1
threads 0, 16
