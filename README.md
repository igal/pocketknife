pocketknife
===========

`pocketknife` is a devops tool for managing computers running `chef-solo`, powered by [Opscode Chef](http://www.opscode.com/chef/).

Using `pocketknife`, you create a project that describes the configuration of your computers and then deploy it to bring them to their intended state.

With `pocketknife`, you don't need to setup or manage a specialized `chef-server` node or rely on an unreliable network connection to a distant hosted service whose security you don't control, deal with managing `chef`'s security keys, or deal with manually synchronizing data with the `chef-server` datastore.

With `pocketknife`, all of your cookbooks, roles and nodes are stored in easy-to-use files that you can edit, share, backup and version control with tools you already have.

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

Define a new node using the `chef` JSON syntax for [runlist](http://wiki.opscode.com/display/chef/Setting+the+run_list+in+JSON+during+run+time) and [attributes](http://wiki.opscode.com/display/chef/Attributes). For example, to define a node with the hostname `henrietta.swa.gov.it` create the `nodes/henrietta.swa.gov.it.json` file, and add the contents below so it uses the `ntp_client` role and overrides its attributes to use a local NTP server:

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

Operations on remote nodes will be performed using SSH. You should consider [configuring ssh-agent](http://mah.everybody.org/docs/ssh) so you don't have to keep typing in your passwords.

Finally, deploy your configuration to the remote machine and see the results. For example, lets deploy the above configuration to the `henrietta.swa.gov.it` host, which can be abbreviated as `henrietta` when calling `pocketknife`:

    pocketknife henrietta

When deploying a configuration to a node, `pocketknife` will check whether Chef and its dependencies are installed. It something is missing, it will prompt you for whether you'd like to have it install them automatically.

To always install Chef and its dependencies when they're needed, without prompts, use the `-i` option, e.g. `pocketknife -i henrietta`. Or to never install Chef and its dependencies, use the `-I` option, which will cause the program to quit with an error rather than prompting if Chef or its dependencies aren't installed.

If something goes wrong while deploying the configuration, you can display verbose logging from `pocketknife` and Chef by using the `-v` option. For example, deploy the configuration to `henrietta` with verbose logging:

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
