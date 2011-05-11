require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "PocketKnife::Node" do
  def node_factory(name=nil, pocketknife=nil, connection=nil)
    name ||= "mynode"
    pocketknife ||= Pocketknife.new(:verbosity => false)
    node = Pocketknife::Node.new(name, pocketknife)
    node.stub(:connection => connection || true) unless connection == false
    return node
  end

  describe "::new" do
    before do
      @pocketknife = Pocketknife.new
      @name = "mynode"
      @node = node_factory(@name, @pocketknife)
    end

    it "should have a name" do
      @node.name.should == @name
    end

    it "should have a pocketknife" do
      @node.pocketknife.should == @pocketknife
    end
  end

  describe "#connection" do
    it "should instantiate a new connection" do
      node = node_factory(nil, nil, false)
      rye = mock(Rye::Box)
      rye.should_receive(:disable_safe_mode)
      Rye::Box.should_receive(:new).with("mynode", {:user => "root"}).and_return(rye)

      node.connection.should == rye
    end

    it "should return an existing connection" do
      node = node_factory(nil, nil, false)
      rye = mock(Rye::Box)
      rye.should_receive(:disable_safe_mode)
      Rye::Box.should_receive(:new).with("mynode", {:user => "root"}).and_return(rye)
      node.connection.should == rye

      node.connection.should == rye
    end
  end

  describe "#has_executable?" do
    before do
      @node = node_factory
    end

    it "should find an existing executable" do
      @node.connection.should_receive(:execute).with(%{which "chef-solo" && test -x `which "chef-solo"`}).and_return(true)

      @node.has_executable?("chef-solo").should be_true
    end

    it "should not find a missing executable" do
      @node.connection.should_receive(:execute).with(%{which "chef-solo" && test -x `which "chef-solo"`}).and_raise(Rye::Err.new("omg"))

      @node.has_executable?("chef-solo").should be_false
    end
  end

  describe "#platform" do
    describe "when Ubuntu 10.10" do
      before do
        node = node_factory
        node.connection.stub(:cat => <<-HERE)
          DISTRIB_ID=Ubuntu
          DISTRIB_RELEASE=10.10
          DISTRIB_CODENAME=maverick
          DISTRIB_DESCRIPTION="Ubuntu 10.10"
        HERE
        @platform = node.platform
      end

      it "should have a distributor" do
        @platform[:distributor].should == "Ubuntu"
      end

      it "should have a release" do
        @platform[:release].should == "10.10"
      end

      it "should have a codename" do
        @platform[:codename].should == "maverick"
      end

      it "should have a version as a floating point number" do
        @platform[:version].should == 10.1
      end
    end
  end

  describe "#install" do
    it "should do nothing if chef is installed" do
      node = node_factory
      node.should_receive(:has_executable?).with("chef-solo").and_return(true)
      node.pocketknife.should_not_receive(:can_install)

      node.install
    end

    it "should only install chef if ruby and rubygems are installed" do
      node = node_factory

      node.pocketknife.should_receive(:can_install).and_return(true)

      node.should_receive(:has_executable?).with("chef-solo").and_return(false)
      node.should_receive(:has_executable?).with("ruby").and_return(true)
      node.should_receive(:has_executable?).with("gem").and_return(true)

      node.should_not_receive(:install_ruby)
      node.should_not_receive(:install_rubygems)
      node.should_receive(:install_chef)

      node.install
    end

    it "should install chef and rubygems if only ruby is present" do
      node = node_factory

      node.pocketknife.should_receive(:can_install).and_return(true)

      node.should_receive(:has_executable?).with("chef-solo").and_return(false)
      node.should_receive(:has_executable?).with("ruby").and_return(true)
      node.should_receive(:has_executable?).with("gem").and_return(false)

      node.should_not_receive(:install_ruby)
      node.should_receive(:install_rubygems)
      node.should_receive(:install_chef)

      node.install
    end

    it "should install chef, rubygems and ruby if none are present" do
      node = node_factory

      node.pocketknife.should_receive(:can_install).and_return(true)

      node.should_receive(:has_executable?).with("chef-solo").and_return(false)
      node.should_receive(:has_executable?).with("ruby").and_return(false)
      node.should_receive(:has_executable?).with("gem").and_return(false)

      node.should_receive(:install_ruby)
      node.should_receive(:install_rubygems)
      node.should_receive(:install_chef)

      node.install
    end
  end

  describe "#install_chef" do
    it "should install chef" do
      node = node_factory
      node.should_receive(:execute).with("gem install --no-rdoc --no-ri chef", true)

      node.install_chef
    end
  end

  describe "#install_rubygems" do
    it "should install rubygems" do
      node = node_factory
      node.should_receive(:execute).with(<<-HERE, true)
cd /root &&
  rm -rf rubygems-1.3.7 rubygems-1.3.7.tgz &&
  wget http://production.cf.rubygems.org/rubygems/rubygems-1.3.7.tgz &&
  tar zxf rubygems-1.3.7.tgz &&
  cd rubygems-1.3.7 &&
  ruby setup.rb --no-format-executable &&
  rm -rf rubygems-1.3.7 rubygems-1.3.7.tgz
      HERE

      node.install_rubygems
    end
  end

  describe "#install_ruby" do
    it "should install ruby on Ubuntu" do
      node = node_factory
      node.stub(:platform => {:distributor => "Ubuntu"})
      node.should_receive(:execute).with("DEBIAN_FRONTEND=noninteractive apt-get --yes install ruby ruby-dev libopenssl-ruby irb build-essential wget ssl-cert", true)

      node.install_ruby
    end

    it "should install ruby on CentOS" do
      node = node_factory
      node.stub(:platform => {:distributor => "CentOS"})
      node.should_receive(:execute).with("yum -y install ruby ruby-shadow gcc gcc-c++ ruby-devel wget", true)

      node.install_ruby
    end
  end

  describe "::prepare_upload" do
    before(:all) do
      @previous = Dir.pwd
      @dir = mkproject
      @node = node_factory
    end

    after(:all) do
      FileUtils.rm_rf(@dir) if @dir
      Dir.chdir(@previous)
    end

    def prepare_upload_with_or_without_a_block
      Pocketknife::Node::TMP_SOLO_RB.should_receive(:open)
      Pocketknife::Node::TMP_CHEF_SOLO_APPLY.should_receive(:open)
      Pocketknife::Node::TMP_TARBALL.should_receive(:open)
    end

    describe "without a block" do
      it "should create a tarball and leave it alone" do
        prepare_upload_with_or_without_a_block
        Pocketknife::Node.should_not_receive(:cleanup_upload)
        Pocketknife::Node.prepare_upload
      end
    end

    describe "with a block" do
      it "should create a tarball and clean it up" do
        prepare_upload_with_or_without_a_block
        Pocketknife::Node.should_receive(:cleanup_upload)
        Pocketknife::Node.prepare_upload { }
      end
    end
  end

  describe "::cleanup_upload" do
    it "should cleanup files" do
      mkproject do
        [
          Pocketknife::Node::TMP_SOLO_RB,
          Pocketknife::Node::TMP_CHEF_SOLO_APPLY,
          Pocketknife::Node::TMP_TARBALL
        ].each do |item|
          item.should_receive(:exist?).and_return(true)
          item.should_receive(:unlink)
        end

        Pocketknife::Node.cleanup_upload
      end
    end
  end

  describe "#upload" do
    it "should upload configuration" do
      mkproject do
        node = node_factory

        local_node_json = node.local_node_json_pathname
        local_node_json.open("w") { |h| h.write("{}") }

        node.should_receive(:execute).with(<<-HERE)
umask 0377 &&
  rm -rf "/etc/chef" "/var/local/pocketknife" "/var/local/pocketknife/cache" "/usr/local/sbin/chef-solo-apply" "/usr/local/sbin/csa" &&
  mkdir -p "/etc/chef" "/var/local/pocketknife" "/var/local/pocketknife/cache" "/usr/local/sbin"
        HERE

        node.connection.should_receive(:file_upload).with(local_node_json.to_s, "/etc/chef/node.json")

        node.connection.should_receive(:file_upload).with(Pocketknife::Node::TMP_TARBALL.to_s, "/var/local/pocketknife/cache/pocketknife.tmp")

        node.should_receive(:execute).with(<<-HERE, true)
cd "/var/local/pocketknife/cache" &&
  tar xf "/var/local/pocketknife/cache/pocketknife.tmp" &&
  chmod -R u+rwX,go= . &&
  chown -R root:root . &&
  mv "solo.rb.tmp" "/etc/chef/solo.rb" &&
  mv "chef-solo-apply.tmp" "/usr/local/sbin/chef-solo-apply" &&
  chmod u+x "/usr/local/sbin/chef-solo-apply" &&
  ln -s "chef-solo-apply" "/usr/local/sbin/csa" &&
  rm "/var/local/pocketknife/cache/pocketknife.tmp" &&
  mv * "/var/local/pocketknife"
        HERE

        node.upload
      end
    end
  end

  describe "#apply" do
    it "should apply configuration" do
      node = node_factory
      node.pocketknife.should_receive(:verbosity).at_least(:once).and_return(false)
      node.should_receive(:install)
      node.should_receive(:execute).with("chef-solo -j /etc/chef/node.json", true)
      node.stub(:say)

      node.apply
    end
  end
end
