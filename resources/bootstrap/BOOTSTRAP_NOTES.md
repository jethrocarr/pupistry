# Bootstrap Scripts

Additional bootstrap scripts for major platforms are always welcome. Please
submit a pull request for review and if acceptable, will be merged.


# Development Guide Lines

DO:

* Install Puppet from the most OS-native source possible - either distribution repos, or Puppetlab's repos.
* Install Pupistry from the most OS-native source - either distribution repos, or rubygems.
* Install the latest OS updates for the platform - not all users will want this, but we should provide a good default security example.
* Wrap the user data in a Bash subshell & log all output to syslog - most systems are headless and it's very useful for debug. Also remember to log the commands being run themselves (`#!/bin/bash -x` will do this for you).
* Test the script both in cut & paste into your distro, but also via the user-data field of a major provider like AWS or Digital Ocean. Sometimes interesting bugs show up like user-data being run before networking is ready, or some distributions not defining key environmentals when running user data.

DON'T:

* Use third party respositories or download sites, it needs to be stock vendor OS and packages.
* Execute code from third party sites (eg no wget http://example.com/malware/myscript.sh)
* Tie user data to any particular cloud provider unless unavoidable for that platform.
* Make the script any more complex than it needs to be.


# Examples

See the "centos-7" or "ubuntu-14.04" templates for examples on how the bootstrap
templates should be written. The "fedora-any" template also shows an example of
dealing with networking not being ready and also how to handle frequently
changing distribution versions.


# Life Span

Any distribution that is EOL and no longer supported by either the distribution
or by Puppetlabs will be subject to removal to keep the bootstrap selection
modern and clean. Pull requests to clean up cruft are accepted.

