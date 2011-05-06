pocketknife
===========

`pocketknife` is a devops tool for managing computers running `chef-solo`, powered by [Opscode Chef](http://www.opscode.com/chef/).

Using `pocketknife`, you create a project that describes the configuration of your computers and then apply it to bring them to the intended state.

With `pocketknife`, you don't need to setup or manage a specialized `chef-server` node or rely on an unreliable network connection to a distant hosted service whose security you don't control, deal with managing `chef`'s security keys, or deal with manually synchronizing data with the `chef-server` datastore.

With `pocketknife`, all of your configuration, credentials and node information is stored in easy-to-use files that you can edit, share, backup and version control with tools you already have.

Comparisons
-----------

Why create another tool?

* `knife` is included with `chef` and is primarily used for managing client-server nodes. The `pocketknife` name plays off this by virtue that it's a smaller, more personal way of managing nodes.
* `chef-client` is included with `chef`, but you typically need to install another node to act as a `chef-server`, which takes more resources and effort. Using `chef` in client-server mode provides benefits like network-wide databags and pull-based updates, but if you can live without these, `pocketknife` can save you a lot of effort.
* `chef-solo` is included as part of `chef`, and `pocketknife` uses it. However, `chef-solo` is a low-level tool, and creating and deploying all the files it needs is a significant chore. It also provides no way of deploying or managing your shared and node-specific configuration files. `pocketknife` provides all the missing functionality for creating, managing and deploying, so you don't have to use `chef-solo` directly.
* `littlechef` is the inspiration for `pocketknife`, it's a great project that I've contributed to and you should definitely [evaluate it](https://github.com/tobami/littlechef). I feel that `pocketknife` offers a more robust, repeatable and automated mechanism for deploying remote nodes; has better documentation, default behavior and command-line support; has good tests and a clearer, more maintainable design; and is written in Ruby so you use the same stack as `chef`.

Usage
-----

Install the software on the machine you'll be running `pocketknife` on, this is a computer that will deploy configurations to other computers:

* Install Ruby: http://www.ruby-lang.org/
* Install Rubygems: http://rubygems.org/
* Install `pocketknife`: `gem install pocketknife`

Create a new *project*, a special directory that will contain your configuration files. For example, create the `swa` project directory by running:

    pocketknife --create swa

Go into your new *project* directory:

    cd swa

Create cookbooks in the `cookbooks` directory that describe how your computers should be configured. These are standard `chef` cookbooks, like the [opscode/cookbooks](https://github.com/opscode/cookbooks). For example, download a copy of [opscode/cookbooks/ntp](https://github.com/opscode/cookbooks/tree/master/ntp) as `cookbooks/ntp`.

Override cookbooks in the `site-cookbooks` directory. This has the same structure as `cookbooks`, but any files you put here will override the contents of `cookbooks`. This is useful for storing the original code of a third-party cookbook in `cookbooks` and putting your customizations in `site-cookbooks`.

Optionally define roles in the `roles` directory that describe common behavior and attributes of your computers using JSON syntax using [chef's documentation](http://wiki.opscode.com/display/chef/Roles#Roles-AsJSON). For example, define a role called `ntp_client` by creating a file called `roles/ntp_client.json` with this content:

    {
      "name": "ntp_client",
      "chef_type": "role",
      "json_class": "Chef::Role",
      "run_list": [
        "recipe[ntp]"
      ],
      "override_attributes": {
        "ntp": {
          "servers": ["0.pool.ntp.org", "1.pool.ntp.org", "2.pool.ntp.org", "3.pool.ntp.org"]
        }
      }
    }

Define a new node using the `chef` JSON syntax for [runlist](http://wiki.opscode.com/display/chef/Setting+the+run_list+in+JSON+during+run+time) and [attributes](http://wiki.opscode.com/display/chef/Attributes). For example, define a node called `henrietta` by creating the `nodes/henrietta.json` file with these contents so that it uses the `ntp_client` role and overrides its attributes:

    {
      "run_list": [
        "role[ntp_client]"
      ],
      "override_attributes": {
        "ntp": {
          "servers": ["0.it.pool.ntp.org", "1.it.pool.ntp.org", "2.it.pool.ntp.org", "3.it.pool.ntp.org"]
        }
      }
    }

Optionally specify credentials for your new node using [YAML](http://www.yaml.org/start.html). You should consider [configuring ssh-agent](http://mah.everybody.org/docs/ssh) so you don't have to keep typing in your passwords. By default, `pocketknife` uses `ssh` and assumes that your node has the same hostname as the node name. However, if the node and hostname are different, you will need to configure this. For example, let's specify that node `henrietta` has a hostname of `fnp90.swa.gov.it` by creating a `auth.yml` file with this content:

    henrietta:
        hostname: fnp90.swa.gov.it

Next, install `chef` on the remote machine. In the future, `pocketknife` may do this automagically for you.

Finally, deploy your configuration to the remote machine and see the results. For example, lets deploy the above configuration to `henrietta`:

    pocketknife henrietta

If something went wrong while applying the configuration, you may want to view `chef`'s verbose logging information by applying the configurations with the `-v` option. For example, apply the configuration to `henrietta` with verbose logging:

    pocketknife -v henrietta

If you really need to debug on the remote machine, you may be interested about some of the commands and paths:

* `chef-solo-apply` (/usr/local/sbin/chef-solo-apply) will apply the configuration to the machine. You can specify `-l debug` to make it more verbose. Run it with `-h` for help.
* `csa` (/usr/local/sbin/csa) is a shortcut for `chef-solo-apply` and accepts the same arguments.
* `/etc/chef/solo.rb` contains the `chef-solo` configuration settings.
* `/etc/chef/node.json` contains the node-specific configuration, like the `runlist` and attributes.
* `/var/local/pocketknife` contains the `cookbooks`, `site-cookbooks` and `roles` describing your configuration.

Contributing
------------

This software is published as open source at https://github.com/igal/pocketknife

You can view and file issues for this software at https://github.com/igal/pocketknife/issues

If you'd like to contribute code or documentation:

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.
* Submit a pull request using github, this makes it easy for me to incorporate your code.

Copyright
---------

Copyright (c) 2011 Igal Koshevoy. See `LICENSE.txt` for further details.
