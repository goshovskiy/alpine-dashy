#!/bin/ash


clear

# Function to display yellow text
yellow() {
    printf "${YELLOW}$1${NC}\n"
}

# ANSI color codes
YELLOW='\033[1;33m' # Yellow
NC='\033[0m' # No Color

# Function to create a pause for 5 seconds
pause() {
    sleep 5
}

# Prompt the user to enter their desired username and password
yellow "Enter your desired username:"
read username
yellow "Enter a password for the user:"
read -s password

# Create user
yellow "Creating user $username..."
addgroup "$username" && adduser -S "$username" -G "$username" -h /home/"$username"
echo "$username:$password" | chpasswd

# Install required packages
yellow "Installing required packages..."
apk update && apk upgrade
apk add nano

# Install additional dependencies
yellow "Installing additional dependencies..."
apk add git net-tools curl wget
apk add --update nodejs=16.20.2-r0
apk add yarn
pause

# Set up terminal environment
yellow "Setting up terminal environment..."
ln -s /etc/profile.d/color_prompt.sh.disabled /etc/profile.d/color_prompt.sh
export TERM=linux
sh -c "echo 'TERM=linux' >> ~/.profile"
pause

# Clone Dashy repository
yellow "Cloning Dashy repository..."
git clone https://github.com/Lissy93/dashy.git /home/"$username"/dashy
pause

# Create logs directory
yellow "Creating logs directory..."
mkdir -p /home/"$username"/dashy/logs/build /home/"$username"/dashy/logs/start
pause

# Change ownership of Dashy directory and its contents
yellow "Changing ownership of Dashy directory and its contents..."
chown -R "$username":"$username" /home/"$username"/dashy
cd /home/"$username"/dashy/

# Build the project
yellow "Building the project..."
yarn build

# Create init.d script for Dashy service
yellow "Creating init.d script for Dashy service..."
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
    if [ -s "\$build_log" ]; then
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
pause

# Make init.d script executable
yellow "Making init.d script executable..."
chmod +x /etc/init.d/dashy
pause

# Add Dashy service to boot
yellow "Adding Dashy service to boot..."
rc-update add dashy boot
pause

# Start Dashy service
yellow "Starting Dashy service..."
rc-service dashy start
pause

# Display current user
yellow "Dashy is running under user: $username"
