require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "PocketKnife::NodeManager" do
  describe "#hostname_for" do
    before do
      @node_manager = Pocketknife::NodeManager.new(mock(Pocketknife))
    end

    it "should find a hostname that's the same as the node name" do
      @node_manager.stub(:known_nodes).and_return(["a.host.name"])
      @node_manager.hostname_for("a.host.name").should == "a.host.name"
    end

    it "should find a hostname when given an abbreviated node name" do
      @node_manager.stub(:known_nodes).and_return(["a.host.name"])
      @node_manager.hostname_for("a.host").should == "a.host.name"
    end

    it "should find a hostname when given a very abbreviated node name" do
      @node_manager.stub(:known_nodes).and_return(["a.host.name"])
      @node_manager.hostname_for("a").should == "a.host.name"
    end

    it "should fail to find hostname when given a non-unique abbreviated node name" do
      @node_manager.stub(:known_nodes).and_return(["a.host.name", "a.different.name"])
      begin
        @node_manager.hostname_for("a")
        fail "No exception was thrown!"
      rescue Pocketknife::NoSuchNode => e
        e.message.should == "Can't find unique node named 'a', this matches nodes: a.host.name, a.different.name"
      end
    end

    it "should fail to find hostname for a node that doesn't exist" do
    end
  end
end
