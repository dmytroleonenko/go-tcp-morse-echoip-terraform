# multiregion-terraform for https://github.com/dmytroleonenko/go-tcp-morse-echoip-terraform
Multi-region AWS Terraform application

**TL;DR**: launch 14 AWS NLBs with CPU autoscaled instances in up to 14 regions with a single `terraform` command

Amazon has 14 data centers with 40 availability zones spread around the world (excluding China and GovCloud). This Terraform recipe can launches EC2 instances in every possible zone, and ties them together using AWS NLB into a single domain name that routes traffic to the closest application server based on client location

## Features

* Single `main.tf` with a module instance for each Amazon's [14 regions][1]
* Creates an EC2 instance in every region and availability zone using autoscaling groups (if required)
* Creates two Route 53 records (CNAME) with [latency based routing][2] to all NLBs
* All NLBs allow ICMP Echo Request (ping) from `0.0.0.0/0`

## How-to

Notes:

* create a route53 zone and set primary DNS servers to point to route53
* **IMPORTANT**: edit [cdn/variables.tf](cdn/variables.tf) and set `r53_zone_name`, `r53_domain_name` and all other variables
* requires Terraform >= v0.10.8 + patched aws provider. AWS NLB is still to be improved in Terraform
* requires golang 1.9+
* override the Amazon credential [profile settings][3] by setting `AWS_PROFILE=blah`
* comment out regions in [main.tf](main.tf) to test a smaller deployment

### patching aws terraform provider

```
$ mkdir -p $GOPATH/src/github.com/terraform-providers; cd $GOPATH/src/github.com/terraform-providers
$ git clone --branch v1.2.0 https://github.com/terraform-providers/terraform-provider-aws.git
$ cd terraform-provider-aws
$ patch -p1 </path/to/nlb.patch
$ make build
```
Then from a current repository dir execute

```
$ terraform init
$ terraform get
...

$ cp $GOPATH/bin/terraform-provider-aws $(find . -type f -name "terraform-provider-aws_*" | head -n1)

# replace 'personal' with the name of your AWS profile in ~/.aws/crendentials or leave blank for 'default'
$ TF_SKIP_PROVIDER_VERIFY=1 AWS_PROFILE=personal terraform plan
data.aws_ami.coreos: Refreshing state...
data.aws_availability_zones.available: Refreshing state...
...
Plan: XX to add, 0 to change, 0 to destroy.

$ TF_SKIP_PROVIDER_VERIFY=1 AWS_PROFILE=personal terraform apply
data.aws_ami.coreos: Refreshing state...
data.aws_availability_zones.available: Refreshing state...
...
Apply complete! Resources: XX added, 0 changed, 0 destroyed.
```

## Potential improvements
* Route53 healthcheck to exclude unhealthy region (no instances can serve the traffic in a regiono)
* CoreOS clustering for better upgrade strategies
* Better container deployment mechanism

## Credits
Based on https://github.com/kung-foo/multiregion-terraform initially

[1]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-available-regions
[2]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html#routing-policy-latency
[3]: https://www.terraform.io/docs/providers/aws/#shared-credentials-file
