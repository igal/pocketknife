# Silences any stream for the duration of the block.
#
# File activesupport/lib/active_support/core_ext/kernel/reporting.rb, line 39
def silence_stream(stream)
  old_stream = stream.dup
  stream.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
  stream.sync = true
  yield
ensure
  stream.reopen(old_stream)
end
