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

  # == ExecutionError
  #
  # Exception raised when something goes wrong executing commands against remote host.
  class ExecutionError < NodeError
    # Command that failed.
    attr_accessor :command

    # Cause of exception, a {Rye:Err}.
    attr_accessor :cause

    # Was execution's output shown immediately? If so, don't include output in message.
    attr_accessor :immediate

    # Instantiates a new exception.
    #
    # @param [String] node The name of the unknown node.
    # @param [String] command The command that failed.
    # @param [Rye::Err] cause The actual exception thrown.
    # @param [Boolean] immediate Was execution's output shown immediately? If so, don't include output in message.
    def initialize(node, command, cause, immediate)
      self.command = command
      self.cause = cause
      self.immediate = immediate

      message = <<-HERE.chomp
Failed while executing commands on node '#{node}'
- COMMAND: #{command}
- EXIT STATUS: #{cause.exit_status}
      HERE

      unless immediate
        message << <<-HERE.chomp

- STDOUT: #{cause.stdout.to_s.strip}
- STDERR: #{cause.stderr.to_s.strip}
        HERE
      end

      super(message, node)
    end

    # Returns exit status.
    #
    # @return [Integer] Exit status from execution.
    def exit_status
      return self.cause.exit_status
    end
  end
end
