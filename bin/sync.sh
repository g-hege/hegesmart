#!/bin/bash
source /home/hege/.rvm/environments/ruby-3.3.0
cd /var/www/hegesmart
export HEGETOOL_ENV=staging 
exec bundle exec ruby bin/sync.rb

