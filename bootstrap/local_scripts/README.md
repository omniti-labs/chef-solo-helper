# Local bootstrap scripts

This directory contains local bootstrap scripts that are run on the server
where chef is being bootstrapped. The scripts do the work of installing chef,
cloning any required repositories, and running chef for the first time. There
are different bootstrap scripts for each OS.

## Creating a bootstrap script

Most bootstrap scripts will look pretty similar, except for the code needed to
install chef and git. To facilitate this, there is a bootstrap_commmon.sh
script that you can (and should) source at the top of your boostrap file.

The first task you will want to do is implement the `install_chef` and
`install_git` functions, which should install chef and git respectively. If
you prefer to install them both at once (e.g. with your package manager), you
can implement `install_packages` instead.

Once you have done that, you will want to implement any other functions that
have behavior different from the default.

Finally, you will want to run the do_bootstrap command at the end of the
script. This simply calls each step of the bootstrap in turn. Each command
called is a function that you can override if desired. The functions are:

 * load_config - loads the config.sh file that specifies various
   system/project specific variables.
 * install_packages - installs chef and git (calls install_chef and
   install_git by default)
 * make_chef_dir - Makes /var/chef-solo (or other directory as defined in
   config.sh), and moves any existing dir aside if it already exists.
 * install_key - installs the chef.key file, used to clone git repos
 * schlep_files - copies any other files in place as specified in config.sh,
   such as checkout_list
 * populate_known_hosts - populates the .ssh/known_hosts file as needed
 * make_git_wrapper - creates a wrapper around git to use a custom ssh key
 * clone_repos - clones the scripts repository
 * additional_tasks - doesn't do anything by default. You can override this if
   you need to make your script do anything else before running chef.
 * run_chef - runs chef for the first time
