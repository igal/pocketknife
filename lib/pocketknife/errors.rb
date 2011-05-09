class Pocketknife
  # == NodeError
  #
  # An error with a {Pocketknife::Node}. This is meant to be subclassed by a more specific error.
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
  # Exception raised when asked to install Chef on a node with an unsupported platform.
  class UnsupportedInstallationPlatform < NodeError
  end

  # == NotInstalling
  #
  # Exception raised when Chef is not available ohn a node, but user asked not to install it.
  class NotInstalling < NodeError
  end
end
