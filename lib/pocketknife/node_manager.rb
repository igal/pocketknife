class Pocketknife
  # == NodeManager
  #
  # This class finds, validates and manages {Pocketknife::Node} instances for a {Pocketknife}.
  class NodeManager
    # Instance of a Pocketknife.
    attr_accessor :pocketknife

    # Hash of Node instances by their name.
    attr_accessor :nodes

    # Array of known nodes, used as cache by {#known_nodes}.
    attr_accessor :known_nodes_cache

    # Instantiate a new manager.
    #
    # @param [Pocketknife] pocketknife
    def initialize(pocketknife)
      self.pocketknife = pocketknife
      self.nodes = {}
      self.known_nodes_cache = nil
    end

    # Return a node. Uses cached value in {#known_nodes_cache} if available.
    #
    # @param [String] name A node name to find.
    # @return [Pocketknife::Node]
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
    # Caches results to {#known_nodes_cache}.
    #
    # @return [Array<String>] The node names.
    # @raise [Errno::ENOENT] Raised if can't find the +nodes+ directory.
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
