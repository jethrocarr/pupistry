# AWS Resources

This directory contains resources for use with AWS and Pupistry


## cfn_pupistry_bucket_and_iam.template

This is an template that can build an S3 bucket plus two IAM accounts, one for
the Pupistry build host and another for the hosts running Pupistry itself and
needing read access to the bucket.

It's a perfectly functional stack which is parameterised so you can simply
enter your specific details (like desired bucket name) and it will go and build
a complete setup of the AWS resources needed for using Pupistry that is
suitable for most end users.

Altneratively if you have complex requirements, feel free to incorporate the
ideas and examples of this stack into your own design.

Building the stack (simple):

    aws cloudformation create-stack \
    --capabilities CAPABILITY_IAM \
    --template-body file://cfn_pupistry_bucket_and_iam.template \
    --stack-name pupistry-resources


Building the stack and setting specific parameter values

    aws cloudformation create-stack \
    --capabilities CAPABILITY_IAM \
    --template-body file://cfn_pupistry_bucket_and_iam.template \
    --stack-name pupistry-resources \
    --parameters \
    ParameterKey=S3BucketName,ParameterValue=pupistry-example-bucket \
    ParameterKey=S3BucketArchive,ParameterValue=30 \
    ParameterKey=S3BucketPurge,ParameterValue=365



Make sure the stack has finished building/is built:

    aws cloudformation describe-stacks --query "Stacks[*].StackStatus" --stack-name pupistry-resources

Status should be "COMPLETE", if it is set to "ROLLBACK" then it has failed to
build. If set to "CREATE_IN_PROGRESS" then you need to give it more time.


Fetching details from the stack:

    aws cloudformation describe-stacks --query "Stacks[*].Outputs[*]" --stack-name pupistry-resources

Deleting the stack:

    aws cloudformation delete-stack --stack-name PupistryResources

Note that if the S3 bucket is not empty (ie you've used it for Pupistry
artifacts) then it will fail to delete. Make sure you delete all items from
the S3 bucket first, then delete the stack. This is generally considered a
useful safety feature. ;-)

You can delete all items with:

     aws s3 rm --recursive s3://pupistry-resources-changeme


## Developer Notes

CloudFormation is an awesome and powerful tool, but it can be annoying to
work with thanks to everything being written in the rather picky JSON format.

When writing CFN files, you can validate the templates with:

    aws cloudformation validate-template --template-body file://filename.template


It can often be easier to debug why stacks failed to build with the AWS web
console due to better UI than reading JSON event output on the CLI.


