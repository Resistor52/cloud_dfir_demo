------------------------------------------------------------
#       NOTE: This is Deprecated 
#       See https://forensicate.cloud
-------------------------------------------------------------













# Step by Step Demonstration of Typical Forensic Techniques for AWS EC2 Instances
This demo is a step-by-step walthtrough of techniques that can be used to perform forensics on AWS Elastic Cloud Compute (EC2) Instances. We use various tools such as [LiME](https://github.com/504ensicsLabs/LiME), [Magarita Shotgun](https://github.com/ThreatResponse/margaritashotgun), [aws_ir](https://github.com/ThreatResponse/aws_ir), [SIFT](https://digital-forensics.sans.org/community/downloads), [Rekall](https://github.com/google/rekall), and [Volatility](https://github.com/volatilityfoundation/volatility) during this demonstration lab.

## INTRODUCTION & CONTEXT
This lab makes use of four different EC2 instances, each has their own purpose. While the lab could be done with just two EC2 instances, I want the student to think in terms of the Incident Response Workflow (Preparation > Identification > Containment > Eradication, Recovery > Lessons Learned).

### Preparation
The Preparation Step is one of the most important.  It is this step that positions you for success. After all, in a security incident, time is of the essence. Therefore, it is important to understand your tools and make sure that they are in working order. Because it takes time to build the Incident Response Workstation and the SIFT Workstation, you will want to have these built in advance and saved as an AMI. This way, you can launch them as needed. Likewise, you will want to have the memory modules for all kernels present in your environment readily available.  The best way to do this is to make the memory module each time you authorize a new AMI to be run in your environment. (You aren't just launching random AMIs into production, are you?)

### Identification
In the Identification Step, you recognize that there may be a security incident in progress and start the process of scoping the incident.  For the purposes of our lab, this is when we will spin up the target EC2 instance and create some interesting artifacts to analyze.

### Containment
In the Containment Step, we will use our Incident Response Workstation to capture the memory of the target EC2 instance, and use the aws_ir command to make a snapshot of the EBS volume and put the EC2 instance in a Quarantine security group. We will also perform the forensic analysis in this step. The forensic analysis is generally used to help scope the incident, identify indicators of compromise (IOC) and determine root cause.

### Eradication
In the cloud, the Eradication Step consists of properly addressing the root cause and terminating all infected instances. Of course, you would not terminate all of the instances before collecting all necessary evidence. Eradication before Containment is a common problem: Someone in operations notices malware on an EC2 and then shuts down or terminates the EC2 instance...and THEN lets the security team know. Of course by then, the memory artifacts are lost and possibly the artifacts on disk too.

### Recovery
Recovery in the cloud should be fairly automated, assuming that you are using automation to deploy EC2 instances. Of course, this assumes that it was not your source code that was compromised. The Recovery Stage is about returning to the (new) normal state with mitigations in place.

### Lessons Learned
Never waste a crisis. Use the Lessons Learned Phase to drive your security agenda forward by taking advantage of teachable moments. Provide feedback on how to improve the preparation and response phases.

Ok, without further ado, let's have some fun!

## STEP 1 - Create the LiME Memory Module for the AMI
As noted above, this is a Preparation Phase activity that should be done once for each AMI used in your environment, at the time it is approved (or detected). This is because in order to do a memory capture using Margarita Shotgun, it is necessary to have an external LKM (linux kernel memory) module that corresponds to the kernel that is in use by the EC2 instance that is to be imaged. Do that by launching a new EC2 instance with the same AMI of the system to be imaged. For example, you can use ami-0ff8a91507f77f867 or whatever is the latest in the Marketplace. Next, SSH into it and run the following commands:

```
sudo yum update -y
sudo yum install -y git
sudo yum install -y kernel-devel-$(uname -r)

git clone https://github.com/504ensicsLabs/LiME.git
cd LiME/src
make
cp *.ko ~
```

The result of the 'make' command will be a file with a 'ko' extension.  For example, `lime-4.14.62-65.117.amzn1.x86_64.ko` would be created for ami-0ff8a91507f77f867.

Stay logged into this EC2 Instance for the next step.  The LKM, Volatility Profile, and Rekall Profile must all match the target system and that is why we are using a matching AMI.

## STEP 2 - Prepare the Volatility and Rekall Profiles
The following instructions in this step are adapted from the following references:
* [Linux Memory Forensics Wiki](https://code.google.com/archive/p/volatility/wikis/LinuxMemoryForensics.wiki)
* [rekall / tools / linux / README](https://github.com/google/rekall/tree/master/tools/linux)
* [Creating Volatility Linux Profiles (Debian/Ubuntu)](https://www.evild3ad.com/3571/creating-volatility-linux-profiles-debianubuntu/)

Volatility uses the profile to locate critical information in the memory structure dumped by LiME. A Volatility Profile is a zip file with specific information pertaining to the specific target's kernel.
```
sudo yum install -y libdwarf-tools
git clone https://github.com/volatilityfoundation/volatility.git
sudo chown -R ec2-user ~/volatility/tools/linux
cd ~/volatility/tools/linux/                  # We will use the Volatility tools
make                                          # This makes the module.dwarf file
sudo zip "/home/ec2-user/`uname -r`.zip" module.dwarf /boot/System.map-`uname -r`
cd ~
ls *.zip
```
sudo is required to read the /boot directory.

```
cd ~
git clone https://github.com/google/rekall.git
cd ~/rekall/tools/linux
rm -f Makefile #Replace the Makefile
wget https://raw.githubusercontent.com/Resistor52/cloud_dfir_demo/master/Makefile
sudo make profile
cp module.ko module_dwarf.ko
zip "~/rekall-`uname -r`.zip" module_dwarf.ko /boot/System.map-`uname -r`
cd ~
```

Download these two zip files for use on the SIFT Workstation and the LKM file for use with Margarita Shotgun.  After downloading the files, this EC2 instance can be terminated.  In Step 8, we will use Rekall on the SIFT Workstation to convert the Volatility Profile to a Rekall Profile.  

NOTE: You DO NOT want to run these commands on the same instance that is to be imaged because you want to have minimal impact of the target instance.

## STEP 3 - Prepare the Demo Incident Response Workstation
For this demonstration we will use a new Amazon Linux EC2 instance. Launch the instance and attach an Instance Profile named "EC2_Responder".  The EC2_Responder role should have the following two policies attached:
* AmazonEC2FullAccess
* AmazonS3FullAccess   

Tag this EC2 Instance with the "Name" set to "IR Workstation"

NOTES:
* To learn more about instance profiles for EC2 instances, see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html.
* Using an instance profile is much more secure than installing AWS Access Keys on the EC2 instance.

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

## STEP 4 - Prepare the SIFT workstation
Launch an "Ubuntu Server 16.04 LTS (HVM)" **t2.large** instance with at least 40 GB of primary disk space. In Step 3 of the Launch wizard, expand the "Advanced Details" part of the form and paste in the following code:
```
#!/bin/bash
logfile=/tmp/setup.log
echo "START" > logfile
exec > $logfile 2>&1  # Log stdout and stderr to logfile in /tmp
TIMESTAMP=$(date)
echo; echo "== Install Updates"
apt -y update
apt -y upgrade
echo; echo "== Setup SIFT Workstation"
cd /tmp
wget -q https://github.com/sans-dfir/sift-cli/releases/download/v1.7.1/sift-cli-linux.sha256.asc
wget -q https://github.com/sans-dfir/sift-cli/releases/download/v1.7.1/sift-cli-linux
mv sift-cli-linux /usr/local/bin/sift
chmod 755 /usr/local/bin/sift
sudo sift install --user ubuntu
echo; echo "== Setup the AWS CLI"
apt install -y awscli
echo; echo "== SCRIPT COMPLETE"
echo; echo "== $0 has completed"
```
It may take a while for this step to complete, so continue on. Tag this EC2 Instance with the "Name" set to "SIFT Workstation"

NOTE: Some may wonder why use a second EC2 instance, thinking that the Incident Response Workstation and the SIFT Workstation can be combined. For the demo, they could. However, it is a best practice to perform the forensic analysis in a different AWS Account. In practice, the analysis may be done by a different team member as well.

Next, attach the EC2_Responder role to the SIFT Workstation so that it can access S3.  After the Ubuntu server boot-up script completes, login and verify that the script completed by running `tail -f /tmp/setup.log`.


NOTE: The Current versions of Volatility and Rekall on the SIFT Workstation needs to be updated. Enter these commands:
```
# Update Volatility on SIFT workstation
sudo rm -rf /usr/local/lib/python2.7/dist-packages/volatility
rm -f `which vol.py`
cd /usr/local/lib/python2.7/dist-packages/
sudo git clone https://github.com/volatilityfoundation/volatility.git
cd volatility
sudo python setup.py install
cd ~

# Update Rekall on SIFT Workstation
virtualenv  /tmp/MyEnv
source /tmp/MyEnv/bin/activate
pip install --upgrade setuptools pip wheel
pip install rekall-agent rekall
```
Also verify that the following commands execute by running them individually:
```
rekall --help
layout_tool -h
vol.py --help
```
## STEP 5 - Prepare a Demonstration Target
For this step, simply launch another Amazon Linux t2.micro EC2 instance and in Step 3 of the Launch wizard, expand the "Advanced Details" part of the form and paste in the following code in the User Data field:

```
#!/bin/bash
wget -q https://raw.githubusercontent.com/Resistor52/cloud_dfir_demo/master/DONT_PEEK_HERE/dont_peek.sh
bash dont_peek.sh
rm dont_peek.sh
```
Be sure that you use the same SSH Key that was uploaded to the Incident Response Workstation.  Note that the Security Group for this EC2 instance must be configured to allow SSH connectivity from the IR Workstation so that Margarita Shotgun can connect to it.

NOTE: Don't read the `dont_peek.sh` or the forensic analysis will not be a surprise.

Tag this EC2 Instance with the "Name" set to "Target"

## STEP 6 - Collect Evidence from Demonstration Target
Navigate to the AWS Simple Storage Service and create a S3 bucket for your memory captures. Next, copy the following code to a notepad and alter the parameters as appropriate and then paste the code into the command line while connected via SSH to the Incident Response Workstation:

```
## Set Parameters as appropriate
TARGET_IP=<TARGET_IP_ADDRESS>                # Update this with your target's IPv4 Address
SSH_KEY=<YOUR_SSH_KEY.pem>
SSH_USER=ec2-user                            # for Amazon Linux, SSH_USER=ubuntu for Ubuntu
BUCKET=<YOUR_MEMORY_BUCKET>                  # Use the bucket that was created at the beginning of this step
MODULE=lime-4.14.62-65.117.amzn1.x86_64.ko   # Amazon Linux AMI 2018.03.0 (ami-0ff8a91507f77f867)

## Make the magic happen
MY_IP=$(curl -s icanhazip.com)
margaritashotgun --server $TARGET_IP --username $SSH_USER --key $SSH_KEY \
    --module $MODULE --filename $TARGET_IP-mem.lime --bucket $BUCKET
aws_ir --examiner-cidr-range $MY_IP/32 instance-compromise --target $TARGET_IP \
    --user $SSH_USER --ssh-key $SSH_KEY
```

Note that we are calling Margarita Shotgun prior to AWS_IR because although AWS_IR will call Margarita Shotgun, in the present form AWS_IR cannot accept a parameter on the command line to tell Margarita Shotgun which memory module to use.  Instead AWS_IR assumes that the kernel module is in its repository.  The bad news is that recent kernels are not.  Therefore, the simple workaround is to call Margarita Shotgun first.  (A future demo will show how to set up a custom kernel module repository.)

TROUBLESHOOTING:
* Did you get an "Unable to locate credentials" error? That may indicate that you forgot to attach the instance profile in Step 2.
* Did you get "timed out" error? That may indicate that you may need to change the security group to allow the Incident Response Workstation to connect to the target via SSH.

Here is a [sample of the aws_ir output](sample_aws_ir_output.txt).

## STEP 7 - Prepare the Evidence for Examination
SSH into the SIFT Workstation. Verify that the S3 bucket can be accessed by running the following command:
```
aws s3 ls <YOUR_MEMORY_BUCKET>
```
You should see a file listed that has the name `<TARGET_IP_ADDRESS>-mem.lime` so lets download it using:
```
aws s3 cp s3://<YOUR_MEMORY_BUCKET>/<TARGET_IP_ADDRESS>-mem.lime /cases/<TARGET_IP_ADDRESS>-mem.lime
```

Great, now that we have the Memory Image moved to the SIFT Workstation, let's [make an EBS Volume from the snapshot](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-restoring-volume.html) being careful to select the same availability zone that the SIFT Workstation is running in. Tag the Volume with a meaningful name like "Evidence" to differentiate it.

Next, [attach the "Evidence" volume to the SIFT Workstation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-attaching-volume.html) and then run the `lsblk` command.  The output may look as follows:
```

root@ip-172-31-86-142:/home/ubuntu# lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
xvda    202:0    0    8G  0 disk
└─xvda1 202:1    0    8G  0 part /
xvdf    202:80   0    8G  0 disk
└─xvdf1 202:81   0    8G  0 part                       <----This is the device
loop0     7:0    0   87M  1 loop /snap/core/5145
loop1     7:1    0 12.6M  1 loop /snap/amazon-ssm-agent/295
```
The `lsblk` command revealed that nothing is mounted to `/dev/xvdf1`, so let's mount it read-only:
```
sudo mkdir /mnt/linux_mount
sudo mount -o ro /dev/xvdf1 /mnt/linux_mount
```

REMINDER: If you log out you will need to mount the evidence again unless you have modified /etc/fstab

## STEP 8 - Setup the Volatility & Rekall Profiles
First, upload the Volatility Profile (zip file) that was created in Step 2 to the SIFT workstation and then run the following two commands:
```
sudo cp *.zip /usr/local/lib/python2.7/dist-packages/volatility-2.6-py2.7.egg/volatility/plugins/overlays/linux/
vol.py --info | grep -i amzn
```
You should see a result similar to this:
```
Volatility Foundation Volatility Framework 2.6
Linux4_14_62-65_117_amzn1_x86_64x64 - A Profile for Linux 4.14.62-65.117.amzn1.x86_64 x64
```
Now test it using the following command:
```
vol.py --profile=<YOUR_VOLATILITY_PROFILE> -f <YOUR_MEMORY_DUMP>  linux_banner
```
For example, the command and output may look something like this:
```
$ vol.py --profile=Linux4_14_62-65_117_amzn1_x86_64x64  -f /cases/54.85.216.218-mem.lime  linux_banner
Volatility Foundation Volatility Framework 2.6
Linux version 4.14.62-65.117.amzn1.x86_64 (mockbuild@gobi-build-60009) (gcc version 7.2.1 20170915 (Red Hat 7.2.1-2) (GCC)) #1 SMP Fri Aug 10 20:03:52 UTC 2018
```
This test shows that Volatility used the `linux_banner` plugin to read the lime file with a valid profile. Next, set up the rekall profile:
```
rekal.py convert_profile rekall-*.zip my-rekall-profile.json
```
Now test it:
```
rekal.py --profile my-rekall-profile.json -f <YOUR_MEMORY_DUMP>  banner
```
You should see the same banner that was returned using volatility

## STEP 9 - Analyze the Data using Rekall and Volatility

(additional details coming soon)

Here is the list of Rekall Plugins for Linux:
https://storage.googleapis.com/web.rekall-innovations.com/docs/Manual/Plugins/Linux/index.html?v=13

and the Volatility Plugins for Linux:
https://github.com/volatilityfoundation/volatility/wiki/Linux-Command-Reference

## Step 10 - Analyze the Virtual Hard Drive using the SIFT Workstation

(additional details coming soon)
Refer to a research paper that I wrote on the topic:
https://www.sans.org/reading-room/whitepapers/cloud/digital-forensic-analysis-amazon-linux-ec2-instances-38235

