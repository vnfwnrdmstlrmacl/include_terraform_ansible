# modules/tailscale_bridge/outputs.tf

output "private_ip" {
  description = "Tailscale Bridge EC2의 사설 IP"
  # grep 결과에 따라 .bridge 로 수정했습니다.
  value       = aws_instance.bridge.private_ip
}

output "public_ip" {
  description = "Tailscale Bridge EC2의 공인 IP"
  value       = aws_instance.bridge.public_ip
}

output "instance_id" {
  description = "Tailscale Bridge EC2의 인스턴스 ID"
  value       = aws_instance.bridge.id
}
