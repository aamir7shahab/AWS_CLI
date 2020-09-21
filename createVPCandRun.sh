# creating variables for VPC creation
AVAILABILITY_ZONE='ap-south-1a'
NAME='aws_Cli_VPC'
VPC_NAME='aws_Cli_VPC_tagName'
SUBNET_NAME='aws_Cli_subnet'
GATEWAY_NAME='aws_Cli_gateway'
ROUTE_TABLE_NAME='aws_Cli_routeTable'
SECURITY_GRP_NAME='aws_Cli_securityGrp'
VPC_CIDR_BLOCK='10.1.0.0/16'
SUBNET_CIDR_BLOCK='10.1.1.0/24'
PORT22_CIDR_BLOCK='0.0.0.0/0'
PORT80_CIDR_BLOCK='0.0.0.0/0'
DEST_CIDR_BLOCK='0.0.0.0/0'
UBUNTU_1804_AMI='ami-03f0fd1a2ba530e75'
INSTANCE_TYPE='t2.micro'
INSTANCE_NAME='aws-Cli-Inst'


echo "Creating VPC..."

# creating vpc and storing response
aws_response=$(aws ec2 create-vpc --cidr-block "$VPC_CIDR_BLOCK" --output json)
vpc_id=$(echo -e "$aws_response" | /usr/bin/jq '.Vpc.VpcId' | tr -d '"')
sleep 2

# tagging my vpc
aws ec2 create-tags --resources "$vpc_id" --tags Key=Name,Value="$VPC_NAME"
sleep 2

# enabling dns 
modified_response=$(aws ec2 modify-vpc-attribute --vpc-id "$vpc_id" --enable-dns-hostnames "{\"Value\":true}")
sleep 2

# add dns hostname
modified_response=$(aws ec2 modify-vpc-attribute --vpc-id "$vpc_id" --enable-dns-hostnames "{\"Value\":true}")
sleep 2

# create internet gateway
gateway_response=$(aws ec2 create-internet-gateway --output json)
gateway_id=$(echo -e "$gateway_response" | /usr/bin/jq '.InternetGateway.InternetGatewayId' | tr -d '"')
sleep 2

# naming internet gateway
aws ec2 create-tags --resources "$gateway_id" --tags Key=Name,Value="$GATEWAY_NAME"
sleep 2

# attach gateway to vpc
attach_reponse=$(aws ec2 attach-internet-gateway --internet-gateway-id "$gateway_id" --vpc-id "$vpc_id")
sleep 2

# create subnet for vpc
subnet_response=$(aws ec2 create-subnet --cidr-block "$SUBNET_CIDR_BLOCK" \
				 --availability-zone "$AVAILABILITY_ZONE" \
				 --vpc-id "$vpc_id" \
				 --output json )
subnet_id=$(echo -e "$subnet_response" | /usr/bin/jq '.Subnet.SubnetId' | tr -d '"')
sleep 2

# tag subnet
aws ec2 create-tags --resources "$subnet_id" --tags Key=Name,Value="$SUBNET_NAME"
sleep 2

# enable public ip on subnet
modified_response=$(aws ec2 modify-subnet-attribute --subnet-id "$subnet_id" --map-public-ip-on-launch)
sleep 2

# create security group
security_grp_response=$(aws ec2 create-security-group --group-name "$SECURITY_GRP_NAME" \
						--description "Private: $SECURITY_GRP_NAME" \
						--vpc-id "$vpc_id" \
						--output json)
group_id=$(echo -e "$security_grp_response" | /usr/bin/jq '.GroupId' | tr -d '"')
sleep 2

# name the security group
aws ec2 create-tags --resources "$group_id" --tags Key=Name,Value="$SECURITY_GRP_NAME"
sleep 2

# give access to port 22 and http 80
security_grp_response_2=$(aws ec2 authorize-security-group-ingress --group-id "$group_id" --protocol tcp --port 22 --cidr "$PORT22_CIDR_BLOCK")
security_grp_response_3=$(aws ec2 authorize-security-group-ingress --group-id "$group_id" --protocol tcp --port 80 --cidr "$PORT80_CIDR_BLOCK")
sleep 2

#create route table for vpc
route_table_response=$(aws ec2 create-route-table --vpc-id "$vpc_id" --output json)
routeTable_id=$(echo -e "$route_table_response" |  /usr/bin/jq '.RouteTable.RouteTableId' | tr -d '"')
sleep 2

# tag route table 
aws ec2 create-tags --resources "$routeTable_id" --tags Key=Name,Value="$ROUTE_TABLE_NAME"
sleep 2

# add route for internet gateway
route_response=$(aws ec2 create-route --route-table-id "$routeTable_id" --destination-cidr-block "$DEST_CIDR_BLOCK" --gateway-id "$gateway_id")
sleep 2

# add route to subnet
subnet_route_response=$(aws ec2 --associate-route-table --subnet-id "$subnet_id" --route-table-id "$routeTable_id")
sleep 2

echo " "
echo " VPC created:"

echo "Launching an EC2 Instance..."

# creating a key pair
# aws ec2 create-key-pair --key-name aws-cli-PrivateKey --query 'KeyMaterial' --output text > aws-cli-PrivateKey.pem

# settng permission to key-pair file
# chmod 400 aws-cli-PrivateKey.pem

# launch an ec2 Instance
launch_instance_response=$(aws ec2 run-instances --image-id "$UBUNTU_1804_AMI" \
					 --count 1 \
					 --instance-type "$INSTANCE_TYPE" \
					 --key-name AamirAWSKey \
					 --security-group-ids "$group_id" \
					 --subnet-id "$subnet_id" \
					 --output json \
					 --associate-public-ip-address)
sleep 2

instance_id=$(echo -e "$launch_instance_response" |  /usr/bin/jq '.Instances[].InstanceId' | tr -d '"')

# naming instance
aws ec2 create-tags --resources "$instance_id" --tags Key=Name,Value="$INSTANCE_NAME"

# wait for running of etc instance
sleep 150

description_response=$(aws ec2 describe-instances --instance-id "$instance_id")
instance_state=$(echo -e "$description_response" |  /usr/bin/jq '.Reservations[].Instances[].State.Name' | tr -d '"')
public_ip=$(echo -e "$description_response" |  /usr/bin/jq '.Reservations[].Instances[].PublicIpAddress' | tr -d '"')


echo "Instances State: $instance_state"
echo "Public IP: $public_ip"

# if [[ "$instance_state" == "running" ]]; then
# 	ssh ubuntu@"$public_ip" -i "AamirAWSKey.pem"
# elif [[ "$instance_state" != "running" ]]; then
# 	sleep 60;
# 	ssh ubuntu@"$public_ip" -i "AamirAWSKey.pem"
# fi
