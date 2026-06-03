# v1 -> v2 state migration. Only the Route53 alias records can be carried
# over; the LBs, target groups, and node ASG are replaced or destroyed.

moved {
  from = module.proxy_servers.aws_route53_record.proxy[0]
  to   = module.teleport_nlb.aws_route53_record.proxy[0]
}

moved {
  from = module.proxy_servers.aws_route53_record.proxy_wildcard[0]
  to   = module.teleport_nlb.aws_route53_record.proxy_wildcard[0]
}
