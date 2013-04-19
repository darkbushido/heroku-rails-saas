require 'spec_helper'

describe HerokuRailsSaas::Helper do  
  describe "color methods" do
    it "should defined by HerokuRailsSaas::Helper::COLORS" do
      described_class.const_get("COLORS").each do |color|
        described_class.methods.should include(color.to_sym)
      end
    end

    it "should output color font" do
      described_class.red("message").should == "\e[31mmessage\e[0m"
      described_class.green("message").should == "\e[32mmessage\e[0m"
      described_class.yellow("message").should == "\e[33mmessage\e[0m"
      described_class.magenta("message").should == "\e[35mmessage\e[0m"
      described_class.cyan("message").should == "\e[36mmessage\e[0m"
    end
  end
end