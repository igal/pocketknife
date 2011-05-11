require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Pocketknife" do
  describe "new" do
    before do
      @pocketknife = Pocketknife.new
    end

    it "should instantiate a Pocketknife" do
      @pocketknife.should be_a_kind_of(Pocketknife)
    end

    it "should have normal verbosity" do
      @pocketknife.verbosity.should be_nil
    end

    it "should prompt for installation if needed" do
      @pocketknife.can_install.should be_nil
    end

    it "should have a NodeManager instance" do
      @pocketknife.node_manager.should be_a_kind_of(Pocketknife::NodeManager)
    end

    it "should have a NodeManager instance that knows about it" do
      @pocketknife.node_manager.pocketknife.should == @pocketknife
    end
  end

  describe "cli" do
    describe "create" do
      describe "without name" do
        it "should raise an exception and not create anything" do
          mktmpdircd do |dir|
            lambda { Pocketknife.cli(['-c', '-q']) }.should raise_error(Errno::ENOENT)
            Dir["#{Dir.pwd}/*"].should be_empty
          end
        end
      end
    end
  end

  describe "create" do
    it "should create a project" do
      mktmpdircd do |dir|
        project = 'myproject'
        Pocketknife.new(:verbosity => false).create(project)
        Dir["#{Dir.pwd}/#{project}/*"].should_not be_empty
        Dir["#{Dir.pwd}/#{project}/cookbooks"].should_not be_empty
        Dir["#{Dir.pwd}/#{project}/nodes"].should_not be_empty
        Dir["#{Dir.pwd}/#{project}/roles"].should_not be_empty
        Dir["#{Dir.pwd}/#{project}/site-cookbooks"].should_not be_empty
      end
    end
  end

  describe "node" do
    before(:each) do
      @previous_dir = Dir.pwd
      @dir = mkproject
    end

    after(:each) do
      FileUtils.rm_rf(@dir) if @dir
      Dir.chdir(@previous_dir)
    end

    it "should fail when asked to return an unknown node" do
      node = "foo"
      pocketknife = Pocketknife.new
      begin
        pocketknife.node(node)
      rescue Pocketknife::NoSuchNode => e
        e.node.should == node
      else
        fail "Exception wasn't thrown"
      end
    end

    it "should return a known node, that has a name and pocketknife" do
      name = "mynode"
      path = Pathname.new("nodes/#{name}.json")
      path.open("w") do |h|
        h.write("{}")
      end

      pocketknife = Pocketknife.new
      node = pocketknife.node(name)

      node.name.should == name
      node.pocketknife.should == pocketknife
    end
  end
end
