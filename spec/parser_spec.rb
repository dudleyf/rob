require 'rob'
require 'pry'

describe Rob::Parser do
  def parse(str)
    Rob::Parser.new.parse(str)
  end

  it "should parse booleans" do
    parse("#t").should == [Rob::Boolean.new(true)]
    parse("#f").should == [Rob::Boolean.new(false)]
  end

  it "should parse numbers" do
    parse("1").should == [Rob::Number.new(1)]
    parse("#b10").should == [Rob::Number.new(2)]
    parse("#d10").should == [Rob::Number.new(10)]
    parse("#x10").should == [Rob::Number.new(16)]
  end

  it "should parse symbols" do
    parse("foo").should == [Rob::Symbol.new('foo')]
  end

  it "should parse a list" do
    foo = Rob::Symbol.new('foo')
    bar = Rob::Symbol.new('bar')

    parse("(foo bar)").should == [
      Rob::Pair.new(foo, Rob::Pair.new(bar, nil))
    ]
  end
end
