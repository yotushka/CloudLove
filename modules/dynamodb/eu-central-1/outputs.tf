output "dynamp_db_arn" {
  value = aws_dynamodb_table.this.arn
}

output "dynamp_db_name" {
  value = aws_dynamodb_table.this.name
}

output "dynamp_db_hash_key" {
  value = aws_dynamodb_table.this.hash_key
}