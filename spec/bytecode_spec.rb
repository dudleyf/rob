require 'rob'
require 'pry'

describe Rob::BytecodeSerializer do
  let(:serializer) { Rob::BytecodeSerializer.new }

  it "serializes (write 2)" do
    c = Rob.compile("(write 2)")
    serializer.serialize_bytecode(c).should == 
      "\v\v\x01\x00cs\x00\x00\x00\x00[\x00\x00\x00\x00[\x01\x00\x00\x00n\x02\x00\x00\x00[\x01\x00\x00\x00s\x05\x00\x00\x00write[\x03\x00\x00\x00i\x00\x00\x00\x00i\x00\x00\x00\x10i\x01\x00\x00Q".encode!("ASCII")    
  end
end