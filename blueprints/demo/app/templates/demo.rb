# Simple Starter Demo Example
aws_template_format_version "2010-09-09"
description "Demo stack"

parameter(:instance_type, "t3.micro")
parameter(:key_name, "")
parameter(:subnets)
parameter(:vpc_id)
parameter(:cert_arn)
parameter(:dns_name)
parameter(:hosted_zone_name)

condition(:has_key_name, fn::not(equals(ref(:key_name),'')))

mapping(:ami_map,
  "ap-northeast-1": { ami: "ami-0f9ae750e8274075b" },
  "ap-northeast-2": { ami: "ami-047f7b46bd6dd5d84" },
  "ap-south-1":     { ami: "ami-0889b8a448de4fc44" },
  "ap-southeast-1": { ami: "ami-0b419c3a4b01d1859" },
  "ap-southeast-2": { ami: "ami-04481c741a0311bbb" },
  "ca-central-1":   { ami: "ami-03338e1f67dae0168" },
  "eu-central-1":   { ami: "ami-09def150731bdbcc2" },
  "eu-north-1":     { ami: "ami-d16fe6af" },
  "eu-west-1":      { ami: "ami-07683a44e80cd32c5" },
  "eu-west-2":      { ami: "ami-09ead922c1dad67e4" },
  "eu-west-3":      { ami: "ami-0451ae4fd8dd178f7" },
  "sa-east-1":      { ami: "ami-0669a96e355eac82f" },
  "us-east-1":      { ami: "ami-0de53d8956e8dcf80" },
  "us-east-2":      { ami: "ami-02bcbb802e03574ba" },
  "us-west-1":      { ami: "ami-0019ef04ac50be30f" },
  "us-west-2":      { ami: "ami-061392db613a6357b" }
)

resource(:instance, "AWS::EC2::Instance",
  instance_type: ref(:instance_type),
  image_id: find_in_map(:ami_map, ref("AWS::Region"), :ami),
  security_group_ids: [get_att("instance_security_group.group_id")],
  subnet_id: select("0", split(",", ref(:subnets))),
  user_data: base64(user_data("bootstrap.sh")),
  key_name: fn::if(:has_key_name, ref(:key_name), ref("AWS::NoValue")),
  tags: tags(Name: "demo")
)
resource(:instance_security_group, "AWS::EC2::SecurityGroup",
  group_description: "instance security group",
  security_group_ingress: [{
    ip_protocol: "tcp",
    from_port: 22,
    to_port: 22,
    cidr_ip: "0.0.0.0/0",
  },{
    ip_protocol: "tcp",
    from_port: 80,
    to_port: 80,
    cidr_ip: "0.0.0.0/0",
  },{
    ip_protocol: "tcp",
    from_port: 443,
    to_port: 443,
    cidr_ip: "0.0.0.0/0",
  }],
)

resource(:elb,
  type: "AWS::ElasticLoadBalancingV2::LoadBalancer",
  depends_on: "instance".camelize,
  properties: {
    type: "network",
    subnets: split(",",ref(:subnets))
    # subnet_mappings: subnet_mappings
  }
)
resource(:elb_target_group, "AWS::ElasticLoadBalancingV2::TargetGroup",
  protocol: "TCP",
  port: 80,
  vpc_id: ref(:vpc_id),
  targets: [
    id: ref(:instance),
    port: 80
  ],
)

resource(:elb_listener, "AWS::ElasticLoadBalancingV2::Listener",
  load_balancer_arn: ref(:elb),
  default_actions: [
    type: "forward",
    target_group_arn: ref(:elb_target_group)
  ],
  protocol: "TCP",
  port: 80,
)
resource(:elb_listener_ssl, "AWS::ElasticLoadBalancingV2::Listener",
  load_balancer_arn: ref(:elb),
  certificates: [
    certificate_arn: ref(:cert_arn),
  ],
  default_actions: [
    type: "forward",
    target_group_arn: ref(:elb_target_group)
  ],
  protocol: "TLS",
  port: 443,
)

resource(:domain, "AWS::Route53::RecordSet",
  type: "CNAME",
  ttl: "60",
  name: ref(:dns_name), # dont forget the trailing period
  hosted_zone_name: ref(:hosted_zone_name),
  resource_records: [ get_att("Elb.DNSName", autoformat: false) ],
)

output(:instance)
output(:instance_ip, get_att("instance.public_ip"))
output(:elb, get_att("Elb.DNSName", autoformat: false))
output(:domain, ref(:domain))
