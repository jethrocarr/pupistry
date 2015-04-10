# WORK IN PROGRESS

This project is currently in progress and not all of this documentation reflects
where it is really at. Use this at your own peril/madness. In theory, everything
currently works, but there will be bugs and areas of the documentation that may
not make sense.

I've marked anything I can that is in progress with TODO and workarounds/notes
where I can. It's all under development ATM so it's changing really fast, but
I'll happily take pull requests at even this early stage.


# pupistry

Pupistry (puppet + artistry) is a solution for implementing reliable and secure
masterless puppet deployments by taking Puppet modules assembled by r10k and
generating compresed and signed archives for distribution to the masterless
servers.

Pupistry builds on the functionality offered by the r10k workflow but rather
than requiring the implementing of site-specific custom bootstrap and custom
workflow mechanisms, Pupistry executes r10k, assembles the combined modules
and then generates a compress artifact file. It then signs the artifact with
GPG and uploads it into an Amazon S3 bucket along with a manifest file.

The masterless Puppet machines then just run a Pupistry job which checks for a
new version of the manifest file. If there is, it downloads the new artifact
and does a GPG validation before applying it and running Puppet. To make life
even easier, Pupistry will even spit out bootstrap files for your platform
which sets up each server from scratch to pull and run the artifacts.

Essentially Pupistry is intended to be a robust solution for masterless Puppet
deployments and makes it trivial for beginners to get started with Puppet.


# Why Pupistry?

Masterless Puppet is a great solution for anyone wanting to avoid scaling issues
and risk of centralised failure due to a central Puppet master, but it does bring
a number of issues with it.

1. Having to setup deployer keys to every git repo used is a maintainance headache. Pupistry means only your workstation needs access, which presumably will have access to most/all repos already.
2. Your system build success is dependent on all the git repos you've used, including any third parties that could vanish. A single missing or broken repo could prevent autoscaling or new machine builds at a critical time. Pupistry's use of artifact files prevents surprises - if you can hit S3, you're sorted.
3. It is easy for malicious code in the third party repos to slip in without noticing. Even if the author themselves is honest, not all repos have proper security like two-factor. Pupistry prevents surprise updates of modules and also has an easy diff feature to see what changed since you last generated an artifact.
4. Puppet masterless tends to be implemented in many different ways using everyone's own hacky scripts. Pupistry's goal is to create a singular standard/approach to masterless, in the same way that r10k created a standard approach to git-based Puppet workflows. And this makes things easy - install Pupistry, add the companion Puppet module and run the bootstrap script. Easy!
5. No dodgy cronjobs running r10k and Puppet in weird ways. A simple clean agent with daemon or run-once functionality.
6. Performance - Go from 30+ seconds r10k update checks to 2 second Pupistry update checks. And when there is a change, it's a fast efficent compressed file download from S3 rather than pulling numerious git repos.



# Usage

## Building new artifacts

Build a new artifact:

    $ pupistry build
    I, [2015-04-08T22:19:30.419392 #52534]  INFO -- : Using r10k utility to fetch the latest Puppet code
    [R10K::Action::Deploy::Environment - INFO] Deploying environment /Users/jethro/.pupistry/cache/puppetcode/master
    [R10K::Action::Deploy::Environment - INFO] Deploying module /Users/jethro/.pupistry/cache/puppetcode/master/modules/stdlib
    [R10K::Action::Deploy::Environment - INFO] Deploying module /Users/jethro/.pupistry/cache/puppetcode/master/modules/ruby
    [R10K::Action::Deploy::Environment - INFO] Deploying module /Users/jethro/.pupistry/cache/puppetcode/master/modules/gcc
    [R10K::Action::Deploy::Environment - INFO] Deploying module /Users/jethro/.pupistry/cache/puppetcode/master/modules/inifile
    [R10K::Action::Deploy::Environment - INFO] Deploying module /Users/jethro/.pupistry/cache/puppetcode/master/modules/vcsrepo
    [R10K::Action::Deploy::Environment - INFO] Deploying module /Users/jethro/.pupistry/cache/puppetcode/master/modules/git
    [R10K::Action::Deploy::Environment - INFO] Deploying module /Users/jethro/.pupistry/cache/puppetcode/master/modules/ntp
    [R10K::Action::Deploy::Environment - INFO] Deploying module /Users/jethro/.pupistry/cache/puppetcode/master/modules/firewall
    [R10K::Action::Deploy::Environment - INFO] Deploying module /Users/jethro/.pupistry/cache/puppetcode/master/modules/soe
    I, [2015-04-08T22:21:21.705315 #52534]  INFO -- : r10k run completed
    I, [2015-04-08T22:21:21.706023 #52534]  INFO -- : Creating artifact...
    I, [2015-04-08T22:21:21.999753 #52534]  INFO -- : Compressing artifact...
    I, [2015-04-08T22:21:22.103131 #52534]  INFO -- : Building manifest information for artifact...
    I, [2015-04-08T22:21:22.107012 #52534]  INFO -- : New artifact version 3f29c324aab076cd81667f9031a675e7 ready for pushing
    --
    Tip: Run pupistry diff to see what changed since the last artifact version


Note that artifact builds are done from the upstream git repos, so if you
have made changes, remember to git push first before generating. The tool will
remind you if it detects nothing has changed since the last run.

Once your artifact is built, you can double check what has changed in the
Puppet modules since the last run with:

    $ pupistry diff
    diff -Nuar unpacked.3f29c324aab076cd81667f9031a675e7/puppetcode/master/README.md unpacked.4a522dd22c0453e1e3ec3d17dfed151b/puppetcode/master/README.md
    --- unpacked.3f29c324aab076cd81667f9031a675e7/puppetcode/master/README.md	2015-04-08 22:19:42.000000000 +1200
    +++ unpacked.4a522dd22c0453e1e3ec3d17dfed151b/puppetcode/master/README.md	2015-04-08 23:01:14.000000000 +1200
    @@ -1 +1,4 @@
     Personal Puppet Repo
     +
     +Example of a changed file in a module somewhere, nice and visible for all to see.
     +
     --
     Tip: Run pupistry push to GPG sign & upload if happy to go live


Finally when you're happy, push it to S3 to be delivered to all your servers. 
If you have gpg signing enabled, it will ask you to sign here... or tell you
off if you have it disabled. :-)

    $ pupistry push
    I, [2015-04-08T22:52:01.020865 #53037]  INFO -- : Uploading artifact version latest (3f29c324aab076cd81667f9031a675e7)
    W, [2015-04-08T22:52:01.888356 #53037]  WARN -- : You have GPG signing *disabled*, whilst not critical it does weaken your security.
    W, [2015-04-08T22:52:01.888418 #53037]  WARN -- : Skipping signing step...
    I, [2015-04-08T22:52:03.043886 #53037]  INFO -- : Upload of artifact version 3f29c324aab076cd81667f9031a675e7 completed and is now latest



## Bootstrapping nodes

You need to bootstrap your masterless nodes, which involves installing Pupistry
and setting up Puppet configuration accordingly.

    pupistry bootstrap

    pupistry boostrap --template rhel7


You generally can run this on a new non-Puppetised machine, or into the user
data field of most cloud providers like AWS or Digital Ocean.


## Running Puppet on target nodes

Pupistry replaces the need to call Puppet directly. Instead, call Pupistry with
and it will handle getting the artifact and then executing Puppet for you. It
respects some parameters like --environment and --noop for easy testing of new
manifests and modules.

At it's simpliest, to apply the current Puppet manifests:

    $ pupistry apply
    I, [2015-04-10T00:44:40.623101 #6726]  INFO -- : Pulling latest artifact....
    I, [2015-04-10T00:44:42.700540 #6726]  INFO -- : Executing Puppet...
    Notice: Compiled catalog for testhost1 in environment master in 2.21 seconds
    Notice: Finished catalog run in 3.07 seconds


Check what is going to be applied (Puppet in --noop mode)

    pupistry apply --noop

Specify an alternative environment:

    pupistry apply --environment staging

Run pupistry as a system daemon. When you use the companion Puppet module, a
system init file gets installed that sets this daemon up for you automatically.

    pupistry apply --daemon


Alternatively, if you don't wish to use Pupistry to run the nodes, you don't
have to. You can use Pupistry to build the artifacts and then pull them down
and unpack via any means you find appropiate. It's just standard S3 + tar with
some YAML and optional GPG signing.


# Installation

## 1. Application

First install Pupistry onto your workstation. You can make pupistry generate
you a config file if you've never used it before

    gem install pupistry
    pupistry setup

Alternatively if you like living on the edge, download this repository and run:

    gembuild pupistry.gemspec
    gem install pupistry-VERSION.gem
    pupistry setup

TODO: Currently setup not implemented, copy the sample file provided.

## 2. S3 Bucket

Pupistry uses S3 for storing and pulling the artifact files. You need to
configure the following:

* A *private* S3 bucket (you'll get this by default).
* An IAM account with access to write that bucket (for your build workstation)
* An IAM account with access to read that bucket (for your servers)

If you're not already using IAM with your AWS account you want to be - your
servers should only ever have read access to the bucket and only your build
workstation should be permitted to write new artifacts. IE, don't share your
AWS root account around the place. :-)

Note that if you're running EC2 instances and using IAM roles, you can avoid
needing to create explicit IAM credentials for the agents/servers.



## 3. Puppet Manifests & Configuration

### Puppet Code Structure

The following is the expected minmum structure of the Puppetcode repository to
enable it to work with Pupistry:

    /Puppetfile
    /hiera.yaml
    /manifests/site.pp

Puppetfile is standard r10k and site.pp is standard Puppet. The Hiera config
is generally normal, but you do need to define a datadir to tell Puppet to look
where the puppetcode gets unpacked to. Generally the following sample Hiera
will do the trick:

    ---
    :backends: yaml
    :yaml:
      :datadir: "%{::settings::confdir}/environments/%{::environment}/hieradata"
    :hierarchy:
     - "environments/%{::environment}"
     - "nodes/%{::hostname}"
     - common

Then in Pupistry, the following configuration should be used for the agent (or
subsitute `/etc/puppet/` for wherever your platform has `%{::settings::confdir}`
set to).

      agent:
        puppetcode: /etc/puppet/environments

Pupistry will default to applying the "master" branch if one is not listed, if
you are doing branch-based environments, you can specifiy when bootstrapping
and override on a per-execution basis.

You'll notice pretty quickly if something is broken when doing `puppet apply`

Confused? No worried, check out the sample repo that shows a very simple setup.
You can copy this and start your own Puppet adventure, just add in your modules
to Puppetfile and add them to the relevent machines in manifests/site.pp.

https://github.com/jethrocarr/pupistry-samplepuppet 


TODO: Longer term intend to add support for various popular structure, but
for now it is what it is. It's not hard, check out bin/puppistry and send
pull requests.


### Helper Module

Whilst you can use Pupistry to roll out any particular design of Puppet
manifests, you will save yourself a lot of pain by also including the Pupistry
companion Puppet module in your manifests.

The companion Puppet module will configure Pupistry for you, including setting
up the system service and configuring Puppet and Hiera correctly for masterless
operation.

You can fetch the module from:
https://github.com/jethrocarr/puppet-pupistry

If you're doing r10k and Puppet masterless from scratch, this is probably
something you want to make life easy. With r10k, just add the following to your
Puppetfile:

    # Install the Pupistry companion module
    mod 'jethrocarr/pupistry'



## 4. Bootstrapping Nodes

No need for manual configuration of your servers/nodes, you just need to build
your first artifact with Pupistry (`pupistry build && pupistry push`) and then
generate a bootstrap script for your particular OS with `pupistry bootstrap`

The bootstrap script will:

1. Install Puppet and Pupistry for the particular OS.
2. Download the latest artifact
3. Trigger a Puppet run to build your server.

Once done, it's up to your Puppet manifests to build your machine how you want
it - enjoy!

TODO: Currently being worked on, for now the following is a rough example of
what you can do to bootstrap a RHEL/CentOS7 box:

    rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm
    rpm -ivh http://download.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm

    yum update --assumeyes
    yum install --assumeyes puppet ruby-devel rubygems
    yum install --assumeyes gcc zlib-devel libxml2-devel patch

    gem install pupistry
    mkdir /etc/pupistry
    cat > /etc/pupistry/settings.yaml << "EOF"
    general:
      app_cache: ~/.pupistry/cache
      s3_bucket: example
      s3_prefix:
      gpg_disable: true
      gpg_signing_key: XXXXX
    agent:
      puppetcode: /etc/puppet/environments
      access_key_id: 
      secret_access_key: 
      region: ap-southeast-2
      proxy_uri:
    EOF
    pupistry apply --verbose

It will setup the Puppet repo for RHEL 7, install updates (remember that security
thing?) and then install the gem (and deps to build it). Then we generate the
minimal configuration file needed, and kick off a Puppet run!



# Tutorials

If you're looking for a more complete introduction to doing masterless Puppet
and want to use Pupistry, check out a tutorial by the author:

TUTORIAL LINK HERE

By following this tutorial you can go from nothing, to having a complete up
and running masterless Puppet environment using Pupistry. It covers the very
basics of setting up your r10k environment.


# Caveats & Future Plans

## Use r10k

Currently only an r10k workflow is supported. Pull requests for others (eg
Librarian Puppet) are welcome, but it's not a priority for this author as r10k
is working nicely.


## Bootstrap Functionality

Currently Pupistry only supports generation of bootstrap for CentOS 7 & Ubuntu
14.04. Other distributions will be added, but it may take time to get to your
particular favourite distribution.

Note that it isn't a show stopper if support for your platform of choice
doesn't yet exist -  you can use pupistry with pretty much any nix platform,
you'll just not have the handy advantage of automatically generated bootstrap
for your servers.

If you do customise it for a different platform, pull requests are VERY
welcome, I'll add pretty much any OS if you write a decent bootstrap template
for it.


## Continious Deployment

A lot of what Pupistry does can also be accomplished by various home-grown
Continious Deployment (CD) solutions using platforms like Jenkins or Bamboo. CD
is an excellent approach for larger organisations, but Pupistry has been
designed for both large and small users so does not mandate it.

It would be possible to use Pupistry as part of your CD process and if you
decide to do so, a pull request to better support CD systems out-of-the-box
would be welcome.


## Hiera Security Still Sucks

In a standard Puppet master situation, the Puppet master parses the Hiera data
and then passes only the values that apply to a particular host to it. But with
masterless Puppet, all machines get a full copy of Hiera data, which could be a
major issue if one box gets expoited and the contents leaked. Generally it goes
against good practise and damanges the isolation ability of VMs if you give all
the VMs enough information to do some serious damage to themselves.

Pupistry does not yet have any solution for it and it remains a fundamental
limitation of the Puppet masterless approach. Longer term, we could potentially
craft a solution that customises the artifacts per-machine to fix this security
gap, but there's no proper solution currently.

If you have an environment where you need to send lots of sensitive values to
your servers, a traditional master-full Puppet environment may be a better
solution for this reason. But if you can architect to avoid this or have no
critical secrets in Hiera, Pupistry should be good for you.


## PuppetDB

There's nothing stopping you from using PuppetDB other than Pupistry has no
automatic setup hooks in the bootstrap config. Pull requests to support
PuppetDB for masterless machines are welcome, although masterless users tend
to want to avoid dependencies on a central point.


## Windows

No idea whether this works under Windows, or what would be required to make it
do so. Again, pull requests always welcome but it's not a priority for the
author.



# Developing

When developing Pupistry, you can run the git repo copy with:

    ruby -Ilib/ -r rubygems bin/pupistry

By default Pupistry will try to load a settings.yaml file in the current
working directory, before then trying `~/.pupistry/settings.yaml` and then
finally `/etc/pupistry/settings.yaml`. You can also override with `--config`.

Add `--verbose` for additional debugging information. If you have a bug this
is the first thing you should run to get more context for reports.


# Contributions

Pull requests are very welcome. Pupistry is a very young app and there is
plenty of work that can be done to improve it's code quality, enhance existing
features and add handy new features. Constructive feedback/requests via the
issue tracker is fine, but pull requests speak louder than words. :-)

If you find a bug or need support, please use the issue tracker rather than
personal emails to the author.


# Author

Pupistry is developed by Jethro Carr. Blog posts about Pupistry and new
features can be found at http://www.jethrocarr.com/tag/pupistry

Beer welcome.


# License

Pupistry is licensed under the Apache License, Version 2.0 (the "License").
See the `LICENSE.txt` or http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
