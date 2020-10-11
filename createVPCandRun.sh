# creating global variables for VPC creation
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

# VPC creating message
echo "Creating VPC..."

# creating vpc and storing response
awsResponse=$(aws ec2 create-vpc \
	      --cidr-block "$VPC_CIDR_BLOCK" \
	      --output json)
vpc_id=$(echo -e "$awsResponse" | \
	 /usr/bin/jq '.Vpc.VpcId' | \
	 tr -d '"')
sleep 2

# tagging vpc
aws ec2 create-tags \
	--resources "$vpc_id" \
	--tags Key=Name,Value="$VPC_NAME"
sleep 2

# enabling dns 
modifiedResponse=$(aws ec2 modify-vpc-attribute \
		   --vpc-id "$vpc_id" \
		   --enable-dns-hostnames "{\"Value\":true}")
sleep 2

# add dns hostname
modifiedResponse=$(aws ec2 modify-vpc-attribute \
		   --vpc-id "$vpc_id" \
		   --enable-dns-hostnames "{\"Value\":true}")
sleep 2

# create internet gateway
gatewayResponse=$(aws ec2 create-internet-gateway \
		  --output json)
gatewayId=$(echo -e "$gatewayResponse" | \
	    /usr/bin/jq '.InternetGateway.InternetGatewayId' | \
			tr -d '"')
sleep 2

# naming internet gateway
aws ec2 create-tags \
	--resources "$gatewayId" \
	--tags Key=Name,Value="$GATEWAY_NAME"
sleep 2

# attach gateway to vpc
attachReponse=$(aws ec2 attach-internet-gateway \
		--internet-gateway-id "$gatewayId" \
		--vpc-id "$vpc_id")
sleep 2

# create subnet for vpc
subnetResponse=$(aws ec2 create-subnet \
		 --cidr-block "$SUBNET_CIDR_BLOCK" \
		 --availability-zone "$AVAILABILITY_ZONE" \
		 --vpc-id "$vpc_id" \
		 --output json )

# getting subnet id
subnetId=$(echo -e "$subnetResponse" | \
	   /usr/bin/jq '.Subnet.SubnetId' | \
	    tr -d '"')
sleep 2

# tag subnet
aws ec2 create-tags \
	--resources "$subnetId" \
	--tags Key=Name,Value="$SUBNET_NAME"
sleep 2

# enable public ip on subnet
modifiedResponse=$(aws ec2 modify-subnet-attribute \
		   --subnet-id "$subnetId" \
		   --map-public-ip-on-launch)
sleep 2

# create security group
securityGrpResponse=$(aws ec2 create-security-group \
		      --group-name "$SECURITY_GRP_NAME" \
		      --description "Private: $SECURITY_GRP_NAME" \
		      --vpc-id "$vpc_id" \
		      --output json)
groupId=$(echo -e "$securityGrpResponse" | \
	  /usr/bin/jq '.GroupId' | \
	  tr -d '"')
sleep 2

# name the security group
aws ec2 create-tags \
	--resources "$groupId" \
	--tags Key=Name,Value="$SECURITY_GRP_NAME"
sleep 2

# give access to port 22 and http 80
securityGrpResponse_2=$(aws ec2 authorize-security-group-ingress \
			--group-id "$groupId" \
			--protocol tcp \
			--port 22 \
			--cidr "$PORT22_CIDR_BLOCK")
securityGrpResponse_3=$(aws ec2 authorize-security-group-ingress \
			--group-id "$groupId" \
			--protocol tcp \
			--port 80 \
			--cidr "$PORT80_CIDR_BLOCK")
sleep 2

#create route table for vpc
routeTableResponse=$(aws ec2 create-route-table \
		     --vpc-id "$vpc_id" \
		     --output json)
routeTableId=$(echo -e "$routeTableResponse" | \
	       /usr/bin/jq '.RouteTable.RouteTableId' | \
	       tr -d '"')
sleep 2

# tag route table 
aws ec2 create-tags \
	--resources "$routeTableId" \
	--tags Key=Name,Value="$ROUTE_TABLE_NAME"
sleep 2

# add route for internet gateway
routeResponse=$(aws ec2 create-route \
		--route-table-id "$routeTableId" \
		--destination-cidr-block "$DEST_CIDR_BLOCK" \
		--gateway-id "$gatewayId")
sleep 2

# add route to subnet
subnetRouteResponse=$(aws ec2 --associate-route-table \
		      --subnet-id "$subnetId" \
		      --route-table-id "$routeTableId")
sleep 2

# printing launch message
echo " "
echo " VPC created:"
echo "Launching an EC2 Instance..."

# launch an ec2 Instance
launchInstanceResponse=$(aws ec2 run-instances \
			 --image-id "$UBUNTU_1804_AMI" \
			 --count 1 \
			 --instance-type "$INSTANCE_TYPE" \
			 --key-name AamirAWSKey \
			 --security-group-ids "$groupId" \
			 --subnet-id "$subnetId" \
			 --output json \
			 --associate-public-ip-address)
sleep 2

# getting instance id
instanceId=$(echo -e "$launchInstanceResponse" | \
	     /usr/bin/jq '.Instances[].InstanceId' | \
	     tr -d '"')

# naming instance
aws ec2 create-tags \
	--resources "$instanceId" \
	--tags Key=Name,Value="$INSTANCE_NAME"
sleep 50

# wait for running of etc instance
descriptionResponse=$(aws ec2 describe-instances \
		      --instance-id "$instanceId")
instanceState=$(echo -e "$descriptionResponse" | \
		/usr/bin/jq '.Reservations[].Instances[].State.Name' | \
		tr -d '"')

# checking instance state every 5 sec
while [[ "$instanceState" != "running" ]]; do
	sleep 5
	descriptionResponse=$(aws ec2 describe-instances \
			      --instance-id "$instanceId")
	instanceState=$(echo -e "$descriptionResponse" | \
			/usr/bin/jq '.Reservations[].Instances[].State.Name' | \
			tr -d '"')
done

# getting public ip
publicIp=$(echo -e "$descriptionResponse" | \
	   /usr/bin/jq '.Reservations[].Instances[].PublicIpAddress' | \
	   tr -d '"')

# printing status and public ip to connect
echo "Instances State: $instanceState"
echo "Public IP: $publicIp"
