#!/bin/bash
cd /var/www/hegesmart
export HEGETOOL_ENV=staging 
exec bundle exec ruby bin/sync.rb

