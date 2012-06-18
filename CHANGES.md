Changes
=======

* 0.2.0
    * [!] Changed default transfer mechanism to `rsync` from `tar` in past versions.
    * Added transfer mechanisms, allowing the choice of `rsync` and `tar` for uploading files to nodes. The new `rsync` option deals gracefully with symlinks in your sources and is faster for making small changes. See "Transfer mechanisms" section in the README for details. Suggested by Roland Moriz.
    * Added data bags support, contributed by Richard Livsey.
    * Added ability to override the runlist. See "Override runlist" in the README for details.
    * Added shellwords to properly escape strings in commands.
    * Added clear success message and timer, suggested by Trip Leonard.
    * Added clearer error message when `nodes` directory is missing.
    * Added support for travis-ci to test with various versions of Ruby.
    * Fixed exception thrown if some directories were missing.
    * Fixed CLI to catch all OptionParser errors.
    * Reorganized errors into Pocketknife::Errors hierarchy, while using aliases to retain backwards compatibilty.
    * Improved README and internal documentation.

* 0.1.0
    * First release
