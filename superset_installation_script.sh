#!/bin/bash


# This script has been tested on Ubuntu 18.04
# system package installations

helpFunction()
{
   echo ""
   echo "Usage: $0 -u username -i servername"
   echo -e "\t-u Ubuntu username"
   echo -e "\t-i ip address or domain name"
   exit 1 # Exit script after printing help
}

while getopts "u:i:" opt
do
   case "$opt" in
      u ) username="$OPTARG" ;;
      i ) servername="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$username" ] || [ -z "$servername" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi


sudo apt-get update
sudo apt-get install build-essential libssl-dev libffi-dev python3.8 python3.8-dev python3-pip python3.8-venv libsasl2-dev libldap2-dev nginx

mkdir app
cd app

python3.8 -m venv venv
. venv/bin/activate

pip install --upgrade setuptools apache-superset gevent pip

superset db upgrade
export FLASK_APP=superset
superset fab create-admin
superset load_examples
superset init

echo  > superset_config.py

export SUPERSET_CONFIG_PATH=/home/$username/app/superset_config.py
deactivate

sudo echo "
[Unit]
Description=Gunicorn instance to serve superset
After=network.target

[Service]
User=$username
Group=www-data
WorkingDirectory=/home/$username/app
Environment=\"PATH=/home/$username/app/venv/bin\"
ExecStart=/home/$username/app/venv/bin/gunicorn -w 10 -k gevent --timeout 120 --limit-request-line 0 --limit-request-field_size 0 --bind unix:superset.sock -m 007 \"superset.app:create_app()\"

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/superset.service

sudo systemctl start superset
sudo systemctl enable superset

sudo ufw enable
sudo ufw allow 'Nginx HTTP'

sudo echo "
server {
    listen 80;
    server_name $servername;

    location / {
        include proxy_params;
        proxy_pass http://unix:/home/$username/app/superset.sock;
    }
}
" > /etc/nginx/sites-available/superset

sudo ln -s /etc/nginx/sites-available/superset /etc/nginx/sites-enabled

sudo systemctl restart nginx
