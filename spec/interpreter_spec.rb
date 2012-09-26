require 'rob'
require 'pry'

FIXTURE_DIR = 'spec/testcases'
describe Rob::Interpreter do
  Dir["#{FIXTURE_DIR}/**/*.scm"].sort.each do |f|
    test_name = File.basename(f, '.scm')

    it test_name do
      code = File.read(f)
      expected_path = File.join(FIXTURE_DIR, test_name + '.exp.txt')
      expected = File.read(expected_path)
      output = StringIO.new
      Rob.interpret(code, output)
      output.string.should == expected
    end
  end
end
