## Objective 

Write terraform code to create EC2 intances in an auto scaling group in a subnet and attach those instances to a load balancer and create a Route53 record in a hosted zone for this load balancer.


### PRE-REQUISITE
1) Need AWS account.
2) Terraform
3) AWS credential keys.

Ref: 
https://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/setup-credentials.html
https://learn.hashicorp.com/tutorials/terraform/aws-build

   
   
- Init

```bash
$ terraform init   
```

- Plan

```                                 
$ terraform plan 

```


- Apply
```bash
$ terraform apply
.
Apply complete! Resources: 16 added, 0 changed, 0 destroyed.

Outputs:

elb_dns_name = "web-elb-2134110165.us-east-1.elb.amazonaws.com"
r53-entry-record = "server1.anjoshi-test.com"
r53-hosted-zone-dns-servers = tolist([
  "ns-1247.awsdns-27.org",
  "ns-2042.awsdns-63.co.uk",
  "ns-409.awsdns-51.com",
  "ns-939.awsdns-53.net",
])
```
