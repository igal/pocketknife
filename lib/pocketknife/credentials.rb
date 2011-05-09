class Pocketknife
  # == Credentials
  #
  # A Settingslogic class that provides authentication credentials for how to
  # login to a {Pocketknife::Node}. It looks for an <tt>credentials.yml</tt>
  # file, which can contain a list of nodes and their credentials. If there is
  # no credentials file or no credentials for the host, it defaults having the
  # hostname being the same as the node name and the user being +root+.
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

    # @private
    # Is the Settingslogic data sane? This is used as part of a workaround for
    # a Settingslogic bug where an empty file causes it to fail with:
    #
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
end
