# CloudFormation Template to Debug Possible Network ELB and SSL Issue

This CloudFormation template was put together to debug a strange issue. Unsure exactly why it happens yet, but it seems to occur under these conditions:

1. Network ELB
2. SSL Used
3. Request coming from certain locations. India, Australia, South Africa have reproduced the issue though not consistently with everyone?

This template launches a test instance and a network ELB and wires them together. It configures the ELB with 2 Listeners, one for port 80 and another for port 443.

The port 443 will use the ACM cert that is passed in as a CloudFormation parameter: `CertArn`.

Parameters for route53 resources like: `DnsName` and `HostedZoneName` are expected to also be passed in so that we can test an SSL endpoint.

The user-data script of the instance installs `httpd` and sets up static index.html and test.html pages for testing.

## Route53 Hosted Zone

The route53 hosted zone must already exist. To created it you can use the Route53 console or the CLI. CLI Example:

    aws route53 create-hosted-zone --name mydomain.com --caller-reference $(date +%s)

## Template Summary

    Required Parameters:
      Subnets (String)
      VpcId (String)
      CertArn (String)
      DnsName (String)
      HostedZoneName (String)
    Optional Parameters:
      InstanceType (String) Default: t3.micro
      KeyName (String) Default:
    Resources:
      2 AWS::ElasticLoadBalancingV2::Listener
      1 AWS::EC2::Instance
      1 AWS::EC2::SecurityGroup
      1 AWS::ElasticLoadBalancingV2::LoadBalancer
      1 AWS::ElasticLoadBalancingV2::TargetGroup
      1 AWS::Route53::RecordSet
      6 Total

## Parameters

Name | Description
--- | ---
Subnets | Comma separated list of subnet ids mainly used for the ELB. A minimum of 2 are required. IE: subnet-1,subnet-2
VpcId | Vpc Id the resources will be provisioned in. Here's a command to grab the default vpc if you want to use it: `aws ec2 describe-vpcs | jq -r '.Vpcs[] | select(.IsDefault == true) | .VpcId'`
CertArn | The ARN of the ACM cert. Here's a useful command: `aws acm list-certificates`
DnsName | The dns name of the final endpoint you want. Important: include the trailing period. IE: demo.example.com.
HostedZoneName | The hosted zone name. Important: include the trailing period. IE: example.com.
KeyName | Though the key name is optional, it is may be useful to set if you want to ssh into the instance to debug it.

## Launch Stack

The template is at [output/demo/templates/demo.yml](output/demo/templates/demo.yml). Here are example commands to launch the stack. Please substitute the params.json with your own values.

First, create a `params.json` file

    cat > params.json <<EOL
    [
      {
        "ParameterKey": "Subnets",
        "ParameterValue": "subnet-example1,subnet-example2"
      },
      {
        "ParameterKey": "VpcId",
        "ParameterValue": "vpc-default-example"
      },
      {
        "ParameterKey": "KeyName",
        "ParameterValue": "default-example"
      },
      {
        "ParameterKey": "CertArn",
        "ParameterValue": "arn:aws:acm:us-west-2:112233445566:certificate/8d8919ce-a710-4050-976b-b33EXAMPLE"
      },
      {
        "ParameterKey": "DnsName",
        "ParameterValue": "demo.example.com."
      },
      {
        "ParameterKey": "HostedZoneName",
        "ParameterValue": "example.com."
      }
    ]
    EOL

Now launch the stack:

    cloudformation create-stack --stack-name demo --parameters file://params.json  --template-body file://output/demo/templates/demo.yml

This will provision the resources:

* Single test ec2 instance
* Network ELB with SSL
* The ELB is connected to the ec2 instance

## Reproduction of Issue

This issue is tricky because it is only reproducible in some locations. You can use VPN software to log into another geographical location. From there when you curl the ssl endpoint, you'll get an empty response.

    $ curl https://demo.example.com/test.html
    curl: (52) Empty reply from server
    $

Using `curl --verbose`, shows the SSL handshake works fine. So, don't believe it's the SSL handshake.

Here's a clue though.  When capturing the tcpdump data on the ec2 instance, we can see the both http and https requests coming in.

But the https request takes a very long time before it eventually gets to the server. Maybe 30-40+ seconds. And then the server never reproduces a response.
