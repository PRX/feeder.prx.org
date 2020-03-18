port ENV['PORT'] || 3000
environment ENV['RAILS_ENV'] || 'development'
workers 0
threads 0, 16
