# Packer Templates

This directory contains templates for use with Packer (https://www.packer.io/).

It can be very useful to use Packer with Pupistry, since it allows you to
create your own image with Puppet, Pupistry and updates already loaded which
is very useful when doing autoscaling and you need fast, consistent startup
times.

The packer templates provided will build an image which has Pupistry installed
and will apply any manifests that match hostname of "packer". This should give
you a good general purpose image, but if you want to autoscale a particular app
you may wish to build packer images using specific hostnames to match your
Puppet manifests

Additional packer templates for major platforms are always welcome. Please
submit a pull request for review and if acceptable, will be merged.


# Usage

Refer to the main application README.md file for usage information.


# Development Notes

The filenames of the templates must be in the format of
PLATFORM_OPERATINGSYSTEM.json.erb, this is intentional since OPERATINGSYSTEM
then matches one of the OSes in the bootstrap directory and we can
automatically populate the inline shell commands.

When debugging broken packer template runs, add -debug to the build command
to have control over stepping through the build process. This will give you
the ability to log into the instance before it gets terminated to do any
debugging on the system if needed.


# Examples

See the "aws_amazon-any.json.erb" template for an example on how the templates
should be written for AWS.


# Life Span

Any distribution that is EOL and no longer supported by either the distribution
or by Puppetlabs will be subject to removal to keep the bootstrap selection
modern and clean. Pull requests to clean up cruft are accepted.

