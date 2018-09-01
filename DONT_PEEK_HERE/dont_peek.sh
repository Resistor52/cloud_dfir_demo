#!/bin/bash
#######################################################
#                                                     #
#                DON'T PEEK AT THIS                   #
#               STOP READING THIS !!                  #
#                                                     #
#######################################################

# The purpose of this file is to give you something to investigate
# during the forensics lab demo. If you read this script it can
# ruin the fun!

cd /tmp
cp /usr/bin/nc /tmp/listen4evil
echo "/tmp/listen4evil -k -l 6666" > evil_ear
chmod +x evil_ear
at -f evil_ear now

cat <<- "EOF" > dga1.sh
#!/bin/bash
# Create some bogus domain names and perform DNS queries
# Against a host that is not a DNS Server
cp /usr/bin/dig /tmp/evildigger
while [ 1 ]
do
    PART=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 18 | head -n 1)
    ./evildigger @10.0.1.10 www.$PART.com
done
EOF
chmod +x dga1.sh
at -f dga1.sh now

cat <<- EOF1 > /bin/hello
#!/bin/bash
# Create a script to call heaven
file=call_mom_$(date +%s)
cp /usr/bin/nc /tmp/$file
echo "Hello" | ./$file 10.0.1.30 7777
rm $file
EOF1
chmod +x /bin/hello
touch -a -m -t 201512180130.09 /bin/hello

cat <<- EOF2 > /boot/grub/call2mins.sh
#!/bin/bash
# Call Out Every 2 Minutes
(crontab -l ; echo "*/2 * * * *  /bin/hello") | crontab -
EOF2
chmod +x /boot/grub/call2mins.sh
at -f /boot/grub/call2mins.sh now
