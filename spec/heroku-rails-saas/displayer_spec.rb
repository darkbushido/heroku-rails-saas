require 'spec_helper'

describe HerokuRailsSaas::Displayer do
  before(:each) do
    @color = "green"
    @remote_name = "Random"
    @displayer = described_class.new(@remote_name, @color)
  end  
  
  describe "#labelize" do
    before(:each) do
      @orig_stdout = $stdout
      @output_string_io = StringIO.new
      $stdout = @output_string_io
    end

    after(:each) do
      $stdout = @orig_stdout
    end

    context "with new_line enable" do
      it "should prepend 'output message' with a label 'Random' with a font color of 'green'" do
        @displayer.labelize("output message")
        @output_string_io.string.should == "[ \e[32mRandom\e[0m ] output message\n"
      end
    end

    context "with new_line disable" do
      it "should prepend 'output message' with a label 'Random' with a font color of 'green'" do
        @displayer.labelize("output message", false)
        @output_string_io.string.should == "[ \e[32mRandom\e[0m ] output message"
      end
    end
  end
end