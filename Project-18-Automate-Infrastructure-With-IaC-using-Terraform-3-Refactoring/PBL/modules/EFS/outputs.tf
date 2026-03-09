output "efs_id" {
  value = aws_efs_file_system.ACS-efs.id
}

output "efs_dns" {
  value = aws_efs_file_system.ACS-efs.dns_name
}