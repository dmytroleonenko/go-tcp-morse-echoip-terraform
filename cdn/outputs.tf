output "nlbs" {
  value = ["${aws_lb.echoip-lb.*.public_ip}"]
}
