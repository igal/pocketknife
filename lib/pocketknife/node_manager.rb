class Pocketknife
  # == NodeManager
  #
  # This class finds, validates and manages {Pocketknife::Node} instances for a {Pocketknife}.
  class NodeManager
    # @return [Pocketknife] The Pocketknife instance to manage.
    attr_accessor :pocketknife

    # @return [Hash{String => Pocketknife::Node}] Node instances by their name.
    attr_accessor :nodes

    # @return [Array<Pocketknife::Node>] Known nodes, cached by {#known_nodes}.
    attr_accessor :known_nodes_cache

    # Instantiates a new manager.
    #
    # @param [Pocketknife] pocketknife
    def initialize(pocketknife)
      self.pocketknife = pocketknife
      self.nodes = {}
      self.known_nodes_cache = nil
    end

    # Returns a node. Uses cached value in {#known_nodes_cache} if available.
    #
    # @param [String] name A node name to find, can be an abbrevation.
    # @return [Pocketknife::Node]
    def find(name)
      hostname = self.hostname_for(name)
      return self.nodes[hostname] ||= begin
          node = Node.new(hostname, self.pocketknife)
        end
    end

    # Returns a node's hostname based on its abbreviated node name.
    #
    # The hostname is derived from the filename that defines it. For example, the <tt>nodes/henrietta.swa.gov.it.json</tt> file defines a node with the hostname <tt>henrietta.swa.gov.it</tt>. This node can can be also be referred to as <tt>henrietta.swa.gov</tt>, <tt>henrietta.swa</tt>, or <tt>henrietta</tt>.
    #
    # The abbreviated node name given must match only one node exactly. For example, you'll get a {Pocketknife::NoSuchNode} if you ask for an abbreviated node by the name of <tt>giovanni</tt> when there are nodes called <tt>giovanni.boldini.it</tt> and <tt>giovanni.bellini.it</tt> -- you'd need to ask using a more specific name, such as <tt>giovanni.boldini</tt>.
    #
    # @param [String] abbreviated_name A node name, which may be abbreviated, e.g. <tt>henrietta</tt>.
    # @return [String] The complete node name, e.g. <tt>henrietta.swa.gov.it</tt>.
    # @raise [NoSuchNode] Couldn't find this node, either because it doesn't exist or the abbreviation isn't unique.
    def hostname_for(abbreviated_name)
      if self.known_nodes.include?(abbreviated_name)
        return abbreviated_name
      else
        matches = self.known_nodes.grep(/^#{abbreviated_name}\./)
        case matches.length
        when 1
          return matches.first
        when 0
          raise NoSuchNode.new("Can't find node named '#{abbreviated_name}'", abbreviated_name)
        else
          raise NoSuchNode.new("Can't find unique node named '#{abbreviated_name}', this matches nodes: #{matches.join(', ')}", abbreviated_name)
        end
      end
    end

    # Asserts that the specified nodes are known to Pocketknife.
    #
    # @param [Array<String>] names A list of node names.
    # @return [void]
    # @raise [Pocketknife::NoSuchNode] Couldn't find a node.
    def assert_known(names)
      for name in names
        # This will raise a NoSuchNode exception if there's a problem.
        self.hostname_for(name)
      end
    end

    # Returns the known node names for this project.
    #
    # Caches results to {#known_nodes_cache}.
    #
    # @return [Array<String>] The node names.
    # @raise [Errno::ENOENT] Can't find the +nodes+ directory.
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
end
