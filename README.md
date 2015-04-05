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
and does a GPG validation before applying it and running Puppet.

To make life even easier, Pupistry will even spit out bootstrap files for your
platform which sets up each server from scratch to pull and run the artifacts.


# Usage

## Installation

The same gem is installed on both the workstation and the remote application.

    gem install pupistry

Alternatively, download this repository and run:
    gembuild pupistry.gemspec
    gem install pupistry-VERSION.gem


## S3 Bucket

Pupistry uses S3 for storing and pulling the artifact files. You need to
configure the following:

* A *private* S3 bucket.
* An IAM account with access to write that bucket (for your engineer)
* An IAM account with access to read that bucket (for your servers)

If you're not already using IAM with your AWS account you want to be - your
servers should only ever have read access to the bucket and only your engineer
or workstation should be able to make changes to it.


## Helper Puppet Module

Whilst you can use Pupistry to roll out any particular design of Puppet
manifests, you will save yourself a lot of pain by also including the Pupistry
companion Puppet module in your manifests.

The companion Puppet module will configure Pupistry for you, including setting
up the system service and configuring Puppet and Hiera correctly for masterless
operation.

You can fetch the module from:
https://github.com/jethrocarr/pupistry-puppet



## Generating new artifacts

Generate a new artifact:
    pupistry generate

Note that artifact generation is done from the upstream git repos, so if you
have made changes, remember to git push first before generating.


Display a diff of what files have changed since the last artifact:
    pupistry diff


Push the artifact to S3 for the servers to pull. This step signs the artifact.
    pupistry push


## Bootstrapping nodes

You need to bootstrap your masterless nodes, which involves installing Pupistry
and setting up Puppet configuration accordingly.

    pupistry bootstrap

    pupistry boostrap --template rhel7


You generally can run this on a new non-Puppetised machine, or into the user
data field of most cloud providers like AWS or Digital Ocean.


## Running Puppet on target nodes

Check what is going to be applied (Puppet in --noop mode)
    pupistry apply --noop

Apply the current Puppet manifests:
    pupistry apply

Specify an alternative environment:
    pupistry apply --environment staging

Run pupistry as a system daemon:
    pupistry apply --daemon


# Tutorials

If you're looking for a more complete introduction to doing masterless Puppet
and want to use Pupistry, check out a tutorial by the author:

TUTORIAL LINK HERE


# Why Pupistry?

Masterless Puppet is a great solution for anyone wanting to avoid scaling issues
and risk of centralised failure due to a central Puppet master, but it does bring
a number of issues with it.


## Security

Security takes an unfortunate hit with masterless Puppet. There are three main
issues:

* All servers need access provided to all your git repos for Puppet modules.
* Third party repositories could change at any time.
* All machines can read all hiera data.


### Git Repo Access

It is a hassle having to setup deployer access keys for every machine to be
able to read every one of your git repositories. And if a machine is
compromised, it needs to be changed for every repo and every server.

By using the artifact approach, your servers no longer need access to the git
repos themselves and if one machine is exploited, you just need to change the
IAM credentials used, rather than every single repo.


### Third Party Repositories

The power of using r10k to assemble numerious third party Puppet modules hosted
on the forge, on github or other third party git services is incredible. But it
has the major failing of essentially limiting your security to the
trustworthyness of all the third parties you select.

In some cases the author is relatively unknown and could suddenly decide to
start including malicious content, or in other cases the security of the
platform provide the modules is at risk (eg Puppetforge doesn't require any
two-factor auth for module authors) and a malicious attacker could attack the
platform in order to compromise thousands of machines.

Some organisations fix this by still using r10k but always forking any third
party modules before using them, but this has the download of increased manual
overhead to regularly check for new updates to the forked repos and pulling
them down.


### Hiera Data Limitation.

The Hiera limitation is important to note.

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


## Reliabilty

When using r10k masterless, a single repo failing to download could prevent a
machine from being built. Nobody wants to find that someone chose to delete the
GitHub repo you rely on just minutes before your production host autoscaled and
failed to startup.

By using the artifact file approach, there is no risk of a machine being unable
to come up due to missing Puppet module repos - as long as your machine can reach
your S3 bucket, it will be able to download the artifact and execute Puppet.

Naturally you're still at risk if you write Puppet modules that require third
parties (eg repos, gems, etc) however that's up to you to decide - Pupistry won't
let you down. :-)


## Performance

Whilst r10k deserves a lot of credit for being speedy, it's still no match for
a single HTTP GET request. Pupistry makes checking for new manifests very very
fast and the compressed archive downloads very quickly.

A very clean and simple set of Puppet manifests can still take a good 20+ secs
to check for updates with r10k, vs 1-2 secs with Pupistry.



# Caveats & Future Feature Plans

## Use r10k

Currently only an r10k workflow is supported. Pull requests for others (eg
Librarian Puppet) are welcome, but it's not a priority for this author.


## Bootstrap Functionality

Currently Pupistry only supports generation of bootstrap for CentOS 7 & Ubuntu
14.04. Other distributions will be added over time, and patches are welcome.

Note that this isn't a showstopper, you can use pupistry with pretty much any
nix platform, you'll just not have the handy advantage of automatically
generated bootstrap for your servers - but you can certainly take what has been


## AWS IAM Usage

Currently we expect a specific IAM account to be configured for read & writing
the artifacts. However if you are on AWS itself, there is a feature called roles
that allows permissions to be granted to a particular machine automatically.

Longer term we expect to add native support for this roles functionality, but for
now you will need to fetch the IAM details and pass them to Pupistry yourself.


## Continious Deployment

A lot of what Pupistry does can also be accomplished by various home-grown
Continious Deployment (CD) solutions using platforms like Jenkins or Bamboo. CD
is an excellent approach for larger organisations, but Pupistry has been
designed for both large and small users so does not mandate it.

It would be possible to use Pupistry as part of your CD process and if you
decide to do so, a pull request to better support CD systems out-of-the-box
would be welcome.



# Developing

When developing Pupistry, you can invoke the git repo copy with:
    ruby -Ilib/ -r rubygems bin/pupistry


# Author

Pupistry is developed by Jethro Carr:
http://www.jethrocarr.com/tag/pupistry


# Other Information

This tool is built around the use of r10k for your Puppet workflow. If you are
not familuar with r10k, check it out at https://github.com/acidprime/r10k

