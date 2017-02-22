class LvacReporter < MiniTest::Reporter
  def initialize(*)
    super
    @assertions = 0
    @failed = 0
  end

  def passed?
    @failed.zero?
  end

  def start
    io.puts
    io.puts "--------------------------------------------------------------------------------"
    io.puts
  end

  def record(results)
    @assertions += [results.assertions, 1].max
    results.failures.each do |error|
      io.puts "* #{error}"
      io.puts
      @failed += 1
    end
  end

  def report
    if passed?
      io.puts "#{@assertions} tests ran and they all passed. Well done, everything looks hunky dory."
    elsif @failed == 1
      io.puts "Nearly there, there was only one problem that needs to be fixed."
    else
      io.puts "Looks like there were #{@failed} problems that need to be fixed."
    end
    io.puts "--------------------------------------------------------------------------------"
    io.puts
  end
end

module MiniTest
  def self.plugin_lvac_init(options)
    Minitest.reporter.reporters.clear
    Minitest.reporter << LvacReporter.new
  end
end
