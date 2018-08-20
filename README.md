# cloud_dfir_demo
Demonstration of ThreatResponse aws_ir Step by Step

NOTE: This is just a first draft, check back soon for improvements

## STEP 1 - Create the LiME Memory Module for the AMI
In order to do a memory capture using Margarita Shotgun, it is necessary to have an external LKM (memory module) that corresponds to the kernal that is in use by the EC2 instance that is to be imaged. Do that by launching a new EC2 instance (use ami-cfe4b2b0) with the same AMI of the system to be imaged. Next, SSH into it and run the following commands:

```
sudo yum update
sudo yum install -y git
sudo yum install kernel-devel-$(uname -r)
git clone https://github.com/504ensicsLabs/LiME.git
cd LiME/src
make
```

The result of the 'make' command will be a file with a 'ko' extension.  For example `lime-4.14.47-56.37.amzn1.x86_64.ko`

Download this file for use with Margarita Shotgun.  After downloading the LKM, this EC2 instance can be terminated

## STEP 2 - Prepare the Demo Incident Response Workstation
For this demonstration we will use a new Amazon Linux EC2 instance.  (Use ami-cfe4b2b0.) Launch the instance and create an Instance Profile with full administrator access.  

NOTES: 
* This demo will be updated to use an instance profile with least privileges in the future.  
* To learn more about instance profules for EC2 instances, see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html
* Using an instance profile is much more secure than installing AWS Access Keys on the EC2 instance

Next, SSH into it and run the following commands:
```
sudo yum update -y
sudo yum install -y python34
pip install virtualenv
virtualenv -p python3.4 env
source env/bin/activate
pip install aws_ir
```

Next, upload the kernel module to the Incident Response Workstation that was created in STEP 1.  Also load the SSH Key that can be used to access the target workstation.  For purposes of this demo, it is assumed that the kernel module and SSH key are all in the home directory (/home/ec2-user).

## STEP 3 - Prepare a Demonstration Target
For this step, simply launch another Amazon Linux (use ami-cfe4b2b0) but be sure that you use the same SSH Key that was uploaded to the Incident Response Workstation.  Note that the Security Group must be configured to allow SSH connectivity from the IR Workstation.  If desired, run some stuff to make the memory contain something interesting.  (I will provide some ideas in the next iteration of this demo.)

## STEP 4 - Collect Evidence from Demonstration Target
Now for the fun part.  Copy the following code to a notepad and alter the parameters as appropriate and then paste the code into the command line while connected via SSH to the Incident Response Workstation:

```
## Set Parameters as appropriate
TARGET_IP=54.152.47.17
SSH_KEY=YOURKEY.pem

## Leave as is for Amazon Linix ami-cfe4b2b0
#SSH_USER=ubuntu                           # Ubuntu 
#MODULE=lime-4.4.0-1061-aws.ko             # ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-20180627 (ami-759bc50a)
SSH_USER=ec2-user                          # Amazon Linux
MODULE=lime-4.14.47-56.37.amzn1.x86_64.ko  # amzn-ami-hvm-2018.03.0.20180622-x86_64-gp2 (ami-cfe4b2b0)

## Make the magic happen
MY_IP=$(curl -s icanhazip.com)
margaritashotgun --server $TARGET_IP --username $SSH_USER --key $SSH_KEY --module $MODULE --filename $TARGET_IP-mem.lime
aws_ir --examiner-cidr-range $MY_IP/32 instance-compromise --target $TARGET_IP --user $SSH_USER --ssh-key $SSH_KEY
```

Note that we are calling Margarita Shotgun prior to AWS_IR because although AWS_IR will call Margarita Shotgun, in the present form AWS_IR cannot accept a parameter on the command line to tell Margarita Shotgun which memory module to use.  Instead AWS_IR assumes that the kernel module is in its repository.  The bad news is that recent kernels are not.  Therefore, the simple workaround is to call Margarita Shotgun first.  (Future versions of this demo will show how to set up a custom kernel module repository.) 

## STEP 5 - Analyze the Data using Rekall and Volitility
(Coming Soon)
