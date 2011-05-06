# Standard libraries
require "pathname"
require "fileutils"

# Gem libraries
require "archive/tar/minitar"
require "rye"
require "settingslogic"

# = Pocketknife
#
# For information on using +pocketknife+, please see the {file:README.md README.md} file.
class Pocketknife
  # == Auth
  #
  # A Settingslogic class that provides authentication credentials. It looks
  # for an <tt>auth.yml</tt> file, which can contain a list of nodes and their
  # credentials. If no credentials are defined, it's assumed that the
  #
  # Example of content in <tt>auth.yml</tt>:
  #
  #   # When deploying to node 'henrietta', SSH into host 'fnp90.swa.gov.it':
  #   henrietta:
  #     hostname: fnp90.swa.gov.it
  #
  #   # When deploying to node 'triela', SSH into host 'm1897.swa.gov.it' as user 'bayonet':
  #   triela:
  #     hostname: m1897.swa.gov.it
  #     user: bayonet
  class Auth < Settingslogic
    source "auth.yml"

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

    # Returns credentials for the node.
    #
    # Defaults to having the hostname be the same as the node name, and +root+
    # as the user.
    #
    # @param [String] node The node name.
    # @return [String, Hash] The hostname and a hash containing <tt>:user => USER</tt> where USER is the name of the user.
    def self.credentials_for(node)
      if _sane? && self[node]
        result = []
        result << self[node]["hostname"] || node
        result << {:user => self[node]["user"] || "root"}
      else
        return [node, {:user => "root"}]
      end
    end
  end

  # == NoSuchNode
  #
  # Exception raised when asked to perform an operation on an unknown node.
  class NoSuchNode < StandardError
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

      parser.on("-c", "--create [PROJECT]", "Create project") do |name|
        puts "* Creating project in directory: #{name}"
        pocketknife.create(name) do |created|
          puts "- #{created}"
        end
        return
      end

      parser.on("-v", "--verbose", "Run chef in verbose mode") do |name|
        pocketknife.verbose = true
      end

      parser.on("-u", "--upload", "Upload configuration, but don't apply it") do |v|
        options[:upload] = true
      end

      parser.on("-a", "--apply", "Runs cheef to apply already-uploaded configuration") do |v|
        options[:apply] = true
      end

      parser.on("-q", "--quiet", "Run quietly, only display important information") do |v|
        pocketknife.quiet = true
      end

      begin
        arguments = parser.parse!
      rescue OptionParser::MissingArgument => e
        puts parser
        puts
        puts "ERROR: #{e}"
        exit -1
      end

      begin
        display = lambda do |node, success, error|
          if success
            puts "* #{node}: #{success}"
          elsif error
            puts "! #{node}: #{error}"
          else
            # Ignore
          end
        end

        if options[:upload]
          pocketknife.upload(arguments, &display)
        end

        if options[:apply]
          pocketknife.apply(arguments, &display)
        end

        if not options[:upload] and not options[:apply]
          pocketknife.upload_and_apply(arguments, &display)
        end
      rescue NoSuchNode => e
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
  attr_accessor :quiet

  # Run verbosely? If true, run chef with the debugging level logger.
  attr_accessor :verbose

  # Instantiate a new Pocketknife.
  def initialize
  end

  # Creates a new project directory.
  #
  # @param [String] project The name of the project directory to create.
  # @yield [path] Yields status information to the optionally supplied block.
  # @yieldparam [String] path The path of the file or directory created.
  def create(project, &block)
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
        yield(target.to_s) if block
      end
    end

    settings_yml = (dir + "settings.yml")
    unless settings_yml.exist?
      settings_yml.open("w") {}
      yield(settings_yml.to_s) if block
    end

    return true
  end

  # Uploads and applies configuration to the nodes, calls #upload and #apply.
  def upload_and_apply(nodes, &block)
    upload(nodes, &block)
    apply(nodes, &block)
  end

  # Uploads configuration information to remote nodes.
  #
  # @param [Array<String>] nodes A list of node names.
  # @yield [node, success, error] Yields status information to the optionally supplied block.
  # @yieldparam [String] node The name of the node.
  # @yieldparam [String] success A message indicating success.
  # @yieldparam [String] error A message indicating error.
  # @raise [NoSuchNode] Raised if asked to operate on an unknown node.
  def upload(nodes, &block)
    assert_known_nodes(nodes)

    # TODO either do this in memory or scope this to the PID to allow concurrency
    tarball = Pathname.new("pocketknife.tmp")
    tarball.open("w") do |handle|
      Archive::Tar::Minitar.pack([
        VAR_POCKETKNIFE_COOKBOOKS.basename.to_s,
        VAR_POCKETKNIFE_SITE_COOKBOOKS.basename.to_s,
        VAR_POCKETKNIFE_ROLES.basename.to_s],
      handle)
    end

    for node in nodes
      rye = rye_for(node)

      item = ETC_CHEF.to_s
      begin
        rye.test(:d, item)
        rye.rm("-rf", item)
      rescue Rye::Err
        # Ignore, this means the directory doesn't exist
      end
      yield(node, "Creating directory: #{item}") if block && ! quiet
      rye.mkdir(:p, item)

      item = VAR_POCKETKNIFE.to_s
      begin
        rye.test(:d, item)
        rye.rm("-rf", item)
      rescue Rye::Err
        # Ignore, this means the directory doesn't exist
      end
      yield(node, "Creating directory: #{item}") if block && ! quiet
      rye.mkdir(:p, item)

      item = VAR_POCKETKNIFE_CACHE.to_s
      yield(node, "Creating directory: #{item}") if block && ! quiet
      rye.mkdir(:p, item)

      yield(node, "Uploading file: #{SOLO_RB}") if block && ! quiet
      rye.file_upload(StringIO.new(SOLO_RB_CONTENT), SOLO_RB.to_s)

      yield(node, "Uploading file: #{NODE_JSON}") if block && ! quiet
      rye.file_upload(node_json_path_for(node).to_s, NODE_JSON.to_s)

      yield(node, "Uploading file: #{CHEF_SOLO_APPLY}") if block && ! quiet
      rye.file_upload(StringIO.new(CHEF_SOLO_APPLY_CONTENT), CHEF_SOLO_APPLY.to_s)

      yield(node, "Setting permissions: #{CHEF_SOLO_APPLY}") if block && ! quiet
      rye.chmod("u=rwx,go=", CHEF_SOLO_APPLY.to_s)
      rye.chown("root:root", CHEF_SOLO_APPLY.to_s)

      begin
        rye.test(:e, CHEF_SOLO_APPLY_ALIAS.to_s)
        rye.rm(CHEF_SOLO_APPLY_ALIAS.to_s)
      rescue Rye::Err
        # Ignore, this means the file doesn't exist
      end
      yield(node, "Creating symlink: #{CHEF_SOLO_APPLY} -> #{CHEF_SOLO_APPLY_ALIAS}") if block && ! quiet
      rye.ln(:s, CHEF_SOLO_APPLY.to_s, CHEF_SOLO_APPLY_ALIAS.to_s)

      item = VAR_POCKETKNIFE_TARBALL
      yield(node, "Uploading cookbooks and roles") if block && ! quiet
      rye.file_upload(item.basename.to_s, item.to_s)
      rye[VAR_POCKETKNIFE.to_s].tar(:xf, item.to_s)
      tarball.unlink

      [
        VAR_POCKETKNIFE,
        ETC_CHEF
      ].each do |item|
        yield(node, "Setting permissions: #{item}") if block && ! quiet
        rye.chmod(:R, "u=rwX,go=", item.to_s)
        rye.chown(:R, "root:root", item.to_s)
      end

      yield(node, "Finished uploading!") if block && ! quiet

      rye.disconnect
    end
  end

  # Applies configurations to remote nodes.
  #
  # @param [Array<String>] nodes A list of node names.
  # @yield [node, success, error] Yields status information to the optionally supplied block.
  # @yieldparam [String] node The name of the node.
  # @yieldparam [String] success A message indicating success.
  # @yieldparam [String] error A message indicating error.
  # @raise [NoSuchNode] Raised if asked to operate on an unknown node.
  def apply(nodes, &block)
    assert_known_nodes(nodes)

    for node in nodes
      rye = rye_for(node)

      yield(node, "Applying configuration") if block && ! quiet
      command = "chef-solo -j #{NODE_JSON}"
      command << " -l debug" if verbose
      result = rye.execute(command)
      yield(node, "Applied: #{command}\n#{result.stdout}") if block

      yield(node, "Finished applying!") if block && ! quiet

      rye.disconnect
    end
  end

  # Returns the known node names for this project.
  #
  # @return [Array<String>] Node names.
  def known_nodes
    dir = Pathname.new("nodes")
    json_extension = /\.json$/
    if dir.directory?
      return dir.entries.select do |path|
        path.to_s =~ json_extension
      end.map do |path|
        path.to_s.sub(json_extension, "")
      end
    else
      raise Errno::ENOENT, "Can't find 'nodes' directory."
    end
  end

  # @private
  ETC_CHEF = Pathname.new("/etc/chef")
  # @private
  SOLO_RB = ETC_CHEF + "solo.rb"
  # @private
  NODE_JSON = ETC_CHEF + "node.json"
  # @private
  VAR_POCKETKNIFE = Pathname.new("/var/local/pocketknife")
  # @private
  VAR_POCKETKNIFE_CACHE = VAR_POCKETKNIFE + "cache"
  # @private
  VAR_POCKETKNIFE_TARBALL = VAR_POCKETKNIFE_CACHE + "/pocketknife.tmp"
  # @private
  VAR_POCKETKNIFE_COOKBOOKS = VAR_POCKETKNIFE + "cookbooks"
  # @private
  VAR_POCKETKNIFE_SITE_COOKBOOKS = VAR_POCKETKNIFE + "site-cookbooks"
  # @private
  VAR_POCKETKNIFE_ROLES = VAR_POCKETKNIFE + "roles"
  # @private
  SOLO_RB_CONTENT = <<-HERE
file_cache_path "#{VAR_POCKETKNIFE_CACHE}"
cookbook_path ["#{VAR_POCKETKNIFE_COOKBOOKS}", "#{VAR_POCKETKNIFE_SITE_COOKBOOKS}"]
role_path "#{VAR_POCKETKNIFE_ROLES}"
  HERE
  # @private
  CHEF_SOLO_APPLY = Pathname.new("/usr/local/sbin/chef-solo-apply")
  # @private
  CHEF_SOLO_APPLY_ALIAS = CHEF_SOLO_APPLY.dirname + "csa"
  # @private
  CHEF_SOLO_APPLY_CONTENT = <<-HERE
#!/bin/sh
chef-solo -j #{NODE_JSON} "$@"
  HERE

  # Asserts that the specified nodes are known to Pocketknife.
  #
  # @param [Array<String>] nodes A list of node names.
  # @raise [NoSuchNode] Raised if there's an unknown node.
  def assert_known_nodes(nodes)
    known = known_nodes
    unknown = nodes - known

    unless unknown.empty?
      raise NoSuchNode.new("No configuration found for node: #{unknown.first}" , unknown.first)
    end
  end

  # Returns a Rye::Box connection for the given node. The credentials are looked up through Auth.
  #
  # @param [String] node The node name.
  # @return [Rye::Box] A Rye::Box connection.
  def rye_for(node)
    credentials = Auth.credentials_for(node)
    rye = Rye::Box.new(*credentials)
    rye.disable_safe_mode
    return rye
  end

  # Returns a Pathname for the node's JSON file.
  #
  # @param [String] node A node name.
  # @return [Pathname] The JSON file.
  # @raise [NoSuchNode] Raised if asked to operate on an unknown node.
  def node_json_path_for(node)
    assert_known_nodes([node])
    return Pathname.new("nodes") + "#{node}.json"
  end
end
