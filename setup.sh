#!/bin/sh

# Prompt the user to enter their desired username and password
echo "Enter your desired username:"
read username
echo "Enter a password for the user:"
read -s password

#Basically we shouldn't be running dashy as root although you could if you wanted to
echo "Creating user $username..."
addgroup -S "$username" && adduser -S "$username" -G "$username" -h /home/"$username" -s /bin/bash
echo "$username:$password" | chpasswd

#Packages...
echo "Installing required packages..."
apk add bash nano
apk update && apk upgrade

#Default terminal sucks, so we are gonna make it look more appealing
echo "Setting up terminal environment..."
ln -s /etc/profile.d/color_prompt.sh.disabled /etc/profile.d/color_prompt.sh
export TERM=linux
sh -c "echo 'TERM=linux' >> ~/.profile"

#More packages...
echo "Installing additional dependencies..."
apk add git net-tools curl wget
apk add --update nodejs=16.20.2-r0
apk add yarn

#Time to clone the official dashy repo!
echo "Cloning Dashy repository..."
git clone https://github.com/Lissy93/dashy.git /home/"$username"/dashy

#self explanatory (assuming you will be using the newly created user)
echo "Changing ownership of Dashy directory and its contents..."
chown -R "$username":"$username" /home/"$username"/dashy
cd /home/"$username"/dashy/


echo "Creating logs directory..."
mkdir -p logs/build logs/start

#yarn build
echo "Building the project..."
yarn build

#we want dashy running in the background so heres a little init.d script, it'll automatically start everytime you boot up your alpine instance
cat << EOF > /etc/init.d/dashy
#!/sbin/openrc-run

description="Running Dashy on system start"

directory="/home/$username/dashy"
pidfile="/var/run/dashy.pid"

name="dashy"
command_background="yes"
timestamp=\$(date +"%Y-%m-%d-%H-%M-%S")
build_log="\$directory/logs/build/\${name}-build-\${timestamp}.log"
start_log="\$directory/logs/start/\${name}-start-\${timestamp}.log"
host=\$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\\.){3}[0-9]*' | grep -Eo '([0-9]*\\.){3}[0-9]*' | grep -v '127.0.0.1')

depend() {
    need net
}

start_pre() {
    ebegin "Building Dashy!"
    cd "\$directory"
    yarn build > "\$build_log" 2>&1
    if [ -s "\$built_log" ]; then
        last_line=\$(tail -n 1 "\$build_log")
        einfo "Dashy has been built! \$last_line"
    else
        ewarn "Failed to build Dashy."
    fi
}

start() {
    ebegin "Starting Dashy!"
    nohup yarn start > "\$start_log" 2>&1 &
    echo \$! > "\$pidfile"
    sleep 5
    # Check if the line starting with "Your new" exists in the start_log file
    if grep -q "Your new dashboard" "\$start_log"; then
        einfo "Your new dashboard is now up and running at \$host"
    else
        ewarn "Dashy has errors or failed to start. See Logs."
    fi
}
EOF

chmod +x /etc/init.d/dashy
echo "Adding dashy service to boot..."
rc-update add dashy boot

#start the service using rc-service dashy start
echo "Starting dashy service..."
rc-service dashy start

current_user=$(whoami)
echo "Dashy is running under user: $current_user"

