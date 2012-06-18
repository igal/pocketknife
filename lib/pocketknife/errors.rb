class Pocketknife
  # == Error
  #
  # Superclass of all Pocketknife errors.
  class Error < StandardError
    # == InvalidTransferMechanism
    #
    # Exception raised when given an invalid transfer mechanism, e.g. not :tar or :rsync.
    class InvalidTransferMechanism < Error
      # @return [Symbol] Transfer mechanism that failed.
      attr_accessor :mechanism

      def initialize(mechanism)
        super("Invalid transfer mechanism: #{mechanism}")
      end
    end

    # == NodeError
    #
    # An error with a {Pocketknife::Node}. This is meant to be subclassed by a more specific error.
    class NodeError < Error
      # @return [String] The name of the node.
      attr_accessor :node

      # Instantiate a new exception.
      #
      # @param [String] message The message to display.
      # @param [String] node The name of the unknown node.
      def initialize(message, node)
        self.node = node
        super(message)
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

      # == RsyncError
      #
      # Exception raised if rsync command failed.
      class RsyncError < NodeError
        # @return [String] Command that failed.
        attr_accessor :command

        def initialize(command, node)
          super("Failed while rsyncing: #{command}", node)
        end
      end

      # == ExecutionError
      #
      # Exception raised when something goes wrong executing commands against remote host.
      class ExecutionError < NodeError
        # @return [String] Command that failed.
        attr_accessor :command

        # @return [Rye::Err] Cause of exception, a Rye:Err.
        attr_accessor :cause

        # @return [Boolean] Was execution's output shown immediately? If so, don't include output in message.
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

  end

  InvalidTransferMechanism = Pocketknife::Error::InvalidTransferMechanism
  NodeError = Pocketknife::Error::NodeError
  NoSuchNode = Pocketknife::Error::NodeError::NoSuchNode
  UnsupportedInstallationPlatform = Pocketknife::Error::NodeError::UnsupportedInstallationPlatform
  NotInstalling = Pocketknife::Error::NodeError::NotInstalling
  RsyncError = Pocketknife::Error::NodeError::RsyncError
  ExecutionError = Pocketknife::Error::NodeError::ExecutionError
end
