# cambrium_challange
Create a Provider for AWS.
Create a VPC (Virtual Private Cloud in AWS).
Create a Public Subnet with auto public IP Assignment enabled in custom VPC.
Create a Private Subnet in customer VPC.
Create an Internet Gateway for Instances in the public subnet to access the Internet.
Create a routing table consisting of the information of Internet Gateway.
Associate the routing table to the Public Subnet to provide the Internet Gateway address.
Creating an Elastic IP for the NAT Gateway.
Creating a NAT Gateway for the internet in private subnet
Creating a route table for the Nat Gateway Access which has to be associated private subnet.
Created ec2 instance with websever have the open to world security group
Finally load balancer to traffic which can users can access webserver
