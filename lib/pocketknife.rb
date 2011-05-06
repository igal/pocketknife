# Standard libraries
require "pathname"
require "fileutils"

# Gem libraries
require "archive/tar/minitar"
require "rye"
require "settingslogic"

# Converts the object into textual markup given a specific `format`
# (defaults to `:html`)
#
# == Parameters:
#
#        asdfasdfadsf
#
# format::
#   A Symbol declaring the format to convert the object to. This
#   can be `:text` or `:html`.
#
# == Returns:
#
# A string representing the object in a specified
# format.
#
# @param [String, #read] format the contents to reverse
# @return [String] the contents reversed lexically
def to_format(format = :html)
  # format the object
end

# == asdf
#
# asdf
#
class Pocketknife
  # == Auth
  #
  # A Settingslogic class that provides authentication credentials. It looks
  # for an `auth.yml` file, which can contain a list of nodes and their
  # credentials. If no credentials are defined, it's assumed that the
  #
  # Example of content in `auth.yml`:
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

    # Workaround for Settingslogic bug where an empty file causes it to fail with:
    #   NoMethodError Exception: undefined method `to_hash' for false:FalseClass
    # TODO File bug and patch for Settingslogic.
    def self.sane?
      begin
        self.to_hash
        return true
      rescue NoMethodError
        return false
      end
    end

    def self.credentials_for(node)
      if sane? && self[node]
        result = []
        result << self[node]["hostname"] || node
        result << {:user => self[node]["user"] || "root"}
      else
        return [node, {:user => "root"}]
      end
    end
  end

  class NoSuchNode < StandardError
    attr_accessor :node

    def initialize(message, node)
      self.node = node
      super(message)
    end
  end

  # Execute command-line interpreter.
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

      parser.on("-v", "--verbose", "Execute chef in verbose mode") do |name|
        pocketknife.verbose = true
      end

      parser.on("-u", "--upload", "Upload configuration, but don't execute it") do |v|
        options[:upload] = true
      end

      parser.on("-e", "--execute", "Execute existing configuration") do |v|
        options[:execute] = true
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

        if options[:execute]
          pocketknife.execute(arguments, &display)
        end

        if not options[:upload] and not options[:execute]
          pocketknife.apply(arguments, &display)
        end
      rescue NoSuchNode => e
        puts "! #{e}"
        exit -1
      end
    end
  end

  # Return version string.
  def self.version
    return "0.0.1"
  end

  attr_accessor :quiet
  attr_accessor :verbose

  def initialize
  end

  # Return array of node names in this project.
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

  ETC_CHEF = Pathname.new("/etc/chef")
  SOLO_RB = ETC_CHEF + "solo.rb"
  NODE_JSON = ETC_CHEF + "node.json"
  VAR_POCKETKNIFE = Pathname.new("/var/local/pocketknife")
  VAR_POCKETKNIFE_CACHE = VAR_POCKETKNIFE + "cache"
  VAR_POCKETKNIFE_TARBALL = VAR_POCKETKNIFE_CACHE + "/pocketknife.tmp"
  VAR_POCKETKNIFE_COOKBOOKS = VAR_POCKETKNIFE + "cookbooks"
  VAR_POCKETKNIFE_SITE_COOKBOOKS = VAR_POCKETKNIFE + "site-cookbooks"
  VAR_POCKETKNIFE_ROLES = VAR_POCKETKNIFE + "roles"
  SOLO_RB_CONTENT = <<-HERE
file_cache_path "#{VAR_POCKETKNIFE_CACHE}"
cookbook_path ["#{VAR_POCKETKNIFE_COOKBOOKS}", "#{VAR_POCKETKNIFE_SITE_COOKBOOKS}"]
role_path "#{VAR_POCKETKNIFE_ROLES}"
  HERE
  CHEF_SOLO_APPLY = Pathname.new("/usr/local/sbin/chef-solo-apply")
  CHEF_SOLO_APPLY_ALIAS = CHEF_SOLO_APPLY.dirname + "csa"
  CHEF_SOLO_APPLY_CONTENT = <<-HERE
#!/bin/sh
chef-solo -j #{NODE_JSON} "$@"
  HERE

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

  def execute(nodes, &block)
    assert_known_nodes(nodes)

    for node in nodes
      rye = rye_for(node)

      yield(node, "Executing configuration") if block && ! quiet
      command = "chef-solo -j #{NODE_JSON}"
      command << " -l debug" if verbose
      result = rye.execute(command)
      yield(node, "Executed: #{command}\n#{result.stdout}") if block

      yield(node, "Finished executing!") if block && ! quiet

      rye.disconnect
    end
  end

  def assert_known_nodes(nodes)
    known = known_nodes
    unknown = nodes - known

    unless unknown.empty?
      raise NoSuchNode.new("No configuration found for node: #{unknown.first}" , unknown.first)
    end
  end

  def rye_for(node)
    credentials = Auth.credentials_for(node)
    rye = Rye::Box.new(*credentials)
    rye.disable_safe_mode
    return rye
  end

  def apply(nodes, &block)
    upload(nodes, &block)
    execute(nodes, &block)
  end

  # Create a new project directory. If block is provided, yield the name of the
  # newly created file or directory to it.
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

  def node_json_path_for(node)
    return Pathname.new("nodes") + "#{node}.json"
  end
end
