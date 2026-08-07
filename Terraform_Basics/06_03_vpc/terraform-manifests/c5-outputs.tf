# vpc_id
output "vpc_id" {
    value = aws_vpc.main.id
    description = "VPC ID"
}

# public subnet id
output "public_subnet_ids" {
    value = [for subnet in aws_subnet.public : subnet.id]
    description = "List of public subnet IDs"
}

# private subnet id
output "private_subnet_ids" {
    value = [for subnet in aws_subnet.private : subnet.id]
    description = "List of private subnet IDs"
}

# public subnet map
output "public_subnet_map" {
    value = {for az, subnet in aws_subnet.public : az => subnet.id}
    description = "Map of public subnets with availability zone as key and subnet ID as value"
}

