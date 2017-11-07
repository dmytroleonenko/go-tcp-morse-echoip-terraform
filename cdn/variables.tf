variable "region" {}

variable "min_servers_per_region" {
  default = 1
}

variable "max_servers_per_region" {
  default = 2
}

variable "instance_type" {
  default = "t2.nano"
}

variable "r53_zone_name" {
  default = "echoip.ml"
}

# Will be prepended to the name associated r53_zone_name
variable "r53_domain_name" {
  default = "cdn"
}

# VPC cidr block
variable "cidr_block" {
  default = "10.233.0.0/16"
}

# tcp port for NLB to accept connections on
variable "echoip_tcp_port" {
  default = "9999"
}

variable "openssh_pub_key" {
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDBUMAvu9adRbOs6trSB7Bcxde9zOh/NWsVAz7lyHZ8Tu5HWy38LaLNomO0Asu5TromerG20lG4tGg5z1UPfWvK0m0a6e7PvL9x3C0jaRbhdMkXtWnNO8QTBrS+BGd361V3VgUENRR5P6UJW9zmvZOxQFQgfjNOvHrQ3U+BYyyyTsVKzKo0pp1hBp1MC33O3pTgVXRWOGgCnqD26DcfA7PTk9dfUOpbW9ju1Suy8cEPoWTWZMFaGnVe2kPS9eqRVSo0ofj+QLZ/irGiM6UVk1Hb+JvPtrNr2c4Z9O+4RrPTPOKn0JMbiKIOUzTb1Lk9EbyYbVmEhMwECAlqTSI1ZLyt cardno:000603036759"
}
