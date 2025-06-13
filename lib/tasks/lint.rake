class LintUtils
  PRINT_CHAR = "-"
  PRINT_PREFIX = 15
  PRINT_WIDTH = 50
  PRINT_COLOR = 34

  def self.puts(str, is_first = true)
    padded = "#{PRINT_CHAR * PRINT_PREFIX} #{str} ".ljust(PRINT_WIDTH, PRINT_CHAR)
    color = "\e[#{PRINT_COLOR}m#{padded}\e[0m"
    if @has_printed
      print "\n#{color}\n\n"
    else
      @has_printed = true
      print "#{color}\n\n"
    end
  end
end

task :lint do
  LintUtils.puts("linting standardrb")
  exit1 = system("bundle exec standardrb")

  LintUtils.puts("linting erb_lint")
  exit2 = system("bundle exec erb_lint --lint-all --format compact")

  LintUtils.puts("linting prettier")
  exit3 = system("npx prettier --check .")

  abort unless exit1 && exit2 && exit3
end

namespace "lint" do
  task :fix do
    LintUtils.puts("fixing standardrb")
    exit1 = system("bundle exec standardrb --fix")

    LintUtils.puts("fixing erb_lint")
    exit2 = system("bundle exec erb_lint --lint-all --autocorrect")

    LintUtils.puts("fixing prettier")
    exit3 = system("npx prettier --write --list-different .")

    abort unless exit1 && exit2 && exit3
  end
end
