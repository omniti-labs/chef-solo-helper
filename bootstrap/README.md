# Serverless bootstrap scripts

Overview of files:

`bootstrap-ssh.sh` copies the bootstrap script and git key to the remote server
and runs the bootstrap script. This is intended to be used from your
laptop/desktop on a freshly created server that you have ssh access (with
sudo) to.

`local_scripts/bootstrap-*.sh` sets up the chef repository on the remote
server, checking it out and setting up the services. These scripts are
designed to be run on the remote server itself by `bootstrap-ssh.sh` or
`bootstrap-zlogin.sh` and do not normally need to be run manually. You need to
pick the correct one in the OS.

`chef.key` should be the ssh private key used to access the chef repository on
the git server. It will be copied to all machines and should provide read
only access for pulling updates.

## Configuring the bootstrap scripts

The bootstrap scripts require some configuration to specify things like which
repositories to use. This is done in a config.sh file. There is a sample file
provided, which you can change as needed. Some useful parameters:

 - USERNAME - the username you use to connect to the remote system. For ubuntu
   ec2 instances, this is `ubuntu`.
 - BOOTSTRAP_SCRIPT - This lets you specify an alternative bootstrap.sh script
   that is copied over to the remote system, which is useful if you need to
   modify it.
 - SCRIPTS_REPO, CONFIG_REPO, COMMON_REPO - paths to the git repositories
   containing the chef configuration
    - The script repository should be the repository with the run_chef.sh
      script in it.
    - The config repository should contain the chef configuration (cookbooks,
      nodes, roles etc.)
    - The common repository is optional, and can contain extra cookbooks that
      are common to multiple chef installations. If you don't need this, then
      leave it blank.
 - GIT_HOST - If set, this pre-populates the ssh known hosts file before
   trying to clone the git repositories. The value of this variable is the
   hostname to use and should match the git host used.

## Running the bootstrap script

Before running the bootstrap-ssh.sh script, you should have ssh access to the
machine you want to bootstrap, and should be able to run sudo.

Once the configuration is set up, you just need to run:

    ./bootstrap-ssh [-c config.sh] [address] [nodename]

Where `address` is the address of the server, and `nodename` is the hostname
you wish to assign to the server. At this point, the server has just been set
up and doesn't know what its hostname is, so the bootstrap script will set the
hostname, which will then ensure that chef knows what to do. If the hostname
has been set correctly already, then the nodename parameter can be omitted.

## Ec2 scripts

In addition, there are some scripts/files for setting up a new ec2 instance
quickly:

`ec2/new_instance.rb` creates a blank instance in ec2. This step could be
accomplished instead via the web interface or other method of ec2 instance
creation if desired. Of course, this step can be skipped if ec2 is not in use.

`config.rb` contains the configuration for setting up a new ec2 instance. Look
at the `config.rb.sample` file (and/or read below) for how to set this up.

### Setting up the new instance script

Install the following gems (if you have chef, then they should already be
installed):

 - fog
 - highline
 - mixlib-config

Set up your config.rb based on the sample:

 - The AWS api keys should be provided to you
 - The ssh key name is the name of the ssh key in the AWS web console for you
   to connect to newly created instances.
 - If you don't have an ssh key, create one in the AWS console:
    - EC2 tab
    - Network & Security section
    - Key Pairs
    - Create key pair
        - Alternatively, there is now an import key pair button to import
          existing ssh keys
    - Store this somewhere in your home directory. A separate file called
      something similar to ~/.ssh/ec2.asc is a good option.

Run the new_instance script. The questions are pretty straightforward, and
most of the options are multiple choice.
