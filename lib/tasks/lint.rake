task :lint do
  puts "---------- linting standardrb ----------".blue
  exit1 = system("bundle exec standardrb")

  puts "\n---------- linting erblint -------------\n".blue
  exit2 = system("bundle exec erblint --lint-all --format compact")

  puts "\n---------- linting prettier ------------\n".blue
  exit3 = system("npx prettier --check .")

  abort unless exit1 && exit2 && exit3
end

namespace "lint" do
  task :fix do
    puts "---------- fixing standardrb ----------".blue
    exit1 = system("bundle exec standardrb --fix")

    puts "\n---------- fixing erblint -------------\n".blue
    exit2 = system("bundle exec erblint --lint-all --autocorrect")

    puts "\n---------- fixing prettier ------------\n".blue
    exit3 = system("npx prettier --write --list-different .")

    abort unless exit1 && exit2 && exit3
  end
end
