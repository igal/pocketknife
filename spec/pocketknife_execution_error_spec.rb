require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Pocketknife::ExecutionError" do
  describe "when raised while executing without immediate output" do
    before do
      @rye_err = mock(Rye::Err,
        :exit_status => 1,
        :stdout => "hello",
        :stderr => "oh noes!!1!")
      @error = Pocketknife::ExecutionError.new("mynode", "mycommand", @rye_err, false)
      @message = @error.to_s
    end

    describe "object" do
      subject { @error }

      its(:node) { should == "mynode" }
      its(:exit_status) { should == 1 }
      its(:cause) { should == @rye_err }
      its(:immediate) { should == false }
    end

    it "should have a detailed message" do
      @message.should == <<-HERE.chomp
Failed while executing commands on node 'mynode'
- COMMAND: mycommand
- EXIT STATUS: 1
- STDOUT: hello
- STDERR: oh noes!!1!
      HERE
    end
  end

  describe "when raised while executing with immediate output" do
    before do
      @rye_err = mock(Rye::Err,
        :exit_status => 1,
        :stdout => "hello",
        :stderr => "oh noes!!1!")
      @error = Pocketknife::ExecutionError.new("mynode", "mycommand", @rye_err, true)
      @message = @error.to_s
    end

    describe "object" do
      subject { @error }

      its(:node) { should == "mynode" }
      its(:exit_status) { should == 1 }
      its(:cause) { should == @rye_err }
      its(:immediate) { should == true }
    end

    it "should have a detailed message" do
      @message.should == <<-HERE.chomp
Failed while executing commands on node 'mynode'
- COMMAND: mycommand
- EXIT STATUS: 1
      HERE
    end
  end
end
