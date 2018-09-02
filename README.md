# Demonstration of Typical Forensic Techniques in the AWS Cloud Step-by-Step
This demo is a step-by-step walthtrough of techniques that can be used to perform forensics on AWS Elastic Cloud Compute (EC2) Instances. We use various tools such as LiME, Magarita Shotgun, aws_ir, SIFT, Rekall, and Volitility during this demonstration lab.

## INTRODUCTION & CONTEXT
This lab makes use of four different EC2 instances, each has their own purpose. While the lab could be done with just two EC2 instances, I want the student to think in terms of the Incident Response Workflow (Preparation > Identification > Containment > Eradication, Recovery > Lessons Learned).

### Preparation
The Preparation Step is one of the most important.  It is this step that positions you for success. After all, in a security incident, time is of the essence. Therefore, it is important to understand your tools and make sure that they are in working order. Because it takes time to build the Incident Response Workstation and the SIFT Workstation, you will want to have these built in advance and saved as an AMI. This way, you can launch them as needed. Likewise, you will want to have the memory modules for all kernels present in your environment readily available.  The best way to do this is to make the memory module each time you authorize a new AMI to be run in your environment. (You aren't just launching random AMIs into production, are you?)

### Identification
In the Identification Step, you recognize that there may be a security incident in progress and start the process of scoping the incident.  For the purposes of our lab, this is when we will spin up the target EC2 instance and create some interesting artifacts to analyze.

### Containment
In the Containment Step, we will use our Incident Response Workstation to capture the memory of the target EC2 instance, and use the aws_ir command to make a snapshot of the EBS volume and put the EC2 instance in a Quarantine security group. We will also perform the forensic analysis in this step. The forensic analysis is generally used to help scope the incident, identify indicators of compromise (IOC) and determine root cause.

### Eradication
In the cloud, the Eradication Step consists of properly addressing the root cause and terminating all infected instances. Of course, you would not terminate all of the instances before collecting all necessary evidence. Eradication before Containment is a common problem: Someone in operations notices malware on an EC2 and then shutsdown or terminates the EC2 instance...and THEN lets the security team know. Of course by then the memory artifacts are lost and possibly the artifacts on disk too.

### Recovery
Recovery in the cloud should be fairly automated, assuming that you are using automation to deploy EC2 instances. Of course, this assumes that it was not your source code that was compromised. The Recovery Stage is about returning to the (new) normal state with mitigations in place.

### Lessons Learned
Never waste a crisis. Use the Lessons Learned Phase to drive your security agenda forward by taking advantage of teachable moments. Provide feedback on how to improve the preparation and response phases.

Ok, without further ado, let's have some fun!

## STEP 1 - Create the LiME Memory Module for the AMI
As noted above, this is a Preparation Phase activity that should be done once for each AMI used in your environment, at the time it is approved (or detected). This is because in order to do a memory capture using Margarita Shotgun, it is necessary to have an external LKM (memory module) that corresponds to the kernal that is in use by the EC2 instance that is to be imaged. Do that by launching a new EC2 instance with the same AMI of the system to be imaged. For example, you can use use ami-0ff8a91507f77f867 or whatever is the latest in the Marketplace. Next, SSH into it and run the following commands:

```
sudo yum update -y
sudo yum install -y git
sudo yum install -y kernel-devel-$(uname -r)
git clone https://github.com/504ensicsLabs/LiME.git
cd LiME/src
make
```

The result of the 'make' command will be a file with a 'ko' extension.  For example, `lime-4.14.62-65.117.amzn1.x86_64.ko
` would be created for ami-0ff8a91507f77f867.

Download this file for use with Margarita Shotgun.  After downloading the LKM, this EC2 instance can be terminated.  NOTE: You DO NOT want to run these commands on the same instance that is to be imaged because you want to have minimal impact of the target instance.

## STEP 2 - Prepare the Demo Incident Response Workstation
For this demonstration we will use a new Amazon Linux EC2 instance. Launch the instance and create an Instance Profile with full administrator access.  

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

REMINDER: The command to upload files via SCP to your home directory is:
```
scp -i <YOUR_SSH_KEY> <YOUR_FILE>  ec2-user@<YOUR_IP_ADDRESS>:~
```

NOTE: If you exit SSH, you will need to rerun `source env/bin/activate` or aws_ir will not execute

## STEP 3 - Prepare a Demonstration Target
For this step, simply launch another Amazon Linux t2.micro EC2 instance and in Step 3 of the Launch wizard, expand the "Advanced Details" part of the form and paste in the following code in the User Data field:

```
#!/bin/bash
wget -q https://raw.githubusercontent.com/Resistor52/cloud_dfir_demo/master/DONT_PEEK_HERE/dont_peek.sh
bash dont_peek.sh
rm dont_peek.sh
```
Be sure that you use the same SSH Key that was uploaded to the Incident Response Workstation.  Note that the Security Group for this EC2 instance must be configured to allow SSH connectivity from the IR Workstation so that Margarita Shotgun can connect to it.  

## STEP 4 - Collect Evidence from Demonstration Target
Now for the fun part.  Copy the following code to a notepad and alter the parameters as appropriate and then paste the code into the command line while connected via SSH to the Incident Response Workstation:

```
## Set Parameters as appropriate
TARGET_IP=<YOUR_IP_ADDRESS>                  # Update this with your target's IPv4 Address
SSH_KEY=<YOUR_SSH_KEY.pem>
SSH_USER=ec2-user                            # for Amazon Linux, SSH_USER=ubuntu for Ubuntu
MODULE=lime-4.14.62-65.117.amzn1.x86_64.ko   # amzn-ami-hvm-2018.03.0.2018Amazon Linux AMI 2018.03.0 (ami-0ff8a91507f77f867)

## Make the magic happen
MY_IP=$(curl -s icanhazip.com)
margaritashotgun --server $TARGET_IP --username $SSH_USER --key $SSH_KEY --module $MODULE --filename $TARGET_IP-mem.lime
aws_ir --examiner-cidr-range $MY_IP/32 instance-compromise --target $TARGET_IP --user $SSH_USER --ssh-key $SSH_KEY
```

Note that we are calling Margarita Shotgun prior to AWS_IR because although AWS_IR will call Margarita Shotgun, in the present form AWS_IR cannot accept a parameter on the command line to tell Margarita Shotgun which memory module to use.  Instead AWS_IR assumes that the kernel module is in its repository.  The bad news is that recent kernels are not.  Therefore, the simple workaround is to call Margarita Shotgun first.  (Future versions of this demo will show how to set up a custom kernel module repository.)

TROUBLESHOOTING: Did you get an "Unable to locate credentials" error? That may indicate that you forgot to attach the instance profile in Step 2

## STEP 5 - Analyze the Data using Rekall and Volitility
(Coming Soon)
