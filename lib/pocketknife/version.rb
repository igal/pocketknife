class Pocketknife
  # == Version
  #
  # Information about the Pocketknife version.
  module Version
    # @return [Integer] Major version.
    MAJOR = 0
    # @return [Integer] Minor version.
    MINOR = 2
    # @return [Integer] Patch version.
    PATCH = 0
    # @return [Integer] Build version.
    BUILD = nil

    # @return [String] The version as a string.
    STRING = [MAJOR, MINOR, PATCH, BUILD].compact.join('.')
  end
end
