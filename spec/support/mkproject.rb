# Creates temporary directory and cd's into it.
#
# If a block is supplied, it is executed within this directory, and when done, it cd's back and removes the directory.
#
# Without a block, it just creates the directory, cd's into it and returns the directory's path for you to cleanup yourself.
def mktmpdircd(&block)
  if block
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        yield(dir)
      end
    end
  else
    dir = Dir.mktmpdir
    Dir.chdir(dir)
    return dir
  end
end

def mkproject(&block)
  create = lambda { Pocketknife.new(:verbosity => false).create('.') }
  if block
    mktmpdircd do |dir|
      create.call
      yield(dir)
    end
  else
    dir = mktmpdircd
    create.call
    return dir
  end
end
