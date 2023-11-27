#!/bin/bash
cd /var/www/hegesmart
export HEGETOOL_ENV=staging 
exec bundle exec pry -Iconfig -rboot

