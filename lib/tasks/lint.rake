task :lint do
  puts "---------- linting standardrb ----------".blue
  exit1 = system("bundle exec standardrb")

  puts "\n---------- linting erblint -------------\n".blue
  exit2 = system("bundle exec erblint --lint-all --format compact")

  abort unless exit1 && exit2
end

namespace "lint" do
  task :fix do
    puts "---------- fixing standardrb ----------".blue
    exit1 = system("bundle exec standardrb --fix")

    puts "\n---------- fixing erblint -------------\n".blue
    exit2 = system("bundle exec erblint --lint-all --autocorrect")

    abort unless exit1 && exit2
  end
end
