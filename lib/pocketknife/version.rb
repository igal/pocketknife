class Pocketknife
  # == Version
  #
  # Information about the Pocketknife version.
  module Version
    MAJOR = 0
    MINOR = 1
    PATCH = 0
    BUILD = nil

    STRING = [MAJOR, MINOR, PATCH, BUILD].compact.join('.')
  end
end
