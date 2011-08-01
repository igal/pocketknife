# Standard libraries
require "pathname"
require "fileutils"

# Gem libraries
require "archive/tar/minitar"
require "rye"

# Related libraries
require "pocketknife/errors"
require "pocketknife/node"
require "pocketknife/node_manager"
require "pocketknife/version"

# = Pocketknife
#
# == About
#
# Pocketknife is a devops tool for managing computers running <tt>chef-solo</tt>. Using Pocketknife, you create a project that describes the configuration of your computers and then apply it to bring them to the intended state.
#
# For information on using the +pocketknife+ tool, please see the {file:README.md README.md} file. The rest of this documentation is intended for those writing code using the Pocketknife API.
#
# == Important methods
#
# * {cli} runs the command-line interpreter, whichi in turn executes the methods below.
# * {#initialize} creates a new Pocketknife instance.
# * {#create} creates a new project.
# * {#deploy} deploys configurations to nodes, which uploads and applies.
# * {#upload} uploads configurations to nodes.
# * {#apply} applies existing configurations to nodes.
# * {#node} finds a node to upload or apply configurations.
#
# == Important classes
#
# * {Pocketknife::Node} describes how to upload and apply configurations to nodes, which are remote computers.
# * {Pocketknife::NodeManager} finds, checks and manages nodes.
# * {Pocketknife::NodeError} describes errors encountered when using nodes.
class Pocketknife
  # Runs the interpreter using arguments provided by the command-line. Run <tt>pocketknife -h</tt> or review the code below to see what command-line arguments are accepted.
  #
  # Example:
  #   # Display command-line help:
  #   Pocketknife.cli('-h')
  #
  # @param [Array<String>] args A list of arguments from the command-line, which may include options (e.g. <tt>-h</tt>).
  # @return [void]
  # @raise [SystemExit] Something catastrophic happened, e.g. user passed invalid options to interpreter.
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

      parser.on("-v", "--verbose", "Display detailed status information") do |name|
        pocketknife.verbosity = true
      end

      parser.on("-q", "--quiet", "Display minimal status information") do |v|
        pocketknife.verbosity = false
      end

      parser.on("-u", "--upload", "Upload configuration, but don't apply it") do |v|
        options[:upload] = true
      end

      parser.on("-a", "--apply", "Runs cheef to apply already-uploaded configuration") do |v|
        options[:apply] = true
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

      if nodes.empty?
        puts parser
        puts
        puts "ERROR: No nodes specified."
        exit -1
      end

      begin
        if options[:upload]
          pocketknife.upload(nodes)
        end

        if options[:apply]
          pocketknife.apply(nodes)
        end

        if not options[:upload] and not options[:apply]
          pocketknife.deploy(nodes)
        end
      rescue NodeError => e
        puts "! #{e.node}: #{e}"
        exit -1
      end
    end
  end

  # Returns the software's version.
  #
  # @return [String] A version string, e.g. <tt>0.0.1</tt>.
  def self.version
    return Pocketknife::Version::STRING
  end

  # Amount of detail to display.
  #
  # @return [Nil, Boolean] +true+ means verbose, +nil+ means normal, +false+ means quiet.
  attr_accessor :verbosity

  # Should Chef and its dependencies be installed automatically if not found on a node?
  #
  # @return [Nil, Boolean] +true+ means perform the installation without prompting, +false+ means quit if Chef isn't found, and +nil+ means prompt the user to decide this interactively.
  attr_accessor :can_install

  # @return [Pocketknife::NodeManager] This instance's node manager.
  attr_accessor :node_manager

  # Instantiates a new Pocketknife.
  #
  # @option [Nil, Boolean] verbosity Amount of detail to display. +true+ means verbose, +nil+ means normal, +false+ means quiet.
  # @option [Nil, Boolean] install Install Chef and its dependencies if needed? +true+ means do so automatically, +false+ means don't, and +nil+ means display a prompt to ask the user what to do.
  def initialize(opts={})
    self.verbosity   = opts[:verbosity]
    self.can_install = opts[:install]

    self.node_manager = NodeManager.new(self)
  end

  # Displays a message, but only if it's important enough.
  #
  # @param [String] message The message to display.
  # @param [Nil, Boolean] importance How important is this? +true+ means important, +nil+ means normal, +false+ means unimportant.
  # @return [void]
  def say(message, importance=nil)
    display = \
      case self.verbosity
      when true
        true
      when nil
        importance != false
      else
        importance == true
      end

    if display
      puts message
    end
  end

  # Creates a new project directory.
  #
  # @param [String] project The name of the project directory to create.
  # @yield status information to the optionally supplied block.
  # @yieldparam [String] path The path of the file or directory created.
  # @return [void]
  def create(project)
    self.say("* Creating project in directory: #{project}")

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
        self.say("- #{target}/")
      end
    end

    return true
  end

  # Returns a node.
  #
  # @param [String] name The name of the node.
  # @return [Pocketknife::Node]
  def node(name)
    return node_manager.find(name)
  end

  # Deploys configuration to the nodes, calls {#upload} and {#apply}.
  #
  # @param [Array<String>] nodes A list of node names.
  # @return [void]
  def deploy(nodes)
    node_manager.assert_known(nodes)

    Node.prepare_upload do
      for node in nodes
        node_manager.find(node).deploy
      end
    end
  end

  # Uploads configuration information to remote nodes.
  #
  # @param [Array<String>] nodes A list of node names.
  # @return [void]
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
  # @return [void]
  def apply(nodes)
    node_manager.assert_known(nodes)

    for node in nodes
      node_manager.find(node).apply
    end
  end
end
