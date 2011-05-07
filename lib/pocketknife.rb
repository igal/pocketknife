# Standard libraries
require "pathname"
require "fileutils"

# Gem libraries
require "archive/tar/minitar"
require "rye"
require "settingslogic"

# Related libraries
require "pocketknife/version"

# = Pocketknife
#
# For information on using +pocketknife+, please see the {file:README.md README.md} file.
class Pocketknife
  # == NodeError
  #
  # An error with a node. This is usually subclassed by a more specific error.
  class NodeError < StandardError
    # The name of the node.
    attr_accessor :node

    # Instantiate a new exception.
    #
    # @param [String] message The message to display.
    # @param [String] node The name of the unknown node.
    def initialize(message, node)
      self.node = node
      super(message)
    end
  end

  # == NoSuchNode
  #
  # Exception raised when asked to perform an operation on an unknown node.
  class NoSuchNode < NodeError
  end

  # == UnsupportedInstallationPlatform
  #
  # Exception raised when asked to install Chef on an unsupported platform.
  class UnsupportedInstallationPlatform < NodeError
  end

  # == NotInstalling
  #
  # Exception raised when Chef is not available, but user asked not to install it.
  class NotInstalling < NodeError
  end

  # == Credentials
  #
  # A Settingslogic class that provides authentication credentials. It looks
  # for an <tt>credentials.yml</tt> file, which can contain a list of nodes and their
  # credentials. If no credentials are defined, it's assumed that the
  #
  # Example of content in <tt>credentials.yml</tt>:
  #
  #   # When deploying to node 'henrietta', SSH into host 'fnp90.swa.gov.it':
  #   henrietta:
  #     hostname: fnp90.swa.gov.it
  #
  #   # When deploying to node 'triela', SSH into host 'm1897.swa.gov.it' as user 'bayonet':
  #   triela:
  #     hostname: m1897.swa.gov.it
  #     user: bayonet
  class Credentials < Settingslogic
    source "credentials.yml"

    # Is the Settingslogic data sane? This is used as part of a workaround for
    # a Settingslogic bug where an empty file causes it to fail with:
    #   NoMethodError Exception: undefined method `to_hash' for false:FalseClass
    #
    # @return [Boolean] Is sane?
    def self._sane?
      begin
        self.to_hash
        return true
      rescue NoMethodError
        return false
      end
    end

    # Returns credentials for a node.
    #
    # Defaults to hostname being the same as the node name, and user being +root+.
    #
    # @param [String] node The node name.
    # @return [String, Hash] The hostname and a hash containing <tt>:user => USER</tt> where USER is the name of the user.
    def self.find(node)
      if _sane? && self[node]
        return [
          self[node]["hostname"] || node,
          {:user => self[node]["user"] || "root"}
        ]
      else
        return [node, {:user => "root"}]
      end
    end
  end

  # == NodeManager
  #
  # The NodeManager manages Node instances for a Pocketknife.
  class NodeManager
    # Instance of a Pocketknife.
    attr_accessor :pocketknife

    # Hash of Node instances by their name.
    attr_accessor :nodes

    # Array of known nodes, used as cache by #known_nodes. Nil when empty.
    attr_accessor :known_nodes_cache

    # Instantiate a new NodeManager.
    #
    # @param [Pocketknife] pocketknife
    def initialize(pocketknife)
      self.pocketknife = pocketknife
      self.nodes = {}
      self.known_nodes_cache = nil
    end

    # Return a Node instance. Use cached value if available.
    #
    # @param [String] name A node name to find.
    # @return [Node]
    def find(name)
      self.assert_known([name])

      return self.nodes[name] ||= begin
          node = Node.new(name, self.pocketknife)
        end
    end

    # Asserts that the specified nodes are known to Pocketknife.
    #
    # @param [Array<String>] nodes A list of node names.
    # @raise [NoSuchNode] Raised if there's an unknown node.
    def assert_known(names)
      unknown = names - self.known_nodes

      unless unknown.empty?
        raise NoSuchNode.new("No configuration found for node: #{unknown.first}" , unknown.first)
      end
    end

    # Returns the known node names for this project.
    #
    # Caches results to #known_nodes_cache
    #
    # @return [Array<String>] The node names.
    # @raise [Errno::ENOENT] Raised if can't find the 'nodes' directory.
    def known_nodes
      return(self.known_nodes_cache ||= begin
          dir = Pathname.new("nodes")
          json_extension = /\.json$/
          if dir.directory?
            dir.entries.select do |path|
              path.to_s =~ json_extension
            end.map do |path|
              path.to_s.sub(json_extension, "")
            end
          else
            raise Errno::ENOENT, "Can't find 'nodes' directory."
          end
        end)
    end
  end

  # == Node
  #
  # A node represents a remote computer. You can connect to a node, execute commands on it, install the stack, and upload and apply configurations to it.
  class Node
    # String name of the node.
    attr_accessor :name

    # Instance of a Pocketknife.
    attr_accessor :pocketknife

    # Instance of Rye::Box connection, cached by #connection.
    attr_accessor :connection_cache

    # Hash with information about platform, cached by #platform.
    attr_accessor :platform_cache

    # Initialize a new Node.
    #
    # @param [String] name A node name.
    # @param [Pocketknife] pocketknife
    def initialize(name, pocketknife)
      self.name = name
      self.pocketknife = pocketknife
      self.connection_cache = nil
    end

    # Returns a Rye::Box connection.
    #
    # Caches result to #connection_cache
    def connection
      return self.connection_cache ||= begin
          credentials = Credentials.find(self.name)
          rye = Rye::Box.new(*credentials)
          rye.disable_safe_mode
          rye
        end
    end

    # Displays status message.
    #
    # @param [String] message The message to display.
    # @param [Boolean] important Is the message important? If so, displays it even in quiet mode.
    def display_status(message, important=false)
      if important or not self.pocketknife.is_quiet
        puts "* #{self.name}: #{message}"
      end
    end

    # Returns path to this node's <tt>nodes/NAME.json</tt> file, used as <tt>node.json</tt> by <tt>chef-solo</tt>.
    #
    # @return [Pathname]
    def local_node_json_pathname
      return Pathname.new("nodes") + "#{self.name}.json"
    end

    # Does this node have the given executable?
    #
    # @param [String] executable A name of an executable, e.g. <tt>chef-solo</tt>.
    # @return [Boolean] Has executable?
    def has_executable?(executable)
      begin
        self.connection.execute(%{which "#{executable}" && test -x `which "#{executable}"`})
        return true
      rescue Rye::Err
        return false
      end
    end

    # Returns information describing the node.
    #
    # The information is formatted similar to this:
    #   {
    #     :distributor=>"Ubuntu", # String with distributor name
    #     :codename=>"maverick", # String with release codename
    #     :release=>"10.10", # String with release number
    #     :version=>10.1 # Float with release number
    #   }
    #
    # @return [Hash<String, Object] Return a hash describing the node, see above.
    # @raise [UnsupportedInstallationPlatform] Raised if there's no installation information for this platform.
    def platform
      return self.platform_cache ||= begin
        lsb_release = "/etc/lsb-release"
        begin
          output = self.connection.cat(lsb_release).to_s
          result = {}
          result[:distributor] = output[/DISTRIB_ID\s*=\s*(.+?)$/, 1]
          result[:release] = output[/DISTRIB_RELEASE\s*=\s*(.+?)$/, 1]
          result[:codename] = output[/DISTRIB_CODENAME\s*=\s*(.+?)$/, 1]
          result[:version] = result[:release].to_f

          if result[:distributor] && result[:release] && result[:codename] && result[:version]
            return result
          else
            raise UnsupportedInstallationPlatform.new("Can't install on node '#{self.name}' with invalid '#{lsb_release}' file", self.name)
          end
        rescue Rye::Err
          raise UnsupportedInstallationPlatform.new("Can't install on node '#{self.name}' without '#{lsb_release}'", self.name)
        end
      end
    end

    # Installs Chef and its dependencies on a node if needed.
    #
    # @raise [NotInstalling] Raised if Chef isn't installed, but user didn't allow installation.
    # @raise [UnsupportedInstallationPlatform] Raised if there's no installation information for this platform.
    def install
      unless self.has_executable?("chef-solo")
        case self.pocketknife.can_install
        when nil
          # Prompt for installation
          print "? #{node}: Chef not found. Install it and its dependencies? (Y/n) "
          STDOUT.flush
          answer = STDIN.gets.chomp
          case answer
          when /^y/i, ''
            # Continue with install
          else
            raise NotInstalling.new("Chef isn't installed on node '#{self.name}', but user doesn't want to install it.", self.name)
          end
        when true
          # User wanted us to install
        else
          # Don't install
          raise NotInstalling.new("Chef isn't installed on node '#{self.name}', but user doesn't want to install it.", self.name)
        end

        unless self.has_executable?("ruby")
          self.install_ruby
        end

        unless self.has_executable?("gem")
          self.install_rubygems
        end

        self.install_chef
      end
    end

    # Installs chef on the remote node.
    def install_chef
      self.display_status("Installing chef...")
      self.execute("gem install --no-rdoc --no-ri chef", true)
      self.display_status("Installed chef")
    end

    # Installs Rubygems on the remote node.
    def install_rubygems
      self.display_status("Installing rubygems...")
      self.execute(<<-HERE, true)
        cd /root &&
          rm -rf rubygems-1.3.7 rubygems-1.3.7.tgz &&
          wget http://production.cf.rubygems.org/rubygems/rubygems-1.3.7.tgz &&
          tar zxf rubygems-1.3.7.tgz &&
          cd rubygems-1.3.7 &&
          ruby setup.rb --no-format-executable &&
          rm -rf rubygems-1.3.7 rubygems-1.3.7.tgz
      HERE
      self.display_status("Installed rubygems")
    end

    # Installs Ruby on the remote node.
    def install_ruby
      command = \
        case self.platform[:distributor].downcase
        when /ubuntu/, /debian/, /gnu\/linux/
          "DEBIAN_FRONTEND=noninteractive apt-get --yes install ruby ruby-dev libopenssl-ruby irb build-essential wget ssl-cert"
        when /centos/, /red hat/, /scientific linux/
          "yum -y install ruby ruby-shadow gcc gcc-c++ ruby-devel wget"
        else
          raise UnsupportedInstallationPlatform.new("Can't install on node '#{self.name}' with unknown distrubtor: `#{self.platform[:distrubtor]}`", self.name)
        end

      self.display_status("Installing ruby...")
      self.execute(command, true)
      self.display_status("Installed ruby")
    end

    # Prepares an upload, by creating a cache of shared files used by all nodes.
    #
    # If an optional block is supplied, calls ::cleanup_upload after it ends.
    # This is typically used like:
    #   Node.prepare_upload do
    #     mynode.upload
    #   end
    #
    # @yield [] Prepares the upload, executes the block, and cleans up the upload when done.
    def self.prepare_upload(&block)
      begin
        # TODO either do this in memory or scope this to the PID to allow concurrency
        TMP_SOLO_RB.open("w") {|h| h.write(SOLO_RB_CONTENT)}
        TMP_CHEF_SOLO_APPLY.open("w") {|h| h.write(CHEF_SOLO_APPLY_CONTENT)}
        TMP_TARBALL.open("w") do |handle|
          Archive::Tar::Minitar.pack(
            [
              VAR_POCKETKNIFE_COOKBOOKS.basename.to_s,
              VAR_POCKETKNIFE_SITE_COOKBOOKS.basename.to_s,
              VAR_POCKETKNIFE_ROLES.basename.to_s,
              TMP_SOLO_RB.to_s,
              TMP_CHEF_SOLO_APPLY.to_s
            ],
            handle
          )
        end
      rescue Exception => e
        cleanup_upload
        raise e
      end

      if block
        begin
          yield(self)
        ensure
          cleanup_upload
        end
      end
    end

    # Cleans up cache of shared files uploaded to all nodes. This cache is created by the ::prepare_upload method.
    def self.cleanup_upload
      [
        TMP_TARBALL,
        TMP_SOLO_RB,
        TMP_CHEF_SOLO_APPLY
      ].each do |path|
        path.unlink if path.exist?
      end
    end

    # Uploads configuration information to node.
    #
    # IMPORTANT: You must first call ::prepare_upload to create the shared files that will be uploaded.
    def upload
      self.display_status("Uploading configuration...")

      self.display_status("Removing old files...")
      self.execute <<-HERE
        umask 0377 &&
          rm -rf "#{ETC_CHEF}" "#{VAR_POCKETKNIFE}" "#{VAR_POCKETKNIFE_CACHE}" "#{CHEF_SOLO_APPLY}" "#{CHEF_SOLO_APPLY_ALIAS}" &&
          mkdir -p "#{ETC_CHEF}" "#{VAR_POCKETKNIFE}" "#{VAR_POCKETKNIFE_CACHE}" "#{CHEF_SOLO_APPLY.dirname}"
      HERE

      self.display_status("Uploading new files...")
      self.connection.file_upload(self.local_node_json_pathname.to_s, NODE_JSON.to_s)
      self.connection.file_upload(TMP_TARBALL.to_s, VAR_POCKETKNIFE_TARBALL.to_s)

      self.display_status("Installing new files...")
      self.execute <<-HERE, true
        cd "#{VAR_POCKETKNIFE_CACHE}" &&
          tar xf "#{VAR_POCKETKNIFE_TARBALL}" &&
          chmod -R u+rwX,go= . &&
          chown -R root:root . &&
          mv "#{TMP_SOLO_RB}" "#{SOLO_RB}" &&
          mv "#{TMP_CHEF_SOLO_APPLY}" "#{CHEF_SOLO_APPLY}" &&
          chmod u+x "#{CHEF_SOLO_APPLY}" &&
          ln -s "#{CHEF_SOLO_APPLY.basename}" "#{CHEF_SOLO_APPLY_ALIAS}" &&
          rm "#{VAR_POCKETKNIFE_TARBALL}" &&
          mv * "#{VAR_POCKETKNIFE}"
      HERE

      self.display_status("Finished uploading!")
    end

    # Applies the configuration to the node. Installs Chef, Ruby and Rubygems if needed.
    def apply
      self.install

      self.display_status("Applying configuration...")
      command = "chef-solo -j #{NODE_JSON}"
      command << " -l debug" if self.pocketknife.is_verbose
      self.execute(command, true)
      self.display_status("Finished applying!")
    end

    # Uploads and applies the configuration to the node. See #upload and #apply.
    def upload_and_apply
      self.upload
      self.apply
    end

    # Executes commands on the external node.
    #
    # @param [String] commands Shell commands to execute.
    # @param [Boolean] verbose Display execution information immediately to STDOUT, rather than returning it as an object when done.
    # @return [Rye::Rap] A result object describing the completed execution.
    def execute(commands, immediate=false)
      if immediate
        self.connection.stdout_hook {|line| puts line}
      end
      return self.connection.execute("(#{commands}) 2>&1")
    ensure
      self.connection.stdout_hook = nil
    end

    # Remote path to chef's settings
    # @private
    ETC_CHEF = Pathname.new("/etc/chef")
    # Remote path to solo.rb
    # @private
    SOLO_RB = ETC_CHEF + "solo.rb"
    # Remote path to node.json
    # @private
    NODE_JSON = ETC_CHEF + "node.json"
    # Remote path to pocketknife's deployed configuration
    # @private
    VAR_POCKETKNIFE = Pathname.new("/var/local/pocketknife")
    # Remote path to pocketknife's cache
    # @private
    VAR_POCKETKNIFE_CACHE = VAR_POCKETKNIFE + "cache"
    # Remote path to temporary tarball containing uploaded files.
    # @private
    VAR_POCKETKNIFE_TARBALL = VAR_POCKETKNIFE_CACHE + "pocketknife.tmp"
    # Remote path to pocketknife's cookbooks
    # @private
    VAR_POCKETKNIFE_COOKBOOKS = VAR_POCKETKNIFE + "cookbooks"
    # Remote path to pocketknife's site-cookbooks
    # @private
    VAR_POCKETKNIFE_SITE_COOKBOOKS = VAR_POCKETKNIFE + "site-cookbooks"
    # Remote path to pocketknife's roles
    # @private
    VAR_POCKETKNIFE_ROLES = VAR_POCKETKNIFE + "roles"
    # Content of the solo.rb file
    # @private
    SOLO_RB_CONTENT = <<-HERE
file_cache_path "#{VAR_POCKETKNIFE_CACHE}"
cookbook_path ["#{VAR_POCKETKNIFE_COOKBOOKS}", "#{VAR_POCKETKNIFE_SITE_COOKBOOKS}"]
role_path "#{VAR_POCKETKNIFE_ROLES}"
    HERE
    # Remote path to chef-solo-apply
    # @private
    CHEF_SOLO_APPLY = Pathname.new("/usr/local/sbin/chef-solo-apply")
    # Remote path to csa
    # @private
    CHEF_SOLO_APPLY_ALIAS = CHEF_SOLO_APPLY.dirname + "csa"
    # Content of the chef-solo-apply file
    # @private
    CHEF_SOLO_APPLY_CONTENT = <<-HERE
#!/bin/sh
chef-solo -j #{NODE_JSON} "$@"
    HERE
    # Local path to solo.rb that will be included in the tarball
    # @private
    TMP_SOLO_RB = Pathname.new("solo.rb.tmp")
    # Local path to chef-solo-apply.rb that will be included in the tarball
    # @private
    TMP_CHEF_SOLO_APPLY = Pathname.new("chef-solo-apply.tmp")
    # Local path to the tarball to upload to the remote node containing shared files
    # @private
    TMP_TARBALL = Pathname.new("pocketknife.tmp")
  end

  # Runs the interpreter using arguments provided by the command-line.
  #
  # Example:
  #   # Display command-line help:
  #   Pocketknife.cli('-h')
  #
  # @param [Array<String>] args A list of arguments from the command-line, which may include options (e.g. <tt>-h</tt>).
  def self.cli(args)
    pocketknife = Pocketknife.new

    OptionParser.new do |parser|
      parser.banner = <<-HERE
USAGE: pocketknife [options] [nodes]

EXAMPLES:
  # Create a new project called PROJECT
  pocketknife -c PROJECT

  # Apply configuration to a node called NODE
  pocketknife NODE

OPTIONS:
      HERE

      options = {}

      parser.on("-c", "--create PROJECT", "Create project") do |name|
        pocketknife.create(name)
        return
      end

      parser.on("-V", "--version", "Display version number") do |name|
        puts "Pocketknife #{Pocketknife::Version::STRING}"
        return
      end

      parser.on("-v", "--verbose", "Run chef in verbose mode") do |name|
        pocketknife.is_verbose = true
      end

      parser.on("-u", "--upload", "Upload configuration, but don't apply it") do |v|
        options[:upload] = true
      end

      parser.on("-a", "--apply", "Runs cheef to apply already-uploaded configuration") do |v|
        options[:apply] = true
      end

      parser.on("-q", "--quiet", "Run quietly, only display important information") do |v|
        pocketknife.is_quiet = true
      end

      parser.on("-i", "--install", "Install Chef automatically") do |v|
        pocketknife.can_install = true
      end

      parser.on("-I", "--noinstall", "Don't install Chef automatically") do |v|
        pocketknife.can_install = false
      end

      begin
        arguments = parser.parse!
      rescue OptionParser::MissingArgument => e
        puts parser
        puts
        puts "ERROR: #{e}"
        exit -1
      end

      nodes = arguments

      begin
        if options[:upload]
          pocketknife.upload(nodes)
        end

        if options[:apply]
          pocketknife.apply(nodes)
        end

        if not options[:upload] and not options[:apply]
          pocketknife.upload_and_apply(nodes)
        end
      rescue NoSuchNode, NotInstalling, UnsupportedInstallationPlatform => e
        puts "! #{e}"
        exit -1
      end
    end
  end

  # Returns the software's version.
  #
  # @return [String] A version string.
  def self.version
    return "0.0.1"
  end

  # Run quietly? If true, only show important output.
  attr_accessor :is_quiet

  # Run verbosely? If true, run chef with the debugging level logger.
  attr_accessor :is_verbose

  # Can chef and its dependencies be installed automatically if not found? true means perform installation without prompting, false means quit if chef isn't available, and nil means prompt the user for input.
  attr_accessor :can_install

  # NodeManager instance.
  attr_accessor :node_manager

  # Instantiate a new Pocketknife.
  #
  # @option [Boolean] is_quiet Hide status information and only show important stuff?
  # @option [Boolean] is_verbose Show debug level Chef execution output?
  # @option [Boolean] can_install Install Chef and its dependencies if needed? true means do so automatically, false means don't, and nil means display a prompt to ask the user what to do.
  def initialize(opts={})
    self.is_quiet     = opts[:quiet].nil?   ? false : opts[:quiet]
    self.is_verbose   = opts[:verbose].nil? ? false : opts[:verbose]
    self.can_install  = opts[:install].nil? ? nil   : opts[:install]

    self.node_manager = NodeManager.new(self)
  end

  # Creates a new project directory.
  #
  # @param [String] project The name of the project directory to create.
  # @yield [path] Yields status information to the optionally supplied block.
  # @yieldparam [String] path The path of the file or directory created.
  def create(project)
    puts "* Creating project in directory: #{project}" unless self.is_quiet

    dir = Pathname.new(project)

    %w[
      nodes
      roles
      cookbooks
      site-cookbooks
    ].each do |subdir|
      target = (dir + subdir)
      unless target.exist?
        FileUtils.mkdir_p(target)
        puts "- #{target}/" unless self.is_quiet
      end
    end

    credentials_yml = (dir + "credentials.yml")
    unless credentials_yml.exist?
      credentials_yml.open("w") {}
        puts "- #{credentials_yml}" unless self.is_quiet
    end

    return true
  end

  # Returns a Node instance.
  #
  # @param[String] name The name of the node.
  def node(name)
    return node_manager.find(name)
  end

  # Uploads and applies configuration to the nodes, calls #upload and #apply.
  #
  # @params[Array<String>] nodes A list of node names.
  def upload_and_apply(nodes)
    node_manager.assert_known(nodes)

    Node.prepare_upload do
      for node in nodes
        node_manager.find(node).upload_and_apply
      end
    end
  end

  # Uploads configuration information to remote nodes.
  #
  # @param [Array<String>] nodes A list of node names.
  def upload(nodes)
    node_manager.assert_known(nodes)

    Node.prepare_upload do
      for node in nodes
        node_manager.find(node).upload
      end
    end
  end

  # Applies configurations to remote nodes.
  #
  # @param [Array<String>] nodes A list of node names.
  def apply(nodes)
    node_manager.assert_known(nodes)

    for node in nodes
      node_manager.find(node).apply
    end
  end
end
